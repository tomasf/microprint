//
//  TFPBedLevelCompensator.h
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-08-20.
//  Copyright © 2015 Tomas Franzén. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TFPPrintParameters.h"


@interface TFPBedLevelCompensator : NSObject
- (instancetype)initWithBedLevel:(TFPBedLevelOffsets)level;

- (double)zAdjustmentAtX:(double)x Y:(double)y;
@end