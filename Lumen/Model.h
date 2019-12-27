// Copyright (c) 2015-2019 Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#import <Foundation/Foundation.h>

@interface Model : NSObject

- (void)observeOutput:(float)output forInput:(float)input;
- (float)predictFromInput:(float)input;

@end
