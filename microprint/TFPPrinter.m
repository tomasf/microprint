//
//  TFPPrinter.m
//  MicroPrint
//
//  Created by Tomas Franzén on Tue 2015-06-23.
//

#import "TFPPrinter.h"
#import "TFPExtras.h"
#import "TFPGCode.h"
#import "TFPPrintParameters.h"
#import "TFStringScanner.h"
#import "TFP3DVector.h"
#import "TFPGCodeProgram.h"
#import "TFPGCodeHelpers.h"
#import "TFPPrinter+VirtualEEPROM.h"
#import "TFPPrinterConnection.h"

#import "MAKVONotificationCenter.h"


static const NSUInteger maxLineNumber = 100;


@interface TFPPrinter ()
@property TFPPrinterConnection *connection;
@property dispatch_queue_t communicationQueue;

@property BOOL connectionFinished;
@property (readwrite) BOOL pendingConnection;
@property NSMutableArray *establishmentBlocks;

@property (readwrite) TFPPrinterColor color;
@property (readwrite, copy) NSString *serialNumber;
@property (readwrite, copy) NSString *firmwareVersion;

@property (readwrite) double heaterTemperature;
@property (readwrite) BOOL hasValidZLevel;

@property NSMutableDictionary *responseListenerBlocks;
@property NSMutableArray *unnumberedResponseBlocks;

@property NSMutableArray *codeQueue;
@property BOOL waitingForResponse;

@property NSUInteger lineNumberCounter;
@property NSMutableDictionary *codeRegistry;
@end



@implementation TFPPrinter


- (instancetype)initWithConnection:(TFPPrinterConnection*)connection {
	if(!(self = [super init])) return nil;
	__weak __typeof__(self) weakSelf = self;
	
	self.connection = connection;
	self.connection.messageHandler = ^(TFPPrinterMessageType type, NSInteger lineNumber, id value){
		dispatch_async(weakSelf.communicationQueue, ^{
			[weakSelf handleMessage:type lineNumber:lineNumber value:value];
		});
	};
	
	self.connection.rawLineHandler = ^(NSString *string) {
		if(weakSelf.incomingCodeBlock) {
			dispatch_async(dispatch_get_main_queue(), ^{
				if(![string isEqual:@"wait"]) {
					weakSelf.incomingCodeBlock(string);
				}
			});
		}
	};
	
	self.communicationQueue = dispatch_queue_create("se.tomasf.microprint.serialPortQueue", DISPATCH_QUEUE_SERIAL);
		
	self.responseListenerBlocks = [NSMutableDictionary new];
	self.establishmentBlocks = [NSMutableArray new];
	self.codeQueue = [NSMutableArray new];
	self.codeRegistry = [NSMutableDictionary new];
	self.unnumberedResponseBlocks = [NSMutableArray new];
	self.pendingConnection = YES;
	self.hasValidZLevel = YES; // Assume valid Z for now
	
	[self.connection openWithCompletionHandler:^(NSError *error) {
		self.pendingConnection = NO;
		self.lineNumberCounter = 1;
		
		if(error) {
			for(void(^block)(NSError*) in self.establishmentBlocks) {
				block(error);
			}
			[self.establishmentBlocks removeAllObjects];
		}else{
			[weakSelf identifyWithCompletionHandler:^(BOOL success) {
			}];
		}
	}];
	
	[self addObserver:self keyPath:@"currentOperation" options:0 block:^(MAKVONotification *notification) {
		if(weakSelf.connectionFinished && !weakSelf.currentOperation) {
			[weakSelf refreshState];
		}
	}];
	
	return self;
}


- (void)establishConnectionWithCompletionHandler:(void(^)(NSError *error))completionHandler {
	if(self.connectionFinished) {
		completionHandler(nil);
		return;
	}
	[self.establishmentBlocks addObject:completionHandler];
}


