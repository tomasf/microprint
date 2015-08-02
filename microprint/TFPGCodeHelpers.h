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
+ (instancetype)waitCodeWithDuration:(NSTimeInterval)seconds;
+ (instancetype)waitForMoveCompletionCode;

// Line numbering
+ (instancetype)codeForSettingLineNumber:(uint16_t)lineNumber;
- (instancetype)codeBySettingLineNumber:(uint16_t)lineNumber;

// Feed rates
+ (instancetype)codeForSettingFeedRate:(double)feedRate;

// Motors
+ (instancetype)turnOnMotorsCode;
+ (instancetype)turnOffMotorsCode;

// Positioning
+ (instancetype)absoluteModeCode;
+ (instancetype)relativeModeCode;
+ (instancetype)codeForResettingPosition:(TFP3DVector*)position extrusion:(NSNumber*)E;

// Moving
+ (instancetype)moveHomeCode;
+ (instancetype)moveWithPosition:(TFP3DVector*)position extrusion:(NSNumber*)E feedRate:(double)F;
+ (instancetype)moveWithPosition:(TFP3DVector*)position feedRate:(double)feedRate;

// Extrusion
+ (instancetype)codeForExtrusion:(double)E feedRate:(double)feedRate;
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

@property (readonly) NSInteger layerIndexFromComment;
@end


typedef NS_ENUM(NSUInteger, TFPPrintPhase) {
	TFPPrintPhaseInvalid,
	TFPPrintPhasePreamble,
	TFPPrintPhaseAdhesion,
	TFPPrintPhaseModel,
	TFPPrintPhasePostamble,
};


@interface TFPPrintLayer : NSObject
@property (readonly) NSInteger layerIndex;
@property (readonly) TFPPrintPhase phase;
@property (readonly) NSRange lineRange;
@property (readonly) double minZ;
@property (readonly) double maxZ;
@end


typedef struct {
	double x;
	double y;
	double z;
	double xSize;
	double ySize;
	double zSize;
} TFPCuboid;


@interface TFPGCodeProgram (TFPHelpers)
- (TFPCuboid)measureBoundingBox;

- (void)enumerateMovesWithBlock:(void(^)(TFPAbsolutePosition from, TFPAbsolutePosition to, double feedRate, TFPGCode *code, NSUInteger index))block;

- (BOOL)validateForM3D:(NSError**)error;
- (NSDictionary*)curaProfileValues;

// Keys are NSNumber-wrapped TFPPrintPhases
// Values are NSValue-wrapped NSRanges
- (NSDictionary*)determinePhaseRanges;

- (NSArray*)determineLayers;
@end