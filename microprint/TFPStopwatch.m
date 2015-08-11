//
//  TFPStopwatch.m
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-08-10.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPStopwatch.h"
#import "TFPExtras.h"
#import "TFTimer.h"


@interface TFPStopwatch ()
@property NSTimeInterval storedTime;
@property uint64_t startTime;

@property TFTimer *updateTimer;
@end


@implementation TFPStopwatch


- (void)start {
	__weak __typeof__(self) weakSelf = self;
	
	self.startTime = TFNanosecondTime();
	self.updateTimer = [TFTimer timerWithInterval:1 repeating:YES block:^{
		[weakSelf willChangeValueForKey:@"elapsedTime"];
		[weakSelf didChangeValueForKey:@"elapsedTime"];
	}];
}


- (void)stop {
	self.storedTime = self.elapsedTime;
	self.startTime = 0;
	self.updateTimer = nil;
}


- (void)reset {
	[self stop];
	self.storedTime = 0;
}


- (NSTimeInterval)elapsedTime {
	double duration = self.storedTime;
	if(self.startTime > 0) {
		duration += ((double)(TFNanosecondTime() - self.startTime)) / NSEC_PER_SEC;
	}
	return duration;
}


@end