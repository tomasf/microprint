//
//  TFPGCodeHelpers.h
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-07-13.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPGCode.h"
#import "TFPGCodeProgram.h"


@interface TFPGCode (TFPHelpers)
+ (double)convertFeedRate:(double)feedRate;

+ (instancetype)codeForSettingLineNumber:(uint16_t)lineNumber;
- (instancetype)codeBySettingLineNumber:(uint16_t)lineNumber;

+ (instancetype)stopCode;

+ (instancetype)waitCodeWithDuration:(NSUInteger)seconds;

+ (instancetype)moveHomeCode;
+ (instancetype)turnOnMotorsCode;
+ (instancetype)turnOffMotorsCode;

+ (instancetype)codeForSettingPosition:(TFP3DVector*)position E:(NSNumber*)E;
+ (instancetype)resetExtrusionCode;

+ (instancetype)codeForSettingFeedRate:(double)feedRate raw:(BOOL)raw;

+ (instancetype)moveWithPosition:(TFP3DVector*)position withRawFeedRate:(double)F;
+ (instancetype)moveWithPosition:(TFP3DVector*)position withFeedRate:(double)feedRate;

+ (instancetype)codeForExtrusion:(double)E withRawFeedRate:(double)feedRate;
+ (instancetype)codeForExtrusion:(double)E withFeedRate:(double)feedRate;

+ (instancetype)absoluteModeCode;
+ (instancetype)relativeModeCode;

+ (instancetype)codeForHeaterTemperature:(double)temperature waitUntilDone:(BOOL)wait;
+ (instancetype)codeForTurningOffHeater;

+ (instancetype)codeForSettingFanSpeed:(double)speed;
+ (instancetype)turnOffFanCode;
@end



@interface TFPGCodeProgram (TFPHelpers)

- (TFP3DVector*)measureSize;
- (void)enumerateMovesWithBlock:(void(^)(TFPAbsolutePosition from, TFPAbsolutePosition to, double feedRate))block;

@end