- (void)identifyWithCompletionHandler:(void(^)(BOOL success))completionHandler {
	if(self.serialNumber) {
		return; // Identification not needed
	}
	
	TFPGCode *getCapabilities = [TFPGCode codeWithString:@"M115"];
	[self sendGCode:getCapabilities responseHandler:^(BOOL success, NSDictionary *value) {
		if(success) {
			[self processCapabilities:value];
			completionHandler(YES);
		}else{
			completionHandler(NO);
		}
		
		for(void(^block)(NSError*) in self.establishmentBlocks) {
			block(nil);
		}
		[self.establishmentBlocks removeAllObjects];
		self.connectionFinished = YES;
		[self refreshState];
	}];
}


- (void)refreshState {
	[self sendGCode:[TFPGCode codeWithField:'M' value:117] responseHandler:^(BOOL success, NSDictionary *value) {
		if(success && value[@"ZV"]) {
			self.hasValidZLevel = [value[@"ZV"] integerValue] > 0;
		}
	}];
}


- (void)sendNotice:(NSString*)noticeFormat, ... {
	va_list list;
	va_start(list, noticeFormat);
	NSString *string = [[NSString alloc] initWithFormat:noticeFormat arguments:list];
	va_end(list);
	TFMainThread(^{
		if(self.noticeBlock) {
			self.noticeBlock(string);
		}
	});
}


// On communication queue here
- (void)handleResendRequest:(NSUInteger)lineNumber {
	TFPGCode *code = self.codeRegistry[@(lineNumber)];
	TFLog(@"Got resend request for line %@", code);
	
	if(code) {
		[self.codeQueue insertObject:code atIndex:0];
		[self dequeueCode];
	} else {
		// Deep shit
	}
}


- (void)sendGCode:(TFPGCode*)code responseHandler:(void(^)(BOOL success, NSDictionary *value))block {
	[self sendGCode:code responseHandler:block responseQueue:dispatch_get_main_queue()];
}


// On communication queue here
- (void)dequeueCode {
	if(self.waitingForResponse) {
		return;
	}
	
	TFPGCode *code = self.codeQueue.firstObject;
	if(code) {
		[self.codeQueue removeObjectAtIndex:0];
		[self.connection sendGCode:code];

		self.waitingForResponse = YES;
		
		if(self.outgoingCodeBlock) {
			dispatch_async(dispatch_get_main_queue(), ^{
				self.outgoingCodeBlock(code.ASCIIRepresentation);
			});
		}
	}
}


- (NSUInteger)consumeLineNumber {
	if(self.lineNumberCounter > maxLineNumber) {
		// Fast-track a line number reset
		[self.responseListenerBlocks removeObjectForKey:@0];
		[self.codeQueue addObject:[TFPGCode codeForSettingLineNumber:0]];
		[self dequeueCode];
		self.lineNumberCounter = 1;
	}

	NSUInteger line = self.lineNumberCounter;
	self.lineNumberCounter++;
	return line;
}


- (double)convertToM3DSpecificFeedRate:(double)feedRate {
	double factor = MIN(feedRate / 3600.06, 1.0);
	return 30 + (1 - factor) * 800;
}


- (TFPGCode*)adjustLine:(TFPGCode*)code {
	if([code hasField:'G'] && [code hasField:'F']) {
		double feedRate = code.feedRate;
		feedRate = [self convertToM3DSpecificFeedRate:feedRate];
		code = [code codeBySettingField:'F' toValue:feedRate];
	}
	
	return code;
}


- (BOOL)sendReplacementsForGCodeIfNeeded:(TFPGCode*)code responseHandler:(void(^)(BOOL success, NSDictionary *value))block responseQueue:(dispatch_queue_t)queue {
	NSInteger M = [code valueForField:'M' fallback:-1];
	
	if(M == 0) {
		// The Micro's firmware goes mad if you send M0 with a line number and keeps requesting a re-send over and over.
		// So let's replace it with M18 + M104 S0, which is equivalent and works properly. Sigh.

		[self sendNotice:@"Issuing replacement for M0."];
		
		[self sendGCode:[TFPGCode turnOffMotorsCode] responseHandler:nil responseQueue:nil];
		[self sendGCode:[TFPGCode codeForTurningOffHeater] responseHandler:block responseQueue:queue];
		return YES;
	}else{
		return NO;
	}
}


