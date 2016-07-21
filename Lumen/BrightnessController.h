//
//  BrightnessController.h
//  Lumen
//
//  Created by Anish Athalye on 4/10/15.
//  Copyright (c) 2015 Anish Athalye. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BrightnessController : NSObject

@property (readonly) BOOL isRunning;

- (void)start;
- (void)stop;

@end
