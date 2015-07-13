//
//  TFPGCodeHelpers.h
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-07-13.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPGCode.h"

@interface TFPGCode (TFPHelpers)
+ (double)convertFeedRate:(double)feedRate;

+ (instancetype)moveToOriginCode;
+ (instancetype)turnOffMotorsCode;
+ (instancetype)moveWithPosition:(TFP3DVector*)position withFeedRate:(double)feedRate;

+ (instancetype)absoluteModeCode;
+ (instancetype)relativeModeCode;
@end