// Copyright (c) 2015-2019 Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#import "BrightnessController.h"
#import "IgnoreListController.h"
#import "Model.h"
#import "Constants.h"
#import "util.h"
#import <IOKit/graphics/IOGraphicsLib.h>
#import <ApplicationServices/ApplicationServices.h>
#import <AppKit/AppKit.h>

@interface BrightnessController ()

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) Model *model;
@property (nonatomic, assign) float lastSet;
@property (nonatomic, assign) BOOL noticed;
@property (nonatomic, assign) float lastNoticed;
@property (nonatomic, assign) BOOL shouldUseNewApi;

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

- (void)tick:(NSTimer *)timer;

// even though the screen gradually transitions between brightness levels,
// getBrightness returns the level to which the brightness is set
- (float)getBrightness;

- (void)setBrightness:(float) level;

- (double)computeLightness:(CGImageRef) image;

@end

@implementation BrightnessController

- (id)init {
    self = [super init];
    if (self) {
        self.model = [Model new];
        self.lastSet = -1; // this causes tick to notice that the brightness has changed significantly
                           // which causes it to create a new data point for the current screen
        self.noticed = NO;
        self.lastNoticed = 0;

        self.ignoreList = [[IgnoreListController alloc] init];
        self.lastActiveAppURLString = @"";

        self.shouldUseNewApi = false;
    }
    return self;
}

- (BOOL)isRunning {
    return self.timer && [self.timer isValid];
}

- (void)start {
    if (self.timer) {
        [self.timer invalidate];
    }
    self.timer = [NSTimer scheduledTimerWithTimeInterval:TICK_INTERVAL
                                                  target:self
                                                selector:@selector(tick:)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)stop {
    [self.timer invalidate];
    self.timer = nil;
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

- (void)tick:(NSTimer *)timer {
    if ([self checkIgnoreList]) {
        return;
    }

    // get screen content lightness
    CGImageRef contents = CGDisplayCreateImage(kCGDirectMainDisplay);
    if (!contents) {
        return;
    }
    double lightness = [self computeLightness:contents];
    CFRelease(contents);


    // check if backlight has been manually changed
    float setPoint = [self getBrightness];
    if (self.noticed || fabsf(self.lastSet - setPoint) > CHANGE_NOTICE) {
        if (!self.noticed) {
            self.noticed = YES;
            self.lastNoticed = setPoint;
            return; // wait till next tick to see if it's still changing
        }
        if (fabsf(setPoint - self.lastNoticed) > CHANGE_NOTICE) {
            self.lastNoticed = setPoint;
            return; // it's still changing
        } else if (self.shouldIgnoreOutput) {
            // the brightness difference is due to adjusting automatically to preferred brightness value.
            // reset and fall through.
            self.shouldIgnoreOutput = NO;
        } else {
            [self.model observeOutput:setPoint forInput:lightness];
            self.noticed = NO;
            // don't return, fall through and evaluate model here
        }
    }

    float brightness = [self.model predictFromInput:lightness];

    [self setBrightness:brightness];
}

- (double)computeLightness:(CGImageRef) image {
    CFDataRef dataRef = CGDataProviderCopyData(CGImageGetDataProvider(image));
    const unsigned char *data = CFDataGetBytePtr(dataRef);

    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);

    double lightness = 0;
    const unsigned int kSkip = 16; // uniformly sample screen pixels
    // find RMS lightness value
    if (data) {
        for (size_t y = 0; y < height; y += kSkip) {
            for (size_t x = 0; x < width; x += kSkip) {
                const unsigned char *dptr = &data[(width * y + x) * 4];
                double l = srgb_to_lightness(dptr[0], dptr[1], dptr[2]);

                lightness += l * l;
            }
        }
    }
    lightness = sqrt(lightness / (width * height / (kSkip * kSkip)));

    CFRelease(dataRef);

    return lightness;
}

- (float)getBrightessNewAPI {
    float level = 1.0f;
    CFURLRef coreDisplayPath = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("/System/Library/Frameworks/CoreDisplay.framework"), nil);
    CFBundleRef coreDisplayBundle = CFBundleCreate(kCFAllocatorDefault, coreDisplayPath);

    if (coreDisplayBundle) {
        typedef double (*getBrightnessFunctionPointer)(UInt32);
        getBrightnessFunctionPointer getBrightnessWithCoreDisplayAPI = CFBundleGetFunctionPointerForName(coreDisplayBundle, CFSTR("CoreDisplay_Display_GetUserBrightness"));

        if (getBrightnessWithCoreDisplayAPI == NULL) {
            NSLog(@"Error: Null pointer!");
        } else {
            level = (float) getBrightnessWithCoreDisplayAPI(0);
            if (self.lastSet != level) {
                NSLog(@"Got new: %f, self.lastSet = %f", level, self.lastSet);
            }
        }
    } else {
        NSLog(@"Failed!");
    }
    return level;
}