// This is so bad. Firmware is a huge piece of crap.

- (BOOL)codeNeedsLineNumber:(TFPGCode*)code {
	NSUInteger M = [code valueForField:'M' fallback:-1];
	if(M == 117 || M == 618 || M == 115) {
		return NO;
	}
	
	return YES;
}


- (void)sendGCode:(TFPGCode*)inputCode responseHandler:(void(^)(BOOL success, NSDictionary *value))block responseQueue:(dispatch_queue_t)queue {
	void(^outerBlock)(BOOL,NSDictionary*) = block ? ^(BOOL success, NSDictionary *value){
		dispatch_async(queue, ^{
			block(success, value);
		});
	} : ^(BOOL success, NSDictionary *value){};
	
	if([self sendReplacementsForGCodeIfNeeded:inputCode responseHandler:block responseQueue:queue]) {
		return;
	}
	
	dispatch_async(self.communicationQueue, ^{
		TFPGCode *code = inputCode;
		NSInteger lineNumber = -1;
		if([self codeNeedsLineNumber:code]) {
			lineNumber = [self consumeLineNumber];
			code = [inputCode codeBySettingLineNumber:lineNumber];
		}
		code = [self adjustLine:code];
		
		if(lineNumber < 0) {
			[self.unnumberedResponseBlocks addObject:outerBlock];
		}else{
			self.responseListenerBlocks[@(lineNumber)] = outerBlock;
		}
		
		[self.codeQueue addObject:code];
		[self dequeueCode];
	});
}


- (void)runGCodeProgram:(TFPGCodeProgram *)program previousValues:(NSArray*)previousValues completionHandler:(void (^)(BOOL success, NSArray *valueDictionaries))completionHandler responseQueue:(dispatch_queue_t)queue {
	if(previousValues.count < program.lines.count) {
		TFPGCode *code = program.lines[previousValues.count];
		[self sendGCode:code responseHandler:^(BOOL success, NSDictionary *value) {
			if(success) {
				NSMutableArray *newValues = [previousValues mutableCopy];
				[newValues addObject:value];
				[self runGCodeProgram:program previousValues:newValues completionHandler:completionHandler responseQueue:queue];
			}else{
				dispatch_async(queue, ^{
					completionHandler(NO, previousValues);
				});
			}
		} responseQueue:queue];
	}else{
		dispatch_async(queue, ^{
			completionHandler(YES, previousValues);
		});
	}
}


- (void)runGCodeProgram:(TFPGCodeProgram*)program completionHandler:(void(^)(BOOL success, NSArray *valueDictionaries))completionHandler responseQueue:(dispatch_queue_t)queue {
	[self runGCodeProgram:program previousValues:@[] completionHandler:completionHandler responseQueue:queue];
}


- (void)runGCodeProgram:(TFPGCodeProgram*)program completionHandler:(void(^)(BOOL success, NSArray *valueDictionaries))completionHandler {
	[self runGCodeProgram:program completionHandler:completionHandler responseQueue:dispatch_get_main_queue()];
}


+ (NSString*)nameForPrinterColor:(TFPPrinterColor)color {
	return @{
			 @(TFPPrinterColorGrape): @"Grape",
			 @(TFPPrinterColorGreen): @"Green",
			 @(TFPPrinterColorLightBlue): @"Light blue",
			 @(TFPPrinterColorBlack): @"Black",
			 @(TFPPrinterColorSilver): @"Silver",
			 @(TFPPrinterColorOrange): @"Orange",
			 @(TFPPrinterColorWhite): @"White",
			 @(TFPPrinterColorOther): @"Other",
			 }[@(color)];
}


- (TFPPrinterColor)colorFromSerialNumber:(NSString*)serialNumber {
	NSDictionary *prefixToColorMap = @{
									   @"PL": @(TFPPrinterColorGrape),
									   @"GR": @(TFPPrinterColorGreen),
									   @"BL": @(TFPPrinterColorLightBlue),
									   @"BK": @(TFPPrinterColorBlack),
									   @"SL": @(TFPPrinterColorSilver),
									   @"OR": @(TFPPrinterColorOrange),
									   @"WH": @(TFPPrinterColorWhite),
									   };
	NSNumber *colorNumber = prefixToColorMap[[serialNumber substringToIndex:2]];
	return colorNumber ? colorNumber.unsignedIntegerValue : TFPPrinterColorOther;
}


- (NSString*)formatSerialNumber:(NSString*)serial {
	if(serial.length < 16) {
		return serial;
	}
	
	NSString *part1 = [serial substringWithRange:NSMakeRange(0, 2)];
	NSString *part2 = [serial substringWithRange:NSMakeRange(2, 2)];
	NSString *part3 = [serial substringWithRange:NSMakeRange(4, 2)];
	NSString *part4 = [serial substringWithRange:NSMakeRange(6, 2)];
	NSString *part5 = [serial substringWithRange:NSMakeRange(8, 2)];
	NSString *part6 = [serial substringWithRange:NSMakeRange(10, 3)];
	NSString *part7 = [serial substringWithRange:NSMakeRange(13, 3)];

	return [@[part1, part2, part3, part4, part5, part6, part7] componentsJoinedByString:@"-"];
}


- (void)processCapability:(NSString*)key value:(NSString*)value {
	if([key isEqual:@"FIRMWARE_VERSION"]) {
		self.firmwareVersion = value;
	}else if([key isEqual:@"X-SERIAL_NUMBER"]) {
		self.serialNumber = [self formatSerialNumber:value];
		self.color = [self colorFromSerialNumber:value];
	}
}


- (void)processCapabilities:(NSDictionary*)dictionary {
	for(NSString *key in dictionary) {
		[self processCapability:key value:dictionary[key]];
	}
}



- (void)processTemperatureUpdate:(double)temperature {
	// On communication queue here
	dispatch_async(dispatch_get_main_queue(), ^{
		if(temperature != self.heaterTemperature) {
			self.heaterTemperature = temperature;
		}
	});
}


- (void)handleMessage:(TFPPrinterMessageType)type lineNumber:(NSInteger)lineNumber value:(id)value {
	// On communication queue here
	
	switch(type) {
		case TFPPrinterMessageTypeConfirmation: {
			self.waitingForResponse = NO;
			[self dequeueCode];
			
			void(^block)(BOOL, NSDictionary*);
			
			if(lineNumber < 0) {
				if(self.unnumberedResponseBlocks.count < 1) {
					[self sendNotice:@"Missing unnumbered response block!"];
				} else {
					block = self.unnumberedResponseBlocks.firstObject;
					[self.unnumberedResponseBlocks removeObjectAtIndex:0];
				}
			}else{
				block = self.responseListenerBlocks[@(lineNumber)];
				[self.responseListenerBlocks removeObjectForKey:@(lineNumber)];
			}
			
			if(block) {
				block(YES, value);
			}
			break;
		}
		case TFPPrinterMessageTypeResendRequest:
			[self handleResendRequest:lineNumber];
			break;
			
		case TFPPrinterMessageTypeTemperatureUpdate:
			[self processTemperatureUpdate:[value doubleValue]];
			break;
			
		case TFPPrinterMessageTypeError:
			break;
			
		case TFPPrinterMessageTypeUnknown:
			TFLog(@"Unhandled input: %@", value);
			break;
			
		case TFPPrinterMessageTypeInvalid: break;
	}
}


- (double)speedMultiplier {
	return 1;
}


- (BOOL)printerShouldBeInvalidatedWithRemovedSerialPorts:(NSArray*)ports {
	return self.connection.state != TFPPrinterConnectionStatePending && self.connection.serialPort && [ports containsObject:self.connection.serialPort];
}


@end