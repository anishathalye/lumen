// Copyright (c) 2015-2019 Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#import <Foundation/Foundation.h>

@interface BrightnessController : NSObject

@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, readonly) BOOL isUsingNewAPI;

- (id)init:(BOOL)shouldUseNewAPI;
- (void)start;
- (void)stop;
- (void)toggleExperimentalMode;

@end
