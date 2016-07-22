//
//  Model.m
//  Lumen
//
//  Created by Anish Athalye on 7/21/16.
//  Copyright © 2016 Anish Athalye. All rights reserved.
//

#import "Model.h"

#define MIN_X_SPACING (0.1f)

@interface XYPoint : NSObject

@property float x;
@property float y;

- (id)initWithX:(float)x andY:(float)y;

@end

@implementation XYPoint

- (id)initWithX:(float)x andY:(float)y {
    self = [super init];
    if (self) {
        self.x = x;
        self.y = y;
    }
    return self;
}

@end

@interface Model ()

@property (nonatomic, strong) NSMutableArray *points;

@end

@implementation Model

- (id)init {
    self = [super init];
    if (self) {
        self.points = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)observeOutput:(float)output forInput:(float)input {
    // add point
    XYPoint *point = [[XYPoint alloc] initWithX:input andY:output];
    [self.points addObject:point];
    // ensure that they're sorted
    [self.points sortUsingComparator:^NSComparisonResult(XYPoint *obj1, XYPoint *obj2) {
        float first = obj1.x;
        float second = obj2.x;
        if (first < second) {
            return NSOrderedAscending;
        }
        else if (first > second) {
            return NSOrderedDescending;
        }
        else {
            return NSOrderedSame;
        }
    }];
    // get current inserted point
    NSInteger index = [self.points indexOfObject:point];
    // remove points that are not monotonically decreasing / not spaced apart enough
    NSMutableIndexSet *toDelete = [[NSMutableIndexSet alloc] init];
    float prevx = point.x, prevy = point.y;
    for (NSInteger i = index - 1; i >= 0; i--) {
        XYPoint *p = [self.points objectAtIndex:i];
        if (p.y <= prevy || (prevx - p.x) < MIN_X_SPACING) {
            [toDelete addIndex:i];
        }
        else {
            prevx = p.x;
            prevy = p.y;
        }
    }
    prevx = point.x;
    prevy = point.y; // reset these
    for (NSInteger i = index + 1; i < self.points.count; i++) {
        XYPoint *p = [self.points objectAtIndex:i];
        if (p.y >= prevy || (p.x - prevx) < MIN_X_SPACING) {
            [toDelete addIndex:i];
        }
        else {
            prevx = p.x;
            prevy = p.y;
        }
    }
    [self.points removeObjectsAtIndexes:toDelete];
}

- (float)predictFromInput:(float)input {
    // nearest neighbor
    // would a line of best fit be better?
    float bestdiff = FLT_MAX, besty = 1;
    for (XYPoint *p in self.points) {
        float diff = fabsf(p.x - input);
        if (diff < bestdiff) {
            bestdiff = diff;
            besty = p.y;
        }
    }
    return besty;
}

@end
