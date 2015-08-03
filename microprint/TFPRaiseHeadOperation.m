//
//  TFPRaiseHeadOperation.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPRaiseHeadOperation.h"
#import "TFPExtras.h"
#import "TFPGCodeHelpers.h"


@interface TFPRaiseHeadOperation ()
@property BOOL stopped;
@end


static const double raiseStep = 0.1;


@implementation TFPRaiseHeadOperation


- (void)raiseStepFromZ:(double)Z toLevel:(double)targetHeight completionHandler:(void(^)())completionHandler {
	if(self.stopped || Z >= targetHeight) {
		completionHandler();
		return;
	}
	
	Z += raiseStep;
	
	TFP3DVector *position = [TFP3DVector zVector:Z];
	[self.printer moveToPosition:position usingFeedRate:2000 completionHandler:^(BOOL success) {
		[self raiseStepFromZ:Z toLevel:targetHeight completionHandler:completionHandler];
	}];
}


- (void)start {
	[super start];
	double targetHeight = self.targetHeight;
		
	[self.printer fetchPositionWithCompletionHandler:^(BOOL success, TFP3DVector *position, NSNumber *E) {
		[self.printer setRelativeMode:NO completionHandler:^(BOOL success) {
			double Z = position.z.doubleValue;
			
			if(Z < targetHeight) {
				if(self.didStartBlock) {
					self.didStartBlock();
				}
				
				[self raiseStepFromZ:Z toLevel:targetHeight completionHandler:^{
					[self.printer sendGCode:[TFPGCode turnOffMotorsCode] responseHandler:^(BOOL success, NSDictionary *value) {
						if(self.didStopBlock) {
							self.didStopBlock(YES);
							[self ended];
						}
					}];
				}];
			}else{
				if(self.didStopBlock) {
					[self ended];
					self.didStopBlock(NO);
				}
			}
		}];
	}];
}


- (void)stop {
	[super stop];
	self.stopped = YES;
}


- (NSString *)activityDescription {
	return @"Raising Print Head";
}


@end