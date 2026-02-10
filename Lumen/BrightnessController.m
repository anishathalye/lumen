// Copyright (c) Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#import "BrightnessController.h"
#import "IgnoreListController.h"
#import "Model.h"
#import "Constants.h"
#import "util.h"
#import <IOKit/graphics/IOGraphicsLib.h>
#import <ApplicationServices/ApplicationServices.h>
#import <AppKit/AppKit.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

extern int DisplayServicesGetBrightness(CGDirectDisplayID display, float *brightness);
extern int DisplayServicesSetBrightness(CGDirectDisplayID display, float brightness);

/*
 BrightnessController architecture
 --------------------------------
 - ScreenCaptureKit callback path updates `latestLightness` from captured frames.
 - A timer-driven control loop (`controlTick`) runs at BRIGHTNESS_SMOOTHING_INTERVAL
   and applies brightness steps toward the model's predicted target.
 - Decoupling control from frame delivery avoids stalls when frame callbacks pause
   (for example, during static screens or UI tracking modes).
 - Manual brightness changes are detected from hardware readback and fed back into
   the model, while recent programmatic writes are filtered to avoid self-learning.
 */
@interface BrightnessController () <SCStreamDelegate, SCStreamOutput>

@property (nonatomic, strong) SCStream *stream;
@property (nonatomic, strong) Model *model;
@property (nonatomic, strong) NSTimer *controlTimer;
@property (nonatomic, assign) float lastSet; // display brightness read back from the OS, after setting it
@property (nonatomic, assign) float lastAssigned; // last value of brightness that the controller has assigned to the display
@property (nonatomic, assign) float targetBrightness; // target brightness predicted from screen content
@property (nonatomic, assign) double latestLightness; // most recent measured screen lightness
@property (nonatomic, assign) BOOL hasLatestLightness; // have we received any lightness sample yet
@property (nonatomic, assign) BOOL noticed; // have we noticed the user manually changing the brightness
@property (nonatomic, assign) float lastNoticed; // the value of the brightness last time we noticed the user manually change it
@property (nonatomic, assign) NSTimeInterval lastManualChangeTime; // the time the user last manually changed the brightness
@property (nonatomic, assign) NSTimeInterval lastProgrammaticSetTime; // the time Lumen last issued a brightness write
@property (nonatomic, assign) NSTimeInterval lastSmoothingTickTime; // the time the controller last updated the smoothing state

/**
 Flags whether ignore observeOutput:forInput: due to brightness changes in ignored apps.
 */
@property (nonatomic, assign) BOOL shouldIgnoreOutput;

/**
 Maintains the list of ignored applications.
 */
@property (nonatomic, strong) IgnoreListController *ignoreList;

/**
 Maintains the last frontmost application (other than Lumen).
 */
@property (nonatomic, strong) NSString *lastActiveAppURLString;

- (void)processLightness:(double)lightness;
- (void)controlTick:(NSTimer *)timer;

- (float)getBrightness;

- (void)setBrightness:(float) level;

- (double)computeLightnessFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

@implementation BrightnessController

- (id)init {
    self = [super init];
    if (self) {
        self.model = [Model new];
        self.lastSet = -1; // this causes tick to notice that the brightness has changed significantly
                           // which causes it to create a new data point for the current screen
        self.lastAssigned = -1;
        self.targetBrightness = -1;
        self.latestLightness = 0;
        self.hasLatestLightness = NO;
        self.noticed = NO;
        self.lastNoticed = 0;
        self.lastManualChangeTime = 0;
        self.lastProgrammaticSetTime = 0;
        self.lastSmoothingTickTime = 0;

        self.ignoreList = [[IgnoreListController alloc] init];
        self.lastActiveAppURLString = @"";
    }
    return self;
}

- (BOOL)isRunning {
    return self.stream != nil;
}

