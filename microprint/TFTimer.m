//
//  TFTimer.m
//  Tåg
//
//  Created by Tomas Franzén on sön 2015-03-29.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFTimer.h"

@interface TFTimer ()
@property (weak) NSTimer *timer;
@end



@implementation NSObject (TFTimerBlockInvocation)

- (void)tftimer_invoke {
	((void(^)())self)();
}

@end



@implementation TFTimer


- (instancetype)initWithInterval:(NSTimeInterval)interval repeating:(BOOL)repeat block:(void(^)())action {
	if(!(self = [super init])) return nil;
	
	action = [action copy];
	self.timer = [NSTimer scheduledTimerWithTimeInterval:interval target:action selector:@selector(tftimer_invoke) userInfo:nil repeats:repeat];
	
	return self;
}


+ (instancetype)timerWithInterval:(NSTimeInterval)interval repeating:(BOOL)repeat block:(void(^)())action {
	return [[self alloc] initWithInterval:interval repeating:repeat block:action];
}


- (void)dealloc {
	[self invalidate];
}


- (void)invalidate {
	[self.timer invalidate];
	self.timer = nil;
}


@end