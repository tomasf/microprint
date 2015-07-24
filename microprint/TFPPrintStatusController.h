//
//  TFPPrintStatusController.h
//  microprint
//
//  Created by Tomas Franzén on Wed 2015-07-15.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TFPPrintJob.h"
#import "TFPGCodeHelpers.h"

@interface TFPPrintStatusController : NSObject
- (instancetype)initWithPrintJob:(TFPPrintJob*)printJob;

// Properties are observable
@property (readonly) NSTimeInterval elapsedTime;
@property (readonly) NSTimeInterval estimatedRemainingTime;
@property (readonly) BOOL hasRemainingTimeEstimate;

@property (readonly) double printProgress;
@property (readonly) TFPPrintPhase currentPhase;
@property (readonly) double phaseProgress;
@property (readonly) TFPPrintLayer *currentLayer;
@property (readonly) NSUInteger layerCount;

@property (copy) void(^willMoveHandler)(TFPAbsolutePosition from, TFPAbsolutePosition to, double feedRate, TFPGCode *code);
@property (copy) void(^layerChangeHandler)();
@end