- (void)start {
    [self stop];
    self.lastAssigned = -1;
    self.targetBrightness = -1;
    self.hasLatestLightness = NO;
    self.lastProgrammaticSetTime = 0;
    self.lastSmoothingTickTime = 0;
    // Keep control updates running in common run-loop modes so tracking UI (e.g. menu bar)
    // does not pause brightness transitions.
    self.controlTimer = [NSTimer timerWithTimeInterval:BRIGHTNESS_SMOOTHING_INTERVAL
                                                 target:self
                                               selector:@selector(controlTick:)
                                               userInfo:nil
                                                repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.controlTimer forMode:NSRunLoopCommonModes];

    if (!CGPreflightScreenCaptureAccess()) {
        if (!CGRequestScreenCaptureAccess()) {
            NSLog(@"Screen Recording permission is required. Enable it in System Settings > Privacy & Security > Screen & System Audio Recording.");
            return;
        }
    }

    [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent *content, NSError *error) {
        if (error) {
            NSLog(@"Error getting shareable content: %@", error);
            return;
        }

        SCDisplay *mainDisplay = nil;
        for (SCDisplay *display in content.displays) {
            if (display.displayID == CGMainDisplayID()) {
                mainDisplay = display;
                break;
            }
        }

        if (!mainDisplay) {
            NSLog(@"Could not find main display");
            return;
        }

        // set up stream configuration with 1/10th resolution
        SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
        config.width = mainDisplay.width / LINEAR_SUBSAMPLE;
        config.height = mainDisplay.height / LINEAR_SUBSAMPLE;
        config.minimumFrameInterval = CMTimeMake(1, FRAME_RATE);
        config.pixelFormat = kCVPixelFormatType_32BGRA;
        config.showsCursor = NO;
        config.capturesAudio = NO;

        // create content filter for main display
        SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:mainDisplay excludingWindows:@[]];

        // create and start stream
        NSError *streamError;
        self.stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:self];

        if (self.stream) {
            [self.stream addStreamOutput:self type:SCStreamOutputTypeScreen sampleHandlerQueue:dispatch_get_main_queue() error:&streamError];
            if (streamError) {
                NSLog(@"Error adding stream output: %@", streamError);
                return;
            }

            [self.stream startCaptureWithCompletionHandler:^(NSError *error) {
                if (error) {
                    NSLog(@"Error starting capture: %@", error);
                } else {
                    NSLog(@"Screen capture started successfully");
                }
            }];
        }
    }];
}

- (void)stop {
    if (self.controlTimer) {
        [self.controlTimer invalidate];
        self.controlTimer = nil;
    }

    if (self.stream) {
        [self.stream stopCaptureWithCompletionHandler:^(NSError *error) {
            if (error) {
                NSLog(@"Error stopping capture: %@", error);
            }
        }];
        self.stream = nil;
    }
}

- (BOOL)checkIgnoreList {
    // do nothing if the frontmost application is in ignored list.
    NSString *lumenBundleString = [NSBundle mainBundle].bundleURL.absoluteString.stringByStandardizingPath;
    NSRunningApplication *activeApplication = [NSWorkspace sharedWorkspace].frontmostApplication;
    NSString *activeAppURLString = activeApplication.bundleURL.absoluteString.stringByStandardizingPath;
    BOOL isLumenActive = NO;
    BOOL skip = NO;

    // for better experience, skip when Lumen is opened on top of an ignored application.
    if ([activeAppURLString isEqualToString:lumenBundleString]) {
        isLumenActive = YES;
        if ([self.ignoreList containsURLString:self.lastActiveAppURLString]) {
            return YES;
        }
    }

    // ignore if the current active app is listed in the ignored list.
    if ([self.ignoreList containsURLString:activeAppURLString]) {
        // any brightness adjustments made by user or Lumen should not be observed, in order to not impact all other non-ignored apps.
        self.shouldIgnoreOutput = YES;

        // update preferred brightness for ignored applications, only if it's certain that the brightness is changed manually by the user.
        float preferredBrightness = [self.ignoreList preferredBrightnessForURLString:activeAppURLString].floatValue;
        if ([activeAppURLString isEqualToString:self.lastActiveAppURLString]) {
            float currentBrightness = [self getBrightness];
            if (fabs(currentBrightness - preferredBrightness) > CHANGE_NOTICE) {
                [self.ignoreList setPreferredBrightness:@(currentBrightness) forURLString:activeAppURLString];
            }
        } else if (preferredBrightness > -1) {
            // update the brightness, only if it has non-default value.
            [self setBrightness:preferredBrightness];
        }

        skip = YES;
    }

    // store the last active application URL (except Lumen.app itself).
    if (!isLumenActive) {
        self.lastActiveAppURLString = activeAppURLString;
    }

    return skip;
}

