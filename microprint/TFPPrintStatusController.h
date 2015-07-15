//
//  TFPPrintStatusController.h
//  microprint
//
//  Created by Tomas Franzén on Wed 2015-07-15.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TFPPrintJob.h"


typedef NS_ENUM(NSUInteger, TFPPrintPhase) {
	TFPPrintPhaseInvalid,
	TFPPrintPhasePreamble,
	TFPPrintPhaseAdhesion,
	TFPPrintPhaseModel,
	TFPPrintPhasePostamble,
};


@interface TFPPrintStatusController : NSObject
- (instancetype)initWithPrintJob:(TFPPrintJob*)printJob;

// Properties are observable
@property (readonly) NSTimeInterval elapsedTime;
@property (readonly) NSTimeInterval estimatedRemainingTime;
@property (readonly) BOOL hasRemainingTimeEstimate;

@property (readonly) double printProgress;
@property (readonly) TFPPrintPhase currentPhase;
@property (readonly) double phaseProgress;
@end
