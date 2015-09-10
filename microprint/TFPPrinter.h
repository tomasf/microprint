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

@class TFPOperation, TFPPrinterConnection, TFPPrinterContext;


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


typedef NS_OPTIONS(NSUInteger, TFPPrinterContextOptions) {
	TFPPrinterContextOptionConcurrent = 1<<0,
	
	TFPPrinterContextOptionDisableLevelCompensation = 1<<1,
	TFPPrinterContextOptionDisableBacklashCompensation  = 1<<2,
	TFPPrinterContextOptionDisableFeedRateConversion = 1<<3,
	
	TFPPrinterContextOptionDisableCompensation = TFPPrinterContextOptionDisableLevelCompensation | TFPPrinterContextOptionDisableBacklashCompensation,
};


extern const NSString *TFPPrinterResponseErrorCodeKey;
typedef NSDictionary<NSString *, NSString*>* TFPGCodeResponseDictionary;



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

- (void)sendNotice:(NSString*)noticeFormat, ...;

// Sending of G-code. Response queue is main.
// If success is YES, value dictionary contains parameters from OK response
// If success is NO, value dictionary contains an NSNumber-wrapped TFPPrinterResponseErrorCode in TFPPrinterResponseErrorCodeKey

- (void)sendGCode:(TFPGCode*)code responseHandler:(void(^)(BOOL success, TFPGCodeResponseDictionary value))block;

- (TFPPrinterContext*)acquireContextWithOptions:(TFPPrinterContextOptions)options queue:(dispatch_queue_t)queue;


+ (NSString*)descriptionForErrorCode:(TFPPrinterResponseErrorCode)code;

// State (observable)
@property (readonly) TFPPrinterColor color;
@property (readonly, copy) NSString *serialNumber;
@property (readonly, copy) NSString *firmwareVersion;
@property (readonly) NSComparisonResult firmwareVersionComparedToTestedRange;

@property (nonatomic) double feedrate;
@property (readonly) double heaterTargetTemperature;
@property (readonly) double heaterTemperature;

@property (readonly) BOOL hasValidZLevel;
@property (readonly) BOOL hasOutOfBoundsZLevel;

@property (nonatomic, readonly) TFPBedLevelOffsets bedBaseOffsets;
@property (nonatomic) TFPBedLevelOffsets bedLevelOffsets;
@property (readonly) BOOL hasAllZeroBedLevelOffsets;

@property (nonatomic) TFPBacklashValues backlashValues;

@property (nonatomic) TFPAbsolutePosition position;

+ (NSString*)nameForPrinterColor:(TFPPrinterColor)color;
+ (NSString*)minimumTestedFirmwareVersion;
+ (NSString*)maximumTestedFirmwareVersion;
@end


@interface TFPPrinterContext : NSObject
@property (readonly) TFPPrinter *printer;

- (void)sendGCode:(TFPGCode*)code responseHandler:(void(^)(BOOL success, TFPGCodeResponseDictionary value))block;
- (void)runGCodeProgram:(TFPGCodeProgram*)program completionHandler:(void(^)(BOOL success, NSArray<TFPGCodeResponseDictionary> *values))completionHandler;

- (void)invalidate;
@end


#import "TFPPrinterHelpers.h"