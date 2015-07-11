//
//  TFPBedHeightCalibrationOperation.h
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPOperation.h"

@class TFPPrintParameters;

@interface TFPBedLevelCalibrationOperation : TFPOperation
- (void)startWithPrintParameters:(TFPPrintParameters*)params;
@end