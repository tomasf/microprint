//
//  TFPPrinter.h
//  MicroPrint
//
//  Created by Tomas Franzén on Tue 2015-06-23.
//

#import <Foundation/Foundation.h>
#import "ORSSerialPort.h"
#import "TFPGCode.h"
#import "TFPPrintParameters.h"
#import "TFPGCodeProgram.h"

@class TFPOperation;


typedef NS_ENUM(NSUInteger, TFPPrinterColor) {
	TFPPrinterColorUndetermined,
	TFPPrinterColorBlack,
	TFPPrinterColorSilver,
	TFPPrinterColorLightBlue,
	TFPPrinterColorGreen,
	TFPPrinterColorOrange,
	TFPPrinterColorWhite,
	TFPPrinterColorGrape,
	TFPPrinterColorOther,
};


@interface TFPPrinter : NSObject
- (instancetype)initWithSerialPort:(ORSSerialPort*)serialPort;
@property (readonly) ORSSerialPort *serialPort;

@property TFPOperation *currentOperation;

- (void)establishConnectionWithCompletionHandler:(void(^)(NSError *error))completionHandler;

// These properties are available after a connection has been established
@property (readonly) TFPPrinterColor color;
@property (readonly, copy) NSString *serialNumber;
@property (readonly, copy) NSString *firmwareVersion;
@property (readonly, copy) NSString *identifier;

+ (NSString*)nameForPrinterColor:(TFPPrinterColor)color;

- (void)sendGCode:(TFPGCode*)GCode responseHandler:(void(^)(BOOL success, NSString *value))block;
- (void)runGCodeProgram:(TFPGCodeProgram*)program completionHandler:(void(^)(BOOL success))completionHandler;

- (void)fetchBedOffsetsWithCompletionHandler:(void(^)(BOOL success, TFPBedLevelOffsets offsets))completionHandler;
- (void)fetchBacklashValuesWithCompletionHandler:(void(^)(BOOL success, TFPBacklashValues values))completionHandler;
- (void)fetchBacklashCompensationSpeedWithCompletionHandler:(void(^)(BOOL success, float speed))completionHandler;
- (void)fillInOffsetAndBacklashValuesInPrintParameters:(TFPPrintParameters*)params completionHandler:(void(^)(BOOL success))completionHandler;

- (void)setBedOffsets:(TFPBedLevelOffsets)offsets completionHandler:(void(^)(BOOL success))completionHandler;
- (void)setBacklashValues:(TFPBacklashValues)values completionHandler:(void(^)(BOOL success))completionHandler;
- (void)setBacklashCompensationSpeed:(float)value completionHandler:(void(^)(BOOL success))completionHandler;

- (void)fetchPositionWithCompletionHandler:(void(^)(BOOL success, TFP3DVector *position, NSNumber *E))completionHandler;

- (void)setRelativeMode:(BOOL)relative completionHandler:(void(^)(BOOL success))completionHandler;
- (void)moveToPosition:(TFP3DVector*)position usingFeedRate:(double)F completionHandler:(void(^)(BOOL success))completionHandler;

@property (copy) void(^resendHandler)(NSUInteger lineNumber);

@property (readonly) double heaterTemperature; // Observable
@property BOOL verboseMode;
@property (readonly) BOOL pendingConnection;
@end