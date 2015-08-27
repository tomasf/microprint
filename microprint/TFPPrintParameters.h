//
//  TFPPrintParameters.h
//  MicroPrint
//
//  Created by Tomas Franzén on Mon 2015-06-22.
//

@import Foundation;
#import "TFPFilament.h"
#import "TFPGCodeHelpers.h"


typedef struct {
	double common;
	double backLeft;
	double backRight;
	double frontRight;
	double frontLeft;
} TFPBedLevelOffsets;


typedef struct {
	double x;
	double y;
	double speed;
} TFPBacklashValues;


extern NSString *TFPBedLevelOffsetsDescription(TFPBedLevelOffsets offsets);
extern NSString *TFPBacklashValuesDescription(TFPBacklashValues values);


@interface TFPPrintParameters : NSObject
@property (readwrite) BOOL verbose;

@property (readwrite) TFPFilament *filament;
@property (readwrite) BOOL useWaveBonding;
@property (readwrite, nonatomic) double idealTemperature;

@property (readwrite) TFPCuboid boundingBox;
@end