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


@interface TFPPrinter : NSObject
- (instancetype)initWithConnection:(TFPPrinterConnection*)connection;

@property TFPOperation *currentOperation;

- (void)establishConnectionWithCompletionHandler:(void(^)(NSError *error))completionHandler;
- (BOOL)printerShouldBeInvalidatedWithRemovedSerialPorts:(NSArray*)ports;
@property (readonly) BOOL pendingConnection;

@property (copy) void(^outgoingCodeBlock)(NSString *string);
@property (copy) void(^incomingCodeBlock)(NSString *string);
@property (copy) void(^noticeBlock)(NSString *string);

@property (readonly) double speedMultiplier;


// Basics. Implied response queue is main.
- (void)sendGCode:(TFPGCode*)code responseHandler:(void(^)(BOOL success, NSDictionary *value))block;
- (void)sendGCode:(TFPGCode*)code responseHandler:(void(^)(BOOL success, NSDictionary *value))block responseQueue:(dispatch_queue_t)queue;
- (void)runGCodeProgram:(TFPGCodeProgram*)program completionHandler:(void(^)(BOOL success, NSArray *valueDictionaries))completionHandler;
- (void)runGCodeProgram:(TFPGCodeProgram*)program completionHandler:(void(^)(BOOL success, NSArray *valueDictionaries))completionHandler responseQueue:(dispatch_queue_t)queue;


// State (observable)
@property (readonly) TFPPrinterColor color;
@property (readonly, copy) NSString *serialNumber;
@property (readonly, copy) NSString *firmwareVersion;

@property (readonly) double heaterTemperature;
@property (readonly) BOOL hasValidZLevel;

+ (NSString*)nameForPrinterColor:(TFPPrinterColor)color;
@end


#import "TFPPrinterHelpers.h"