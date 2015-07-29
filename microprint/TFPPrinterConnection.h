//
//  TFPPrinterConnection.h
//  microprint
//
//  Created by Tomas Franzén on Wed 2015-07-29.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

@import Foundation;

@class TFPGCode, ORSSerialPort;


typedef NS_ENUM(NSInteger, TFPPrinterMessageType) {
	TFPPrinterMessageTypeInvalid,
	TFPPrinterMessageTypeConfirmation, // value = nil or NSDictionary
	TFPPrinterMessageTypeError, // value = NSNumber for error code
	TFPPrinterMessageTypeResendRequest, // value = nil
	TFPPrinterMessageTypeTemperatureUpdate, // value = NSNumber for temperature
	TFPPrinterMessageTypeUnknown, // value = NSString with raw incoming line
};


typedef NS_ENUM(NSUInteger, TFPPrinterConnectionState) {
	TFPPrinterConnectionStateDisconnected,
	TFPPrinterConnectionStatePending,
	TFPPrinterConnectionStateConnected,
};


@interface TFPPrinterConnection : NSObject
- (instancetype)initWithSerialPort:(ORSSerialPort*)serialPort;
@property (readonly) ORSSerialPort *serialPort;

- (void)openWithCompletionHandler:(void(^)(NSError *error))completionHandler;
- (void)sendGCode:(TFPGCode*)code;

@property (copy) void(^messageHandler)(TFPPrinterMessageType type, NSInteger lineNumber, id value); // Called on private queue, remember to dispatch!

@property (readonly) TFPPrinterConnectionState state;
@end