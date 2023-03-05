// Copyright (c) Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#import <Foundation/Foundation.h>

@interface BrightnessController : NSObject

@property (nonatomic, readonly) BOOL isRunning;

- (void)start;
- (void)stop;

@end
