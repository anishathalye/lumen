//
//  BrightnessController.m
//  Lumen
//
//  Created by Anish Athalye on 4/10/15.
//  Copyright (c) 2015 Anish Athalye. All rights reserved.
//

#import "BrightnessController.h"

@interface BrightnessController ()

@property (nonatomic) BOOL running;

@end

@implementation BrightnessController

- (BOOL)isRunning {
    return self.running;
}

- (void)start {
    self.running = YES;
}

- (void)stop {
    self.running = NO;
}

@end
