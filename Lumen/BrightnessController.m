// Copyright (c) 2015-2017 Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#import "BrightnessController.h"
#import "Model.h"
#import "Constants.h"
#import "util.h"
#import <IOKit/graphics/IOGraphicsLib.h>
#import <ApplicationServices/ApplicationServices.h>
#import <AppKit/AppKit.h>

@interface BrightnessController ()

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) Model *model;
@property float lastSet;
@property (nonatomic, assign, getter=isUpdatingIgnoreList) BOOL updatingIgnoreList;
@property (nonatomic, strong) NSArray *ignoredApplications;
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

        self.ignoredApplications = [[NSUserDefaults standardUserDefaults] objectForKey:DEFAULTS_IGNORE_LIST] ?: @[];
        self.lastActiveAppURLString = @"";
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(ignoreListChanged:)
                                                     name:NOTIFICATION_IGNORE_LIST_CHANGED
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

- (void)tick:(NSTimer *)timer {
    // do nothing if the frontmost application is in ignored list.
    if (!self.updatingIgnoreList) {
        NSString *bundleURLString = [NSBundle mainBundle].bundleURL.absoluteString.stringByStandardizingPath;
        NSRunningApplication *activeApplication = [NSWorkspace sharedWorkspace].frontmostApplication;
        NSString *activeAppURLString = activeApplication.bundleURL.absoluteString.stringByStandardizingPath;

        if ([activeAppURLString isEqualToString:bundleURLString]) {
            // for better experience, skip this method when Lumen is opened on top of an ignored application.
            if ([self.ignoredApplications containsObject:self.lastActiveAppURLString]) {
                return;
            }
        } else {
            // store the last active application URL (except Lumen.app itself).
            self.lastActiveAppURLString = activeAppURLString;
        }

        // ignore if the current active app is listed in the ignored list.
        if ([self.ignoredApplications containsObject:activeAppURLString]) {
            return;
        }
    }

    // get screen content lightness
    CGImageRef contents = CGDisplayCreateImage(kCGDirectMainDisplay);
    if (!contents) {
        return;
    }
    double lightness = [self computeLightness:contents];
    CFRelease(contents);


    // check if backlight has been manually changed
    static bool noticed = false;
    static float lastNoticed = 0;
    float setPoint = [self getBrightness];
    if (noticed || fabsf(self.lastSet - setPoint) > CHANGE_NOTICE) {
        if (!noticed) {
            noticed = true;
            lastNoticed = setPoint;
            return; // wait till next tick to see if it's still changing
        }
        if (fabsf(setPoint - lastNoticed) > CHANGE_NOTICE) {
            lastNoticed = setPoint;
            return; // it's still changing
        } else {
            [self.model observeOutput:setPoint forInput:lightness];
            noticed = false;
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

- (float)getBrightness {
    float level = 1.0f;
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
    return level;
}

- (void)setBrightness:(float)level {
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
    self.lastSet = [self getBrightness]; // not just storing `level` cause weird rounding stuff
}

#pragma mark - NSNotification Responder

- (void)ignoreListChanged:(NSNotification *)notification {
    self.updatingIgnoreList = YES;

    NSArray<NSString *> *newIgnoreList = notification.userInfo[@"updatedList"];
    if (newIgnoreList) {
        self.ignoredApplications = newIgnoreList;
    }

    self.updatingIgnoreList = NO;
}

@end
