//
//  TFPZeroBedOperation.m
//  microprint
//
//  Created by William Waggoner on 7/29/15.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPZeroBedOperation.h"
#import "Extras.h"
#import "TFPGCodeHelpers.h"

@interface TFPZeroBedOperation ()

@property BOOL stopped;

@end

@implementation TFPZeroBedOperation

- (void)start {
    [super start];

    const double temperature = 150.0; // Warm it up a bit

    const double moveFeedRate = 2900;

    TFP3DVector *parkingLocation = [TFP3DVector vectorWithX:nil Y:@90.0 Z:@10.0];
    
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
    
    TFLog(@"Zero prep");

    if(self.prepStartedBlock) {
        TFLog(@"didStart Prep");
        self.prepStartedBlock();
    }

    [printer runGCodeProgram:prep completionHandler:^(BOOL success) {

        if(self.zeroStartedBlock) {
            TFLog(@"didStart Zero");
            weakSelf.zeroStartedBlock();
        }

        [printer runGCodeProgram:zero completionHandler:^(BOOL success) {

            TFLog(@"Zeroing done, parking...");
            [printer moveToPosition:parkingLocation usingFeedRate:moveFeedRate completionHandler:^(BOOL success) {
                if(weakSelf.didStopBlock) {
                    TFLog(@"didStop");
                    [weakSelf ended];
                    weakSelf.didStopBlock(YES);
                }
            }];
        }];
    }];



}

- (void)stop {
    [super stop];
    self.stopped = YES;
}

- (NSString *)activityDescription {
    return @"Finding bed zero height";
}

@end