- (void)processLightness:(double)lightness {
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];

    // Phase 1: observe potential user intent from hardware brightness readback.
    float setPoint = [self getBrightness];
    BOOL changedBrightness = fabsf(self.lastSet - setPoint) > CHANGE_NOTICE;
    BOOL likelyProgrammaticSettle = changedBrightness &&
        (currentTime - self.lastProgrammaticSetTime) < PROGRAMMATIC_BRIGHTNESS_SETTLE_WINDOW;
    if (likelyProgrammaticSettle) {
        // Hardware readback can settle after a write; don't treat that as user intent.
        self.lastSet = setPoint;
        self.noticed = NO;
    } else if (self.noticed || changedBrightness) {
        if (!self.noticed) {
            self.noticed = YES;
            self.lastNoticed = setPoint;
            self.lastManualChangeTime = currentTime;
            return; // wait for DEBOUNCE_DELAY to see if it's still changing
        }
        if (fabsf(setPoint - self.lastNoticed) > CHANGE_NOTICE) {
            self.lastNoticed = setPoint;
            self.lastManualChangeTime = currentTime;
            return; // it's still changing
        } else if (currentTime - self.lastManualChangeTime < DEBOUNCE_DELAY) {
            return; // wait for things to settle
        } else if (self.shouldIgnoreOutput) {
            // the brightness difference is due to adjusting automatically to preferred brightness value.
            // reset and fall through.
            self.shouldIgnoreOutput = NO;
        } else {
            [self.model observeOutput:setPoint forInput:lightness];
            self.noticed = NO;
            self.lastSet = setPoint;
            self.lastAssigned = setPoint;
            self.targetBrightness = setPoint;
            self.lastSmoothingTickTime = currentTime;
            // don't return, fall through and evaluate model here
        }
    }

    // Phase 2: compute desired target from observed content lightness.
    float target = [self.model predictFromInput:lightness];
    target = fmaxf(0.0f, fminf(1.0f, target));
    self.targetBrightness = target;

    if (self.lastAssigned < 0) {
        // Initialize the ramp from the current hardware brightness.
        self.lastAssigned = setPoint;
    }

    if (self.lastSmoothingTickTime <= 0) {
        self.lastSmoothingTickTime = currentTime;
    }

    // Phase 3: apply a bounded eased step toward target.
    NSTimeInterval elapsed = currentTime - self.lastSmoothingTickTime;
    if (elapsed < BRIGHTNESS_SMOOTHING_INTERVAL) {
        return;
    }
    self.lastSmoothingTickTime = currentTime;

    float delta = self.targetBrightness - self.lastAssigned;
    if (fabsf(delta) <= BRIGHTNESS_SNAP_THRESHOLD) {
        // no changes to make
        self.lastAssigned = self.targetBrightness;
        return;
    }

    float normalizedDistance = fminf(1.0f, fabsf(delta) / BRIGHTNESS_EASING_DISTANCE);
    // Smoothstep easing: slower near target, faster when farther away.
    float ease = normalizedDistance * normalizedDistance * (3.0f - 2.0f * normalizedDistance);
    float speedFactor = BRIGHTNESS_EASING_MIN_FACTOR + (1.0f - BRIGHTNESS_EASING_MIN_FACTOR) * ease;
    float maxStep = BRIGHTNESS_SMOOTHING_RATE * speedFactor * (float)elapsed;
    float step = copysignf(fminf(fabsf(delta), maxStep), delta);
    float nextBrightness = self.lastAssigned + step;
    nextBrightness = fmaxf(0.0f, fminf(1.0f, nextBrightness));

    [self setBrightness:nextBrightness];
    self.lastAssigned = nextBrightness;
}

- (void)controlTick:(NSTimer *)timer {
    if (!self.hasLatestLightness) {
        // Wait until we have at least one measured lightness sample.
        return;
    }

    if ([self checkIgnoreList]) {
        return;
    }

    [self processLightness:self.latestLightness];
}

- (float)getBrightness {
    float level = 1.0f;
    DisplayServicesGetBrightness(kCGDirectMainDisplay, &level);
    return level;
}

- (void)setBrightness:(float)level {
    float clamped = fmaxf(0.0f, fminf(1.0f, level));
    DisplayServicesSetBrightness(kCGDirectMainDisplay, clamped);
    self.lastProgrammaticSetTime = [NSDate timeIntervalSinceReferenceDate];
    self.lastSet = [self getBrightness]; // not just storing `level` cause weird rounding stuff
}

- (double)computeLightnessFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!imageBuffer) {
        // this happens occasionally, haven't investigated why exactly this happens
        return 0;
    }

    OSType pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
    if (pixelFormat != kCVPixelFormatType_32BGRA) {
        NSLog(@"Unexpected pixel format: %d", (int)pixelFormat);
        return 0;
    }

    CVReturn lockResult = CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    if (lockResult != kCVReturnSuccess) {
        NSLog(@"Failed to lock pixel buffer: %d", lockResult);
        return 0;
    }

    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);

    double lightness = 0;

    for (size_t y = 0; y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            const unsigned char *pixel = (unsigned char *)baseAddress + (y * bytesPerRow) + (x * 4);
            // BGRA format: B=pixel[0], G=pixel[1], R=pixel[2], A=pixel[3]
            double l = srgb_to_lightness(pixel[2], pixel[1], pixel[0]); // R, G, B
            lightness += l * l;
        }
    }

    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

    lightness = sqrt(lightness / (width * height));
    return lightness;
}

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if (type == SCStreamOutputTypeScreen) {
        // check if this sample buffer contains video data
        CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
        if (!formatDescription) {
            NSLog(@"Sample buffer has no format description");
            return;
        }

        CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);

        if (mediaType != kCMMediaType_Video) {
            NSLog(@"Non-video sample buffer received, media type: %d", (int)mediaType);
            return; // skip non-video sample buffers
        }

        double lightness = [self computeLightnessFromSampleBuffer:sampleBuffer];

        // Store latest lightness only. The timer-driven control loop consumes this value,
        // which keeps transitions smooth even when capture callbacks are bursty.
        if (lightness > 0) {
            self.latestLightness = lightness;
            self.hasLatestLightness = YES;
        }
    }
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
    if (error) {
        NSLog(@"Stream stopped with error: %@", error);
    }
    self.stream = nil;
}

@end
