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
#import "TFP3DVector.h"


@interface TFPRaiseHeadOperation ()
@property BOOL stopped;
@property (readwrite) TFPOperationStage stage;
@end


static const double raiseStep = 0.1;


@implementation TFPRaiseHeadOperation
@synthesize stage=_stage;


- (void)raiseStepFromZ:(double)Z toLevel:(double)targetHeight completionHandler:(void(^)())completionHandler {
	if(self.stopped || Z >= targetHeight) {
		completionHandler();
		return;
	}
	
	Z += raiseStep;
	
	TFP3DVector *position = [TFP3DVector zVector:Z];
	[self.context moveToPosition:position usingFeedRate:3000 completionHandler:^(BOOL success) {
		[self raiseStepFromZ:Z toLevel:targetHeight completionHandler:completionHandler];
	}];
}


- (BOOL)start {
	if(![super start]) {
		return NO;
	}

	double targetHeight = self.targetHeight;
	self.stage = TFPOperationStagePreparation;
	
	[self.printer fetchPositionWithCompletionHandler:^(BOOL success, TFP3DVector *position, NSNumber *E) {
		[self.context setRelativeMode:NO completionHandler:^(BOOL success) {
			double Z = position.z.doubleValue;
			
			if(Z < targetHeight) {
				if(self.didStartBlock) {
					self.didStartBlock();
				}
				self.stage = TFPOperationStageRunning;
				
				[self raiseStepFromZ:Z toLevel:targetHeight completionHandler:^{
					self.stage = TFPOperationStageEnding;
					
					[self.printer sendGCode:[TFPGCode turnOffMotorsCode] responseHandler:^(BOOL success, NSDictionary *value) {
						if(self.didStopBlock) {
							self.didStopBlock(YES);
						}
						[self ended];
					}];
				}];
			}else{
				if(self.didStopBlock) {
					self.didStopBlock(NO);
				}
				[self ended];
			}
		}];
	}];
	
	return YES;
}


- (void)stop {
	[super stop];
	self.stopped = YES;
}


- (TFPOperationKind)kind {
	return TFPOperationKindUtility;
}


- (NSString *)activityDescription {
	return @"Raising Print Head";
}


@end