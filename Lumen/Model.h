//
//  Model.h
//  Lumen
//
//  Created by Anish Athalye on 7/21/16.
//  Copyright © 2016 Anish Athalye. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Model : NSObject

- (void)observeOutput:(float)output forInput:(float)input;
- (float)predictFromInput:(float)input;

@end
