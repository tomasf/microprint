//
//  TFPBedHeightCalibrationOperation.h
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TFPPrinter, TFPPrintParameters;

@interface TFPBedLevelCalibrationOperation : NSObject
- (instancetype)initWithPrinter:(TFPPrinter*)printer;
- (void)startWithPrintParameters:(TFPPrintParameters*)params;
@end
