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

    __weak TFPPrinter *printer = self.printer;
    __weak __typeof__(self) weakSelf = self;

    TFPGCodeProgram *prep = [TFPGCodeProgram programWithLines:@[
																[TFPGCode codeForHeaterTemperature:temperature waitUntilDone:YES],
																[TFPGCode codeForTurningOffHeater],
																[TFPGCode turnOffFanCode],
                                ]];

    TFPGCodeProgram *zero = [TFPGCodeProgram programWithLines:@[
																[TFPGCode codeWithField:'G' value:30],
                                ]];

    TFPGCodeProgram *park = [TFPGCodeProgram programWithLines:@[
																[TFPGCode absoluteModeCode],
																[TFPGCode moveWithPosition:parkingLocation feedRate:moveFeedRate],
																[TFPGCode waitCodeWithDuration:0],
																]];

    if(self.progressFeedback) {
        self.progressFeedback(@"Heating up…");
    }
	
	self.stage = TFPOperationStagePreparation;

    [printer runGCodeProgram:prep completionHandler:^(BOOL success, NSArray *valueDictionaries) {
        if (weakSelf.stopped) {
			[weakSelf doStopCompleted:NO];
        }else{

            if(weakSelf.progressFeedback) {
                weakSelf.progressFeedback(@"Finding Bed Location…");
            }

			self.stage = TFPOperationStageRunning;
            [printer runGCodeProgram:zero completionHandler:^(BOOL success, NSArray *valueDictionaries) {
				self.stage = TFPOperationStageEnding;
                if (weakSelf.stopped) {
                    [weakSelf doStopCompleted:NO];
                }else{
                    
                    if(weakSelf.progressFeedback) {
                        weakSelf.progressFeedback(@"Parking Print Head…");
                    }

                    [printer runGCodeProgram:park completionHandler:^(BOOL success, NSArray *valueDictionaries) {
						[weakSelf doStopCompleted:YES];
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