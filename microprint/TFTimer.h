//
//  TFTimer.h
//  Tåg
//
//  Created by Tomas Franzén on sön 2015-03-29.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TFTimer : NSObject
+ (instancetype)timerWithInterval:(NSTimeInterval)interval repeating:(BOOL)repeat block:(void(^)())action;
- (void)invalidate;
@end