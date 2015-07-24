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
+ (instancetype)stopCode;
+ (instancetype)waitCodeWithDuration:(NSUInteger)seconds;

// Line numbering
+ (instancetype)codeForSettingLineNumber:(uint16_t)lineNumber;
- (instancetype)codeBySettingLineNumber:(uint16_t)lineNumber;

// Feed rates
+ (double)convertFeedRate:(double)feedRate;
+ (instancetype)codeForSettingFeedRate:(double)feedRate raw:(BOOL)raw;

// Motors
+ (instancetype)turnOnMotorsCode;
+ (instancetype)turnOffMotorsCode;

// Positioning
+ (instancetype)absoluteModeCode;
+ (instancetype)relativeModeCode;
+ (instancetype)codeForResettingPosition:(TFP3DVector*)position extrusion:(NSNumber*)E;

// Moving
+ (instancetype)moveHomeCode;
+ (instancetype)moveWithPosition:(TFP3DVector*)position extrusion:(NSNumber*)E withRawFeedRate:(double)F;
+ (instancetype)moveWithPosition:(TFP3DVector*)position withRawFeedRate:(double)F;
+ (instancetype)moveWithPosition:(TFP3DVector*)position withFeedRate:(double)feedRate;

// Extrusion
+ (instancetype)codeForExtrusion:(double)E withRawFeedRate:(double)feedRate;
+ (instancetype)codeForExtrusion:(double)E withFeedRate:(double)feedRate;
+ (instancetype)resetExtrusionCode;

// Heater
+ (instancetype)codeForHeaterTemperature:(double)temperature waitUntilDone:(BOOL)wait;
+ (instancetype)codeForTurningOffHeater;

// Fan
+ (instancetype)turnOnFanCode;
+ (instancetype)turnOffFanCode;
+ (instancetype)codeForSettingFanSpeed:(double)speed;

// Virtual EEPROM
+ (instancetype)codeForReadingVirtualEEPROMAtIndex:(NSUInteger)valueIndex;
+ (instancetype)codeForWritingVirtualEEPROMAtIndex:(NSUInteger)valueIndex value:(int32_t)value;

// Utilities
+ (NSDictionary*)dictionaryFromResponseValueString:(NSString*)string;
@end


typedef NS_ENUM(NSUInteger, TFPPrintPhase) {
	TFPPrintPhaseInvalid,
	TFPPrintPhasePreamble,
	TFPPrintPhaseAdhesion,
	TFPPrintPhaseModel,
	TFPPrintPhasePostamble,
};



@interface TFPGCodeProgram (TFPHelpers)
- (TFP3DVector*)measureSize;

- (void)enumerateMovesWithBlock:(void(^)(TFPAbsolutePosition from, TFPAbsolutePosition to, double feedRate, TFPGCode *code, NSUInteger index))block;

- (BOOL)validateForM3D:(NSError**)error;
- (NSDictionary*)curaProfileValues;

// Keys are NSNumber-wrapped TFPPrintPhases
// Values are NSValue-wrapped NSRanges
- (NSDictionary*)determinePhaseRanges;

@end