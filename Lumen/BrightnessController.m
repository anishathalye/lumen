//
//  BrightnessController.m
//  Lumen
//
//  Created by Anish Athalye on 4/10/15.
//  Copyright (c) 2015 Anish Athalye. All rights reserved.
//

#import "BrightnessController.h"
#import "Constants.h"
#import "util.h"
#import <IOKit/graphics/IOGraphicsLib.h>
#import <ApplicationServices/ApplicationServices.h>

@interface BrightnessController ()

@property (nonatomic, strong) NSTimer *timer;

- (void)tick:(NSTimer *)timer;
- (CGContextRef)createSRGBContextFromImage:(CGImageRef) image;
- (float)getBrightness;
- (void)setBrightness:(float) level;
- (CGImageRef)getScreenContents;
- (double)computeBrightness:(CGImageRef) image;

@end

@implementation BrightnessController

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
    CGImageRef contents = [self getScreenContents];
    if (contents) {
        double brightness = [self computeBrightness:contents];
        CFRelease(contents);
        double computed = clip(linear_interpolate(20, 0.8, 95, 0.3, brightness), 0, 1);
        [self setBrightness:computed];
    }
}

- (double)computeBrightness:(CGImageRef) image {
    CGContextRef context = [self createSRGBContextFromImage:image];
    if (!context) {
        return -1; // error
    }

    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    CGRect rect = {{0, 0}, {width, height}};

    CGContextDrawImage(context, rect, image);
    unsigned char *data = CGBitmapContextGetData(context);

    double brightness = 0;
    const unsigned int kSkip = 16; // uniformly sample screen pixels
    // find RMS brightness value
    if (data) {
        for (size_t y = 0; y < height; y += kSkip) {
            for (size_t x = 0; x < width; x += kSkip) {
                unsigned char *dptr = &data[(width * y + x) * 4];
                double l = srgb_to_brightness(dptr[0], dptr[1], dptr[2]);

                brightness += l * l;
            }
        }
    }
    brightness = sqrt(brightness / (width * height / (kSkip * kSkip)));

    if (data) {
        free(data);
    }
    CGContextRelease(context);

    return brightness;
}

- (CGImageRef)getScreenContents {
    CGDirectDisplayID display[MAX_DISPLAYS];
    CGDisplayCount numDisplays;
    CGDisplayErr err = CGGetOnlineDisplayList(MAX_DISPLAYS, display, &numDisplays);
    if (err != CGDisplayNoErr) {
        NSLog(@"error getting displays");
        return NULL;
    }
    CGImageRef imageRef = CGDisplayCreateImage(display[0]);
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
}

- (CGContextRef)createSRGBContextFromImage:(CGImageRef) image {
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);

    // each pixels is 4 bytes, red, green, blue, and unused
    static size_t kBitsPerComponent = 8;
    size_t bytesPerRow = width * 4;
    size_t byteCount = bytesPerRow * height;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (colorSpace == NULL) {
        NSLog(@"error allocating color space");
    }

    void *bitmapData = malloc(byteCount);
    if (bitmapData == NULL) {
        NSLog(@"error allocating memory");
        CGColorSpaceRelease(colorSpace);
        return NULL;
    }

    CGContextRef context = CGBitmapContextCreate(bitmapData, width, height, kBitsPerComponent,
                                                 bytesPerRow, colorSpace,
                                                 (CGBitmapInfo) kCGImageAlphaNoneSkipLast);
    if (context == NULL) {
        NSLog(@"error creating context");
        free(bitmapData);
    }

    CGColorSpaceRelease(colorSpace);

    return context;
}

@end
