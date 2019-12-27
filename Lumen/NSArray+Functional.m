// Copyright (c) 2015-2019 Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#import "NSArray+Functional.h"

@implementation NSArray (Functional)

- (NSArray *)map:(id (^)(id x))function {
    NSMutableArray *array = [NSMutableArray new];
    for (id value in self) {
        [array addObject:function(value)];
    }
    return array;
}

@end
