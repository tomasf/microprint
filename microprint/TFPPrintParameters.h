//
//  TFPPrintParameters.h
//  MicroPrint
//
//  Created by Tomas Franzén on Mon 2015-06-22.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger, TFPFilamentType) {
	TFPFilamentTypeUnknown,
	TFPFilamentTypePLA,
	TFPFilamentTypeABS,
	TFPFilamentTypeHIPS,
	TFPFilamentTypeOther,
};


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
} TFPBacklashValues;


@interface TFPPrintParameters : NSObject
@property (readwrite) NSUInteger bufferSize;
@property (readwrite) BOOL verbose;

@property (readwrite) TFPFilamentType filamentType;
@property (readwrite) double idealTemperature;
@property (readwrite) double maxZ;

@property (readwrite) TFPBedLevelOffsets bedLevelOffsets;
@property (readwrite) TFPBacklashValues backlashValues;
@property (readwrite) double backlashCompensationSpeed;

@property (readwrite) BOOL useWaveBonding;
@property (readwrite) BOOL useBacklashCompensation;

@property (readonly) NSString *bedLevelOffsetsAsString;
@property (readonly) NSString *backlashValuesAsString;
@end