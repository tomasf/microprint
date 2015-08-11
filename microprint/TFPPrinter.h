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

@class TFPOperation, TFPPrinterConnection;


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


typedef NS_ENUM(NSUInteger, TFPPrinterResponseErrorCode) {
	TFPPrinterResponseErrorCodeM110MissingLineNumber = 1000,
	TFPPrinterResponseErrorCodeCannotColdExtrude,
	TFPPrinterResponseErrorCodeCannotCalibrateInUnknownState,
	TFPPrinterResponseErrorCodeUnknownGCode,
	TFPPrinterResponseErrorCodeUnknownMCode,
	TFPPrinterResponseErrorCodeUnknownCommand,
	TFPPrinterResponseErrorCodeHeaterFailed,
	TFPPrinterResponseErrorCodeMoveTooLarge,
	TFPPrinterResponseErrorCodeIdleTimeHeaterAndMotorsTurnedOff,
	TFPPrinterResponseErrorCodeTargetAddressOutOfRange,
	
	TFPPrinterResponseErrorCodeMin = TFPPrinterResponseErrorCodeM110MissingLineNumber,
	TFPPrinterResponseErrorCodeMax = TFPPrinterResponseErrorCodeTargetAddressOutOfRange,
};


extern const NSString *TFPPrinterResponseErrorCodeKey;


@interface TFPPrinter : NSObject
- (instancetype)initWithConnection:(TFPPrinterConnection*)connection;
@property (readonly) TFPPrinterConnection *connection;

@property TFPOperation *currentOperation;

- (void)establishConnectionWithCompletionHandler:(void(^)(NSError *error))completionHandler;
- (BOOL)printerShouldBeInvalidatedWithRemovedSerialPorts:(NSArray*)ports;
@property (readonly) BOOL pendingConnection;

@property (copy) void(^outgoingCodeBlock)(NSString *string);
@property (copy) void(^incomingCodeBlock)(NSString *string);
@property (copy) void(^noticeBlock)(NSString *string);

@property (readonly) double speedMultiplier;


// Sending of G-code. Implied response queue is main.
// If success is YES, value dictionary contains parameters from OK response
// If success is NO, value dictionary contains an NSNumber-wrapped TFPPrinterResponseErrorCode in TFPPrinterResponseErrorCodeKey

- (void)sendGCode:(TFPGCode*)code responseHandler:(void(^)(BOOL success, NSDictionary *value))block;
- (void)sendGCode:(TFPGCode*)code responseHandler:(void(^)(BOOL success, NSDictionary *value))block responseQueue:(dispatch_queue_t)queue;
- (void)runGCodeProgram:(TFPGCodeProgram*)program completionHandler:(void(^)(BOOL success, NSArray *valueDictionaries))completionHandler;
- (void)runGCodeProgram:(TFPGCodeProgram*)program completionHandler:(void(^)(BOOL success, NSArray *valueDictionaries))completionHandler responseQueue:(dispatch_queue_t)queue;

+ (NSString*)descriptionForErrorCode:(TFPPrinterResponseErrorCode)code;

// State (observable)
@property (readonly) TFPPrinterColor color;
@property (readonly, copy) NSString *serialNumber;
@property (readonly, copy) NSString *firmwareVersion;
@property (readonly) NSComparisonResult firmwareVersionComparedToTestedRange;

@property (readonly) double feedrate;
@property (readonly) double heaterTemperature;
@property (readonly) BOOL hasValidZLevel;

@property (nonatomic) TFPBedLevelOffsets bedLevelOffsets;
@property (readonly) BOOL hasAllZeroBedLevelOffsets;

+ (NSString*)nameForPrinterColor:(TFPPrinterColor)color;
+ (NSString*)minimumTestedFirmwareVersion;
+ (NSString*)maximumTestedFirmwareVersion;
@end


#import "TFPPrinterHelpers.h"