//
//  TFPPrinterConnection.m
//  microprint
//
//  Created by Tomas Franzén on Wed 2015-07-29.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrinterConnection.h"
#import "TFPGCode.h"
#import "TFPExtras.h"
#import "TFPGCodeHelpers.h"
#import "TFStringScanner.h"
#import "ORSSerialPort.h"


static const NSTimeInterval firmwareReconnectionDelay = 4;



@interface TFPPrinterConnection () <ORSSerialPortDelegate>
@property (readwrite) ORSSerialPort *serialPort;
@property dispatch_queue_t serialPortQueue;

@property NSMutableData *incomingData;

@property (readwrite) TFPPrinterConnectionState state;
@property BOOL pendingConnection;
@property BOOL connectionFinished;
@property BOOL removed;

@property (copy) void(^connectionCompletionHandler)(NSError *error);
@end



@implementation TFPPrinterConnection


- (instancetype)initWithSerialPort:(ORSSerialPort*)serialPort {
	if(!(self = [super init])) return nil;
	
	self.serialPort = serialPort;
	self.serialPortQueue = dispatch_queue_create("se.tomasf.microprint.printerSerialQueue", DISPATCH_QUEUE_SERIAL);
	
	self.serialPort.delegate = self;
	self.serialPort.delegateQueue = self.serialPortQueue;
	
	self.incomingData = [NSMutableData data];
	
	return self;
}


- (void)openWithCompletionHandler:(void(^)(NSError *error))completionHandler {
	if(self.connectionFinished) {
		completionHandler(nil);
	}else{
		self.pendingConnection = YES;
		self.connectionCompletionHandler = completionHandler;
		self.state = TFPPrinterConnectionStatePending;
		
		[self.serialPort open];
	}
}


- (void)sendGCode:(TFPGCode*)code {
	NSData *data = code.repetierV2Representation;
	dispatch_async(self.serialPortQueue, ^{
		[self.serialPort sendData:data];
	});
}


+ (NSDictionary*)dictionaryFromResponseValueString:(NSString*)string {
	NSMutableDictionary *dictionary = [NSMutableDictionary new];
	NSArray *parts = [string componentsSeparatedByString:@" "];
	
	for(NSString *part in parts) {
		NSUInteger colonIndex = [part rangeOfString:@":"].location;
		if(colonIndex != NSNotFound) {
			NSString *key = [part substringToIndex:colonIndex];
			NSString *value = [part substringFromIndex:colonIndex+1];
			dictionary[key] = value;
		}
	}
	return dictionary;
}


- (void)processIncomingString:(NSString*)incomingLine {
	// On serial port queue here
	
	if(self.rawLineHandler) {
		self.rawLineHandler(incomingLine);
	}
	
	TFStringScanner *scanner = [TFStringScanner scannerWithString:incomingLine];
	TFPPrinterMessageType type = TFPPrinterMessageTypeInvalid;
	NSInteger lineNumber = -1;
	id value = nil;
	
	if([scanner scanString:@"wait"]) {
		
	}else if([scanner scanString:@"ok"]){
		NSUInteger startPosition = scanner.location;
		NSString *token = [scanner scanToken];
		if(token && scanner.lastTokenType == TFTokenTypeNumeric) {
			lineNumber = [token integerValue];
		}else{
			scanner.location = startPosition;
		}
		[scanner scanWhitespace];
		
		NSString *valueString = [scanner scanToString:@"\n"]; // Scans to end
		value = [self.class dictionaryFromResponseValueString:valueString];
		type = TFPPrinterMessageTypeConfirmation;
		
	}else if([scanner scanString:@"T:"]) {
		double temperature = [[scanner scanToString:@"\n"] doubleValue];
		type = TFPPrinterMessageTypeTemperatureUpdate;
		value = @(temperature);
		
	}else if([scanner scanString:@"Resend:"]) {
		lineNumber = [[scanner scanToString:@"\n"] integerValue];
		type = TFPPrinterMessageTypeTemperatureUpdate;
		
	}else if([scanner scanString:@"skip"]) {
		[scanner scanWhitespace];
		lineNumber = [[scanner scanToString:@"\n"] integerValue];
		type = TFPPrinterMessageTypeSkipNotice;
		
	}else if([scanner scanString:@"Error:"]) {
		NSInteger errorCode = [[scanner scanToString:@" "] integerValue];
		type = TFPPrinterMessageTypeError;
		value = @(errorCode);
		
	}else{
		type = TFPPrinterMessageTypeUnknown;
		value = incomingLine;
	}
	
	if(type != TFPPrinterMessageTypeInvalid) {
		self.messageHandler(type, lineNumber, value);
	}
}


- (void)finishEstablishment {
	self.pendingConnection = NO;
	self.connectionFinished = YES;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		self.state = TFPPrinterConnectionStateConnected;
		self.connectionCompletionHandler(nil);
	});
}


- (void)processIncomingData {
	// On serial port thread here
	
	if(self.pendingConnection && [self.incomingData isEqual:[NSData tf_singleByte:'?']]) {
		TFLog(@"Switching from bootloader to firmware mode...");
		
		[self.incomingData setLength:0];
		[self.serialPort sendData:[NSData tf_singleByte:'Q']];
		return;
	}
	
	NSData *linefeed = [NSData tf_singleByte:'\n'];
	NSUInteger linefeedIndex;
 
	while((linefeedIndex = [self.incomingData tf_offsetOfData:linefeed]) != NSNotFound) {
		NSData *line = [self.incomingData subdataWithRange:NSMakeRange(0, linefeedIndex)];
		[self.incomingData replaceBytesInRange:NSMakeRange(0, linefeedIndex+1) withBytes:NULL length:0];
		
		NSString *string = [[NSString alloc] initWithData:line encoding:NSUTF8StringEncoding];
		
		if(self.pendingConnection && [string hasPrefix:@"ok"]) {
			[self finishEstablishment];
		}else{
			[self processIncomingString:string];
		}
	}
}




#pragma mark - Serial Port Delegate


- (void)serialPortWasOpened:(ORSSerialPort * __nonnull)serialPort {
	self.removed = NO;
	[self sendGCode:[TFPGCode codeWithString:@"M115"]];
}


- (void)serialPortWasClosed:(ORSSerialPort * __nonnull)serialPort {
	
	if(self.pendingConnection) {
		dispatch_after(dispatch_time(0, firmwareReconnectionDelay * NSEC_PER_SEC), self.serialPortQueue, ^{
			[self.serialPort open];
		});
	}else{
		TFMainThread(^{
			self.state = TFPPrinterConnectionStateDisconnected;
		});
	}
}


- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error {
	if(self.pendingConnection) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self.connectionCompletionHandler(error);
		});
	}
}


- (void)serialPort:(ORSSerialPort * __nonnull)serialPort didReceiveData:(NSData * __nonnull)data {
	[self.incomingData appendData:data];
	[self processIncomingData];
}


- (void)serialPortWasRemovedFromSystem:(ORSSerialPort * __nonnull)serialPort {
	self.removed = YES;
}


@end