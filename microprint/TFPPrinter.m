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
#import "TFTimer.h"

#import "MAKVONotificationCenter.h"


static const NSUInteger maxLineNumber = 100;
const NSString *TFPPrinterResponseErrorCodeKey = @"ErrorCode";

#define ZERO(x) (x < DBL_EPSILON && x > -DBL_EPSILON)


@interface TFPPrinterGCodeEntry : NSObject
@property TFPGCode *code;
@property NSInteger lineNumber;

@property dispatch_queue_t responseQueue;
@property (copy) void(^responseBlock)(BOOL success, NSDictionary *values);
@end


@implementation TFPPrinterGCodeEntry


- (instancetype)initWithCode:(TFPGCode*)code lineNumber:(NSInteger)line responseBlock:(void(^)(BOOL, NSDictionary*))block queue:(dispatch_queue_t)blockQueue {
	if(!(self = [super init])) return nil;
	
	self.code = code;
	self.lineNumber = line;
	self.responseBlock = block;
	self.responseQueue = blockQueue;
	
	return self;
}


+ (instancetype)lineNumberResetEntry {
	return [[self alloc] initWithCode:[TFPGCode codeForSettingLineNumber:0] lineNumber:0 responseBlock:nil queue:nil];
}


- (void)deliverConfirmationResponseWithValues:(NSDictionary*)values {
	if(self.responseBlock) {
		dispatch_queue_t queue = self.responseQueue ?: dispatch_get_main_queue();
		dispatch_async(queue, ^{
			self.responseBlock(YES, values);
		});
	}
}


- (void)deliverErrorResponseWithErrorCode:(NSUInteger)code {
	if(self.responseBlock) {
		dispatch_queue_t queue = self.responseQueue ?: dispatch_get_main_queue();
		dispatch_async(queue, ^{
			self.responseBlock(NO, @{TFPPrinterResponseErrorCodeKey: @(code)});
		});
	}
}


@end






@interface TFPPrinter ()
@property (readwrite) TFPPrinterConnection *connection;
@property dispatch_queue_t communicationQueue;

@property BOOL connectionFinished;
@property (readwrite) BOOL pendingConnection;
@property NSMutableArray *establishmentBlocks;

@property (readwrite) TFPPrinterColor color;
@property (readwrite, copy) NSString *serialNumber;
@property (readwrite, copy) NSString *firmwareVersion;

@property (readwrite) double feedrate;
@property (readwrite) double heaterTemperature;
@property (readwrite) BOOL hasValidZLevel;
@property (readwrite) NSComparisonResult firmwareVersionComparedToTestedRange;

@property TFPPrinterGCodeEntry *pendingCodeEntry;
@property NSMutableArray *queuedCodeEntries;

@property NSUInteger lineNumberCounter;
@property NSMutableDictionary *codeRegistry;
@end

@interface TFPPrinter (HelpersPrivate)
- (void)fetchBedOffsetsWithCompletionHandler:(void(^)(BOOL success, TFPBedLevelOffsets offsets))completionHandler;
- (void)setBedOffsets:(TFPBedLevelOffsets)offsets completionHandler:(void(^)(BOOL success))completionHandler;
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
		
	self.establishmentBlocks = [NSMutableArray new];
	self.queuedCodeEntries = [NSMutableArray new];
	self.codeRegistry = [NSMutableDictionary new];
	self.pendingConnection = YES;
	self.hasValidZLevel = YES; // Assume valid Z for now
	self.firmwareVersionComparedToTestedRange = NSOrderedSame; // Assume OK firmware for now
	
	[self.connection openWithCompletionHandler:^(NSError *error) {
		self.pendingConnection = NO;
		self.lineNumberCounter = 1;
		
		if(error) {
			for(void(^block)(NSError*) in self.establishmentBlocks) {
				block(error);
			}
			[self.establishmentBlocks removeAllObjects];
		}else{
			[self sendGCode:[TFPGCode codeForSettingLineNumber:0] responseHandler:nil];
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


+ (NSString*)minimumTestedFirmwareVersion {
	return @"2015071301";
}


+ (NSString*)maximumTestedFirmwareVersion {
	return @"2015072701";
}


- (void)refreshState {
	[self sendGCode:[TFPGCode codeWithField:'M' value:117] responseHandler:^(BOOL success, NSDictionary *value) {
		if(success && value[@"ZV"]) {
			self.hasValidZLevel = [value[@"ZV"] integerValue] > 0;
		}
	}];
	
	if ([self.firmwareVersion compare:[self.class minimumTestedFirmwareVersion]] == NSOrderedAscending) {
		self.firmwareVersionComparedToTestedRange = NSOrderedAscending;
	} else if ([self.firmwareVersion compare:[self.class maximumTestedFirmwareVersion]] == NSOrderedDescending) {
		self.firmwareVersionComparedToTestedRange = NSOrderedDescending;
	} else {
		self.firmwareVersionComparedToTestedRange = NSOrderedSame;
	}
	
	[self fetchBedOffsetsWithCompletionHandler:^(BOOL success, TFPBedLevelOffsets offsets) {
		if(success) {
			[self willChangeValueForKey:@"bedLevelOffsets"];
			_bedLevelOffsets = offsets;
			[self didChangeValueForKey:@"bedLevelOffsets"];
		}
	}];
}


- (void)setBedLevelOffsets:(TFPBedLevelOffsets)bedLevelOffsets {
	_bedLevelOffsets = bedLevelOffsets;
	[self setBedOffsets:bedLevelOffsets completionHandler:nil];
}


- (BOOL)hasAllZeroBedLevelOffsets {
	return self.connectionFinished &&
	ZERO(self.bedLevelOffsets.backLeft) &&
	ZERO(self.bedLevelOffsets.backRight) &&
	ZERO(self.bedLevelOffsets.frontLeft) &&
	ZERO(self.bedLevelOffsets.frontRight) &&
	ZERO(self.bedLevelOffsets.common);
}


+ (NSSet *)keyPathsForValuesAffectingHasAllZeroBedLevelOffsets {
	return @[@"bedLevelOffsets", @"connectionFinished"].tf_set;
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
		TFPPrinterGCodeEntry *entry = [[TFPPrinterGCodeEntry alloc] initWithCode:code lineNumber:lineNumber responseBlock:nil queue:nil];
		[self.queuedCodeEntries insertObject:entry atIndex:0];
		[self dequeueCode];
	} else {
		// Deep shit
	}
}


- (void)sendGCode:(TFPGCode*)code responseHandler:(void(^)(BOOL success, NSDictionary *value))block {
	[self sendGCode:code responseHandler:block responseQueue:dispatch_get_main_queue()];
}


- (void)processSentCode:(TFPGCode*)code {
	dispatch_async(dispatch_get_main_queue(), ^{
		NSInteger G = [code valueForField:'G' fallback:-1];
		if(G == 0 || G == 1) {
			if([code hasField:'F']) {
				self.feedrate = [code valueForField:'F'];
			}
		}
	});
}


// On communication queue here
- (void)dequeueCode {
	if(self.pendingCodeEntry) {
		return;
	}
	
	TFPPrinterGCodeEntry *entry = self.queuedCodeEntries.firstObject;
	if(entry) {
		[self processSentCode:entry.code];
		TFPGCode *code = [self adjustLine:entry.code];
		
		[self.queuedCodeEntries removeObjectAtIndex:0];
		[self.connection sendGCode:code];
		self.pendingCodeEntry = entry;
		
		if(self.outgoingCodeBlock) {
			dispatch_async(dispatch_get_main_queue(), ^{
				self.outgoingCodeBlock(entry.code.ASCIIRepresentation);
			});
		}
	}
}


- (NSUInteger)consumeLineNumber {
	if(self.lineNumberCounter > maxLineNumber) {
		// Fast-track a line number reset
		[self.queuedCodeEntries addObject:[TFPPrinterGCodeEntry lineNumberResetEntry]];
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
	if(M == 0 || M == 117 || M == 618 || M == 115) {
		return NO;
	}
	
	return YES;
}


- (void)sendGCode:(TFPGCode*)inputCode responseHandler:(void(^)(BOOL success, NSDictionary *value))block responseQueue:(dispatch_queue_t)queue {
	if([self sendReplacementsForGCodeIfNeeded:inputCode responseHandler:block responseQueue:queue]) {
		return;
	}
	
	dispatch_async(self.communicationQueue, ^{
		TFPGCode *code = inputCode;
		NSInteger lineNumber = -1;
		if([self codeNeedsLineNumber:code]) {
			lineNumber = [self consumeLineNumber];
			code = [inputCode codeBySettingLineNumber:lineNumber];
			self.codeRegistry[@(lineNumber)] = code;
		}
		
		TFPPrinterGCodeEntry *entry = [[TFPPrinterGCodeEntry alloc] initWithCode:code lineNumber:lineNumber responseBlock:block queue:queue];
		[self.queuedCodeEntries addObject:entry];
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
		case TFPPrinterMessageTypeSkipNotice: // We re-used a line number, so the printer skipped it. Pretend it's a confirmation.
			[self sendNotice:@"Got a skip notice for %d!", (int)lineNumber];
			value = @{};
			// nobreak
			
		case TFPPrinterMessageTypeConfirmation: {
			TFPPrinterGCodeEntry *entry = self.pendingCodeEntry;
			self.pendingCodeEntry = nil;
			[self dequeueCode];
			
			if(entry.lineNumber != -1 && entry.lineNumber != lineNumber) {
				[self sendNotice:@"Line number mismatch for pending code entry and response. Response was %d, expected %d (%@)", (int)lineNumber, (int)entry.lineNumber, entry.code];
			}
			
			[entry deliverConfirmationResponseWithValues:value];
			break;
		}
			
		case TFPPrinterMessageTypeResendRequest:
			[self handleResendRequest:lineNumber];
			break;
			
		case TFPPrinterMessageTypeTemperatureUpdate:
			[self processTemperatureUpdate:[value doubleValue]];
			break;
			
		case TFPPrinterMessageTypeError: {
			NSUInteger errorCode = [value unsignedIntegerValue];
			
			TFPPrinterGCodeEntry *entry = self.pendingCodeEntry;
			self.pendingCodeEntry = nil;
			[self dequeueCode];
			
			[self sendNotice:@"Got error %d in response to %@", (int)errorCode, entry.code];
			
			[entry deliverErrorResponseWithErrorCode:errorCode];
			break;
		}
			
		case TFPPrinterMessageTypeUnknown:
			TFLog(@"Unhandled input: %@", value);
			break;
			
		case TFPPrinterMessageTypeInvalid: break;
	}
}


+ (NSString*)descriptionForErrorCode:(TFPPrinterResponseErrorCode)code {
	NSArray *descriptions = @[@"M110 missing line number",
							  @"Cannot cold extrude",
							  @"Cannot calibrate in unknown state",
							  @"Unknown G code",
							  @"Unknown M code",
							  @"Unknown command",
							  @"Heater failed",
							  @"Move too large",
							  @"Heater and motors were turned off after a time of inactivity",
							  @"Target address out of range"
							  ];
	
	if(code < TFPPrinterResponseErrorCodeMin || code > TFPPrinterResponseErrorCodeMax) {
		return nil;
	} else {
		return descriptions[code-TFPPrinterResponseErrorCodeMin];
	}
}



- (double)speedMultiplier {
	return 1;
}


- (BOOL)printerShouldBeInvalidatedWithRemovedSerialPorts:(NSArray*)ports {
	NSLog(@"ports %@", ports);
	NSLog(@"my port %@", self.connection.serialPort);
	NSLog(@"my state %d", (int)self.connection.state);
	
	return self.connection.state != TFPPrinterConnectionStatePending && self.connection.serialPort && [ports containsObject:self.connection.serialPort];
}


@end