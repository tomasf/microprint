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


- (void)start {
    [super start];

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
//                                [TFPGCode codeWithField:'G' value:28],      // Value to speed up testing
                                ]];

    TFPGCodeProgram *park = [TFPGCodeProgram programWithLines:@[
                                [TFPGCode moveWithPosition:parkingLocation feedRate:moveFeedRate],
                                [TFPGCode waitCodeWithDuration:0],
                                ]];

    if(self.progressFeedback) {
        self.progressFeedback(@"Zero prep - warming the print head.");
    }
	
	self.stage = TFPOperationStagePreparation;

    [printer runGCodeProgram:prep completionHandler:^(BOOL success, NSArray *valueDictionaries) {
        if (weakSelf.stopped) {
            [weakSelf doStop];
        }else{

            if(weakSelf.progressFeedback) {
                weakSelf.progressFeedback(@"Running Zero routine");
            }

			self.stage = TFPOperationStageRunning;
            [printer runGCodeProgram:zero completionHandler:^(BOOL success, NSArray *valueDictionaries) {
				self.stage = TFPOperationStageEnding;
                if (weakSelf.stopped) {
                    [weakSelf doStop];
                }else{
                    
                    if(weakSelf.progressFeedback) {
                        weakSelf.progressFeedback(@"Zeroing done, parking...");
                    }

                    [printer runGCodeProgram:park completionHandler:^(BOOL success, NSArray *valueDictionaries) {
                        [weakSelf doStop];
                    }];
                }
            }];
        }
    }];
}

- (void)stop {
    [super stop];
    self.stopped = YES;
    if(self.progressFeedback) {
        self.progressFeedback(@"Stopping...");
    }
}

- (NSString *)activityDescription {
    return @"Finding bed zero height";
}

- (void)doStop {
    [self ended];
    if(self.didStopBlock) {
        self.didStopBlock();
    }
}


- (TFPOperationKind)kind {
	return TFPOperationKindCalibration;
}


@end
