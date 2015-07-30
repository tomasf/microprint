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

    TFLog(@"Zero prep");

    if(self.prepStartedBlock) {
        TFLog(@"didStart Prep");
        self.prepStartedBlock();
    }

    [printer runGCodeProgram:prep completionHandler:^(BOOL success) {

        if (weakSelf.stopped) {
            [weakSelf doStop];
        }else{

            if(weakSelf.zeroStartedBlock) {
                TFLog(@"didStart Zero");
                weakSelf.zeroStartedBlock();
            }
            
            [printer runGCodeProgram:zero completionHandler:^(BOOL success) {

                if (weakSelf.stopped) {
                    [weakSelf doStop];
                }else{
                    
                    if(weakSelf.parkStartedBlock) {
                        TFLog(@"didStart Park");
                        weakSelf.parkStartedBlock();
                    }
                    
                    TFLog(@"Zeroing done, parking...");
                    [printer moveToPosition:parkingLocation usingFeedRate:moveFeedRate completionHandler:^(BOOL success) {
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
    TFLog(@"Stop requested");
}

- (NSString *)activityDescription {
    return @"Finding bed zero height";
}

- (void)doStop {
    TFLog(@"didStop");
    [self ended];
    if(self.didStopBlock) {
        self.didStopBlock();
    }
}

@end
