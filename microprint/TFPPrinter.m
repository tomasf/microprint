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

@property NSMutableDictionary *responseListenerBlocks;

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
	
	self.communicationQueue = dispatch_queue_create("se.tomasf.microprint.serialPortQueue", DISPATCH_QUEUE_SERIAL);
		
	self.responseListenerBlocks = [NSMutableDictionary new];
	self.establishmentBlocks = [NSMutableArray new];
	self.codeQueue = [NSMutableArray new];
	self.codeRegistry = [NSMutableDictionary new];
	self.pendingConnection = YES;
	
	[self.connection openWithCompletionHandler:^(NSError *error) {
		NSLog(@"open %@", error);
		self.pendingConnection = NO;
		
		if(error) {
			for(void(^block)(NSError*) in self.establishmentBlocks) {
				block(error);
			}
			[self.establishmentBlocks removeAllObjects];
		}else{
			[weakSelf identifyWithCompletionHandler:^(BOOL success) {
				NSLog(@"identify");
			}];
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
	}];
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
		
		if(self.verboseMode) {
			TFLog(@"< %@", code);
		}
	}
}


- (NSUInteger)consumeLineNumber {
	NSUInteger line = self.lineNumberCounter;
	
	self.lineNumberCounter++;
	if(self.lineNumberCounter > maxLineNumber) {
		self.lineNumberCounter = 0;
		[self sendGCode:[TFPGCode codeForSettingLineNumber:0] responseHandler:nil];
	}
	
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


- (void)sendGCode:(TFPGCode*)inputCode responseHandler:(void(^)(BOOL success, NSDictionary *value))block responseQueue:(dispatch_queue_t)queue {
	void(^outerBlock)(BOOL,NSDictionary*) = block ? ^(BOOL success, NSDictionary *value){
		dispatch_async(queue, ^{
			block(success, value);
		});
	} : nil;
	
	dispatch_async(self.communicationQueue, ^{
		NSUInteger lineNumber = [self consumeLineNumber];
		TFPGCode *code = [inputCode codeBySettingLineNumber:lineNumber];
		code = [self adjustLine:code];
		
		[self.codeQueue addObject:code];
		[self dequeueCode];
		
		if(outerBlock) {
			self.responseListenerBlocks[@(lineNumber)] = outerBlock;
		}else{
			[self.responseListenerBlocks removeObjectForKey:@(lineNumber)];
		}
	});
}


- (void)runGCodeProgram:(TFPGCodeProgram *)program offset:(NSUInteger)offset completionHandler:(void (^)(BOOL))completionHandler responseQueue:(dispatch_queue_t)queue {
	if(offset < program.lines.count) {
		TFPGCode *code = program.lines[offset];
		[self sendGCode:code responseHandler:^(BOOL success, NSDictionary *value) {
			if(success) {
				[self runGCodeProgram:program offset:offset+1 completionHandler:completionHandler responseQueue:queue];
			}else{
				dispatch_async(queue, ^{
					completionHandler(NO);
				});
			}
		} responseQueue:queue];
	}else{
		dispatch_async(queue, ^{
			completionHandler(YES);
		});
	}
}


- (void)runGCodeProgram:(TFPGCodeProgram*)program completionHandler:(void(^)(BOOL success))completionHandler responseQueue:(dispatch_queue_t)queue {
	[self runGCodeProgram:program offset:0 completionHandler:completionHandler responseQueue:queue];
}


- (void)runGCodeProgram:(TFPGCodeProgram*)program completionHandler:(void(^)(BOOL success))completionHandler {
	[self runGCodeProgram:program completionHandler:completionHandler responseQueue:dispatch_get_main_queue()];
}


- (void)sendGCodeString:(NSString*)GCode responseHandler:(void(^)(BOOL success, NSDictionary *value))block {
	[self sendGCode:[TFPGCode codeWithString:GCode] responseHandler:block];
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
			
			if(self.verboseMode) {
				TFLog(@"> OK %@", value);
			}
			
			if(lineNumber < 0) {
				TFLog(@"This should never happen! Achtung!");
				return;
			}
			
			void(^block)(BOOL, NSDictionary*) = self.responseListenerBlocks[@(lineNumber)];
			if(block) {
				[self.responseListenerBlocks removeObjectForKey:@(lineNumber)];
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
			if(self.verboseMode) {
				TFLog(@"Unhandled input: %@", value);
			}
			break;
			
		case TFPPrinterMessageTypeInvalid: break;
	}
}


- (void)fetchBedOffsetsWithCompletionHandler:(void(^)(BOOL success, TFPBedLevelOffsets offsets))completionHandler {
	NSArray *indexes = @[@(VirtualEEPROMIndexBedOffsetBackLeft),
						 @(VirtualEEPROMIndexBedOffsetBackRight),
						 @(VirtualEEPROMIndexBedOffsetFrontRight),
						 @(VirtualEEPROMIndexBedOffsetFrontLeft),
						 @(VirtualEEPROMIndexBedOffsetCommon)];
	
	[self readVirtualEEPROMFloatValuesAtIndexes:indexes completionHandler:^(BOOL success, NSArray *values) {
		TFPBedLevelOffsets offsets;
		
		if(!success) {
			completionHandler(NO, offsets);
		}
		
		offsets.backLeft = [values[0] floatValue];
		offsets.backRight = [values[1] floatValue];
		offsets.frontRight = [values[2] floatValue];
		offsets.frontLeft = [values[3] floatValue];
		offsets.common = [values[4] floatValue];
		
		completionHandler(YES, offsets);
	}];
}


- (void)setBedOffsets:(TFPBedLevelOffsets)offsets completionHandler:(void(^)(BOOL success))completionHandler {
	NSDictionary *EEPROMValues = @{
								   @(VirtualEEPROMIndexBedOffsetBackLeft): @(offsets.backLeft),
								   @(VirtualEEPROMIndexBedOffsetBackRight): @(offsets.backRight),
								   @(VirtualEEPROMIndexBedOffsetFrontRight): @(offsets.frontRight),
								   @(VirtualEEPROMIndexBedOffsetFrontLeft): @(offsets.frontLeft),
								   @(VirtualEEPROMIndexBedOffsetCommon): @(offsets.common),
								   };
	
	
	[self writeVirtualEEPROMFloatValues:EEPROMValues completionHandler:^(BOOL success) {
		if(completionHandler) {
			completionHandler(success);
		}
	}];
}


- (void)fetchBacklashValuesWithCompletionHandler:(void(^)(BOOL success, TFPBacklashValues values))completionHandler {
	NSArray *indexes = @[@(VirtualEEPROMIndexBacklashCompensationX),
						 @(VirtualEEPROMIndexBacklashCompensationY),
						 @(VirtualEEPROMIndexBacklashCompensationSpeed)
						 ];
	
	[self readVirtualEEPROMFloatValuesAtIndexes:indexes completionHandler:^(BOOL success, NSArray *values) {
		TFPBacklashValues backlash;
		if(success) {
			backlash.x = [values[0] floatValue];
			backlash.y = [values[1] floatValue];
			backlash.speed = [values[2] floatValue];
			
			completionHandler(YES, backlash);
		}else{
			completionHandler(NO, backlash);
		}
	}];
}


- (void)setBacklashValues:(TFPBacklashValues)values completionHandler:(void(^)(BOOL success))completionHandler {
	NSDictionary *EEPROMValues = @{
								   @(VirtualEEPROMIndexBacklashCompensationX): @(values.x),
								   @(VirtualEEPROMIndexBacklashCompensationY): @(values.y),
								   @(VirtualEEPROMIndexBacklashCompensationSpeed): @(values.speed),
								   };
	
	[self writeVirtualEEPROMFloatValues:EEPROMValues completionHandler:^(BOOL success) {
		if(completionHandler) {
			completionHandler(success);
		}
	}];
}



- (void)fetchPositionWithCompletionHandler:(void(^)(BOOL success, TFP3DVector *position, NSNumber *E))completionHandler {
	[self sendGCodeString:@"M114" responseHandler:^(BOOL success, NSDictionary *params) {
		if(success) {
			NSNumber *x = params[@"X"] ? @([params[@"X"] doubleValue]) : nil;
			NSNumber *y = params[@"Y"] ? @([params[@"Y"] doubleValue]) : nil;
			NSNumber *z = params[@"Z"] ? @([params[@"Z"] doubleValue]) : nil;
			NSNumber *e = params[@"E"] ? @([params[@"E"] doubleValue]) : nil;
			
			TFP3DVector *position = [TFP3DVector vectorWithX:x Y:y Z:z];
			completionHandler(YES, position, e);
			
		}else{
			completionHandler(NO, nil, 0);
		}
	}];
}


- (void)fillInOffsetAndBacklashValuesInPrintParameters:(TFPPrintParameters*)params completionHandler:(void(^)(BOOL success))completionHandler {
	[self fetchBedOffsetsWithCompletionHandler:^(BOOL success, TFPBedLevelOffsets offsets) {
		if(!success) {
			completionHandler(NO);
			return;
		}
		
		params.bedLevelOffsets = offsets;
		[self fetchBacklashValuesWithCompletionHandler:^(BOOL success, TFPBacklashValues values) {
			if(!success) {
				completionHandler(NO);
				return;
			}
			params.backlashValues = values;
			completionHandler(YES);
		}];
	}];
}


- (void)setRelativeMode:(BOOL)relative completionHandler:(void(^)(BOOL success))completionHandler {
	[self sendGCodeString:(relative ? @"G91" : @"G90") responseHandler:^(BOOL success, NSDictionary *value) {
		completionHandler(success);
	}];
}


- (void)moveToPosition:(TFP3DVector*)position usingFeedRate:(double)F completionHandler:(void(^)(BOOL success))completionHandler {
	TFPGCode *code = [TFPGCode codeWithString:@"G0"];
	if(position.x) {
		code = [code codeBySettingField:'X' toValue:position.x.doubleValue];
	}
	if(position.y) {
		code = [code codeBySettingField:'Y' toValue:position.y.doubleValue];
	}
	if(position.z) {
		code = [code codeBySettingField:'Z' toValue:position.z.doubleValue];
	}
	if(F >= 0) {
		code = [code codeBySettingField:'F' toValue:F];
	}

	[self sendGCode:code responseHandler:^(BOOL success, NSDictionary *value) {
		if(completionHandler) {
			completionHandler(success);
		}
	}];
}


- (double)speedMultiplier {
	return 1;
}


- (BOOL)printerShouldBeInvalidatedWithRemovedSerialPorts:(NSArray*)ports {
	return self.connection.state != TFPPrinterConnectionStatePending && self.connection.serialPort && [ports containsObject:self.connection.serialPort];
}


@end