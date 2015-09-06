//
//  TFPZeroBedOperation.m
//  microprint
//
//  Created by William Waggoner on 7/29/15.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPZeroBedOperation.h"
#import "TFPExtras.h"
#import "TFPGCodeHelpers.h"
#import "TFP3DVector.h"


@interface TFPZeroBedOperation ()
@property BOOL stopped;
@property (readwrite) TFPOperationStage stage;
@end



@implementation TFPZeroBedOperation
@synthesize stage=_stage;


- (BOOL)start {
	if(![super start]) {
		return NO;
	}

    const double temperature = 150; // Warm it up a bit
    const double moveFeedRate = 2900;

    TFP3DVector *parkingLocation = [TFP3DVector vectorWithX:nil Y:@90 Z:@10];


    TFPGCodeProgram *prep = [TFPGCodeProgram programWithLines:@[
																[TFPGCode codeForHeaterTemperature:temperature waitUntilDone:YES],
																[TFPGCode codeForTurningOffHeater],
																[TFPGCode turnOffFanCode],
																]];

    TFPGCodeProgram *park = [TFPGCodeProgram programWithLines:@[
																[TFPGCode absoluteModeCode],
																[TFPGCode moveWithPosition:parkingLocation feedRate:moveFeedRate],
																[TFPGCode waitForCompletionCode],
																]];

    if(self.progressFeedback) {
        self.progressFeedback(@"Heating up…");
    }
	
	self.stage = TFPOperationStagePreparation;

    [self.context runGCodeProgram:prep completionHandler:^(BOOL success, NSArray *valueDictionaries) {
        if (self.stopped) {
			[self doStopCompleted:NO];
			
        }else{
            if(self.progressFeedback) {
                self.progressFeedback(@"Finding Bed Location…");
            }

			self.stage = TFPOperationStageRunning;
            [self.context sendGCode:[TFPGCode findZeroCode] responseHandler:^(BOOL success, TFPGCodeResponseDictionary value) {
				self.stage = TFPOperationStageEnding;
                if (self.stopped) {
                    [self doStopCompleted:NO];
					
                }else{
                    if(self.progressFeedback) {
                        self.progressFeedback(@"Parking Print Head…");
                    }

                    [self.context runGCodeProgram:park completionHandler:^(BOOL success, NSArray *valueDictionaries) {
						[self doStopCompleted:YES];
                    }];
                }
            }];
        }
    }];
	
	return YES;
}


- (void)stop {
    [super stop];
    self.stopped = YES;
    if(self.progressFeedback) {
        self.progressFeedback(@"Stopping...");
    }
}


- (NSString *)activityDescription {
    return @"Calibrating bed location";
}


- (void)doStopCompleted:(BOOL)completed {
    [self ended];
    if(self.didStopBlock) {
        self.didStopBlock(completed);
    }
}


- (TFPOperationKind)kind {
	return TFPOperationKindCalibration;
}


@end