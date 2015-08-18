//
//  TFPGCodeHelpers.h
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-07-13.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPGCode.h"
#import "TFPGCodeProgram.h"
#import "TFP3DVector.h"


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
+ (instancetype)codeForGettingPosition;

// Extrusion
+ (instancetype)codeForExtrusion:(double)E feedRate:(double)feedRate;
+ (instancetype)resetExtrusionCode;

// Heater
+ (instancetype)codeForHeaterTemperature:(double)temperature waitUntilDone:(BOOL)wait;
+ (instancetype)codeForTurningOffHeater;
+ (instancetype)codeForReadingHeaterTemperature;

// Fan
+ (instancetype)turnOnFanCode;
+ (instancetype)turnOffFanCode;
+ (instancetype)codeForSettingFanSpeed:(double)speed;

// Virtual EEPROM
+ (instancetype)codeForReadingVirtualEEPROMAtIndex:(NSUInteger)valueIndex;
+ (instancetype)codeForWritingVirtualEEPROMAtIndex:(NSUInteger)valueIndex value:(int32_t)value;

@property (readonly) NSInteger layerIndexFromComment;

@property (readonly) TFP3DVector *movementVector;

@property (readonly) BOOL hasExtrusion;
@property (readonly) double extrusion;

@property (readonly) double feedRate;
@property (readonly) BOOL hasFeedRate;
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
	double e;
} TFPAbsolutePosition;



typedef struct {
	double x;
	double y;
	double z;
	double xSize;
	double ySize;
	double zSize;
} TFPCuboid;


extern double TFPAbsolutePositionDistance(TFPAbsolutePosition a, TFPAbsolutePosition b);

extern BOOL TFPCuboidContainsPosition(TFPCuboid cuboid, TFPAbsolutePosition position);
extern BOOL TFPCuboidContainsCuboid(TFPCuboid outer, TFPCuboid inner);
extern TFPCuboid TFPCuboidInfinite;

extern TFPCuboid TFPCuboidM3DMicroPrintVolumeLower;
extern TFPCuboid TFPCuboidM3DMicroPrintVolumeUpper;


@interface TFPGCodeProgram (TFPHelpers)
- (TFPCuboid)measureBoundingBoxWithinBox:(TFPCuboid)limit;
- (TFPCuboid)measureBoundingBox;
- (BOOL)withinM3DMicroPrintableVolume;

- (void)enumerateMovesWithBlock:(void(^)(TFPAbsolutePosition from, TFPAbsolutePosition to, double feedRate, TFPGCode *code, NSUInteger index))block;

- (BOOL)validateForM3D:(NSError**)error;
- (NSDictionary*)curaProfileValues;

// Keys are NSNumber-wrapped TFPPrintPhases
// Values are NSValue-wrapped NSRanges
- (NSDictionary*)determinePhaseRanges;

- (NSArray*)determineLayers;
@end