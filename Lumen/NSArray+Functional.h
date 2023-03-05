// Copyright (c) Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#import <Foundation/Foundation.h>

@interface NSArray (Functional)

NS_ASSUME_NONNULL_BEGIN

- (NSArray *)map:(id (^)(id x))function;

NS_ASSUME_NONNULL_END

@end
