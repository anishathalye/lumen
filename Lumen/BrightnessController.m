//
//  BrightnessController.m
//  Lumen
//
//  Created by Anish Athalye on 4/10/15.
//  Copyright (c) 2015 Anish Athalye. All rights reserved.
//

#import "BrightnessController.h"
#import "Model.h"
#import "Constants.h"
#import "util.h"
#import <IOKit/graphics/IOGraphicsLib.h>
#import <ApplicationServices/ApplicationServices.h>

#define CHANGE_NOTICE (0.01f)

@interface BrightnessController ()

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) Model *model;
@property float lastSet;

- (void)tick:(NSTimer *)timer;

// even though the screen gradually transitions between brightness levels,
// getBrightness returns the level to which the brightness is set
- (float)getBrightness;

- (void)setBrightness:(float) level;

- (CGImageRef)getScreenContents;

- (double)computeLightness:(CGImageRef) image;

@end

@implementation BrightnessController

- (id)init {
    self = [super init];
    if (self) {
        self.model = [[Model alloc] init];
        [self setBrightness:1];
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

- (void)tick:(NSTimer *)timer {
    // get screen content lightness
    CGImageRef contents = [self getScreenContents];
    if (!contents) {
        return;
    }
    double lightness = [self computeLightness:contents];
    CFRelease(contents);


    // check if backlight has been manually changed
    static bool noticed = false;
    static float lastNoticed = 0;
    float setPoint = [self getBrightness];
    if (noticed || fabsf(self.lastSet - setPoint) > CHANGE_NOTICE)
    {
        if (!noticed) {
            NSLog(@"noticed!");
            noticed = true;
            lastNoticed = setPoint;
            return; // wait till next tick to see if it's still changing
        }
        if (fabsf(setPoint - lastNoticed) > CHANGE_NOTICE)
        {
            lastNoticed = setPoint;
            NSLog(@"brightness still changing");
            return; // it's still changing
        }
        else
        {
            NSLog(@"observing... %f; %f", setPoint, lightness);
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

    double brightness = 0;
    const unsigned int kSkip = 16; // uniformly sample screen pixels
    // find RMS brightness value
    if (data) {
        for (size_t y = 0; y < height; y += kSkip) {
            for (size_t x = 0; x < width; x += kSkip) {
                const unsigned char *dptr = &data[(width * y + x) * 4];
                double l = srgb_to_brightness(dptr[0], dptr[1], dptr[2]);

                brightness += l * l;
            }
        }
    }
    brightness = sqrt(brightness / (width * height / (kSkip * kSkip)));

    CFRelease(dataRef);

    return brightness;
}

- (CGImageRef)getScreenContents {
    CGImageRef imageRef = CGDisplayCreateImage(kCGDirectMainDisplay);
    return imageRef;
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

@end