- (float)getBrightness {
    float level = 1.0f;
    if (self.shouldUseNewApi) {
        level = [self getBrightessNewAPI];
    } else {
        io_iterator_t iterator;
        kern_return_t result = IOServiceGetMatchingServices(kIOMasterPortDefault,
                                                            IOServiceMatching("IODisplayConnect"),
                                                            &iterator);
        if (result == kIOReturnSuccess) {
            io_object_t service;
            while ((service = IOIteratorNext(iterator))) {
                IODisplayGetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), &level);
                IOObjectRelease(service);
            }
        }
    }
    return level;
}

- (void)notifySystemOfNewBrightness:(float)level {
    CFURLRef coreDisplayPath = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("/System/Library/PrivateFrameworks/DisplayServices.framework"), nil);
    CFBundleRef coreDisplayBundle = CFBundleCreate(kCFAllocatorDefault, coreDisplayPath);

    if (!coreDisplayBundle) {
        NSLog(@"Failed!");
        return;
    }

    typedef void (*notifyBrightnessFunctionPointer)(UInt32, double);
    notifyBrightnessFunctionPointer notifyBrightnessWithDisplayServicesAPI = CFBundleGetFunctionPointerForName(coreDisplayBundle, CFSTR("DisplayServicesBrightnessChanged"));

    if (notifyBrightnessWithDisplayServicesAPI == NULL) {
        NSLog(@"Error: Null pointer!");
    } else {
        if (level == 0) {
            NSLog(@"It wants to set to 0...");
        } else {
            if (self.lastSet != level) {
                NSLog(@"NOTIFYING %f", level);
            }
            notifyBrightnessWithDisplayServicesAPI(0, (double) level);
        }
    }
}

- (void)setBrightnessNewAPI:(float)level {
    CFURLRef coreDisplayPath = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("/System/Library/Frameworks/CoreDisplay.framework"), nil);
    CFBundleRef coreDisplayBundle = CFBundleCreate(kCFAllocatorDefault, coreDisplayPath);

    if (!coreDisplayBundle) {
        NSLog(@"Failed!");
        return;
    }

    typedef void (*setBrightnessFunctionPointer)(UInt32, double);
    setBrightnessFunctionPointer setBrightnessWithCoreDisplayAPI = CFBundleGetFunctionPointerForName(coreDisplayBundle, CFSTR("CoreDisplay_Display_SetUserBrightness"));

    if (setBrightnessWithCoreDisplayAPI == NULL) {
        NSLog(@"Error: Null pointer!");
    } else {
        if (level == 0) {
            NSLog(@"It wants to set to 0...");
        } else {
            if (self.lastSet != level) {
                NSLog(@"Setting to %f, self.lastSet = %f", level, self.lastSet);
            }
            setBrightnessWithCoreDisplayAPI(0, (double) level);
            [self notifySystemOfNewBrightness:level];
        }
    }
}
- (void)setBrightness:(float)level {
    if (self.shouldUseNewApi) {
        [self setBrightnessNewAPI:level];
    } else {
        io_iterator_t iterator;
        kern_return_t result = IOServiceGetMatchingServices(kIOMasterPortDefault,
                                                            IOServiceMatching("IODisplayConnect"),
                                                            &iterator);
        if (result == kIOReturnSuccess) {
            io_object_t service;
            while ((service = IOIteratorNext(iterator))) {
                IODisplaySetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), level);
                IOObjectRelease(service);
            }
        }
    }
    self.lastSet = [self getBrightness]; // not just storing `level` cause weird rounding stuff
}

@end
