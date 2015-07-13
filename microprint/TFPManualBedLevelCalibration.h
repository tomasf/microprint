//
//  TFPManualBedLevelCalibration.h
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-07-12.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPOperation.h"

@interface TFPManualBedLevelCalibration : TFPOperation
- (void)start;

@property double startZ;
@property double heightTarget;
@end
