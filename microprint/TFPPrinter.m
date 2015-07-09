//
//  TFPPrinter.m
//  MicroPrint
//
//  Created by Tomas Franzén on Tue 2015-06-23.
//

#import "TFPPrinter.h"
#import "Extras.h"
#import "TFPGCode.h"
#import "TFPPrintParameters.h"
#import "TFStringScanner.h"
#import "TFP3DVector.h"


@interface TFPPrinter () <ORSSerialPortDelegate>
@property ORSSerialPort *serialPort;
@property (readwrite, copy) NSString *identifier;

@property BOOL connectionFinished;
@property BOOL pendingConnection;

@property (readwrite) TFPPrinterColor color;
@property (readwrite, copy) NSString *serialNumber;
@property (readwrite, copy) NSString *firmwareVersion;

@property (readwrite) double heaterTemperature;

@property NSMutableArray *establishBlocks;
@property NSMutableData *incomingData;

@property NSMutableArray *unnumberedResponseListenerBlocks;
@property NSMutableDictionary *numberedResponseListenerBlocks;
@end





@implementation TFPPrinter


- (instancetype)initWithSerialPort:(ORSSerialPort*)serialPort {
	if(!(self = [super init])) return nil;
	
	self.serialPort = serialPort;
	self.serialPort.delegate = self;
	
	self.identifier = self.serialPort.path;
	
	self.establishBlocks = [NSMutableArray new];
	self.incomingData = [NSMutableData new];
	self.unnumberedResponseListenerBlocks = [NSMutableArray new];
	self.numberedResponseListenerBlocks = [NSMutableDictionary new];
	
	return self;
}


- (void)establishConnectionWithCompletionHandler:(void(^)(NSError *error))completionHandler {
	if(self.connectionFinished) {
		completionHandler(nil);
	} else {		
		[self.establishBlocks addObject:[completionHandler copy]];

		if(!self.pendingConnection) {
			self.pendingConnection = YES;
			[self.serialPort open];
		}
	}
}



- (void)identifyWithCompletionHandler:(void(^)(BOOL success))completionHandler {
	if(self.serialNumber) {
		return; // Identification not needed
	}
	
	TFPGCode *getCapabilities = [TFPGCode codeWithString:@"M115"];
	[self sendGCode:getCapabilities responseHandler:^(BOOL success, NSString *value) {
		if(success) {
			[self processCapabilities:value];
			completionHandler(YES);
		}else{
			completionHandler(NO);
		}
	}];
}


- (void)serialPortWasRemovedFromSystem:(ORSSerialPort * __nonnull)serialPort {
}


- (void)callEstablishBlocksWithError:(NSError*)error {
	self.pendingConnection = NO;
	
	NSArray *blocks = [self.establishBlocks copy];
	[self.establishBlocks removeAllObjects];
	
	for(void(^block)(NSError *error) in blocks) {
		block(error);
	}
}


- (void)serialPortWasOpened:(ORSSerialPort * __nonnull)serialPort {
	[self identifyWithCompletionHandler:^(BOOL success) {
		if(success) {
			self.connectionFinished = YES;
			[self callEstablishBlocksWithError:nil];
		}else{
			// Hmm
		}
	}];
}


- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error {
	if(self.pendingConnection) {
		[self callEstablishBlocksWithError:error];
	}
}



- (void)sendGCode:(TFPGCode*)GCode responseHandler:(void(^)(BOOL success, NSString *value))block {
	[self.serialPort sendData:GCode.repetierV2Representation];
	
	if([GCode hasField:'N']) {
		self.numberedResponseListenerBlocks[@((NSUInteger)[GCode valueForField:'N'])] = [block copy];
	}else{
		[self.unnumberedResponseListenerBlocks addObject:[block copy]];
	}
}


- (void)sendGCodes:(NSArray*)codes completionHandler:(void(^)(BOOL success))completionHandler {
	TFPGCode *code = codes.firstObject;
	if(code) {
		[self sendGCode:code responseHandler:^(BOOL success, NSString *value) {
			if(success) {
				[self sendGCodes:[codes subarrayWithRange:NSMakeRange(1, codes.count-1)] completionHandler:completionHandler];
			}else{
				completionHandler(NO);
			}
		}];
	}else{
		completionHandler(YES);
	}
}


- (void)sendGCodeString:(NSString*)GCode responseHandler:(void(^)(BOOL success, NSString *value))block {
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


- (NSDictionary*)dictionaryFromResponseValueString:(NSString*)string {
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


- (void)processCapabilities:(NSString*)string {
	NSDictionary *dictionary = [self dictionaryFromResponseValueString:string];
	
	for(NSString *key in dictionary) {
		[self processCapability:key value:dictionary[key]];
	}
}



- (void)processTemperatureUpdate:(double)temperature {
	if(temperature != self.heaterTemperature) {
		self.heaterTemperature = temperature;
	}
}


- (void)handleResendRequest:(NSUInteger)lineNumber {
	if(self.resendHandler) {
		self.resendHandler(lineNumber);
	}else{
		TFLog(@"Unhandled resend request for line %d", (int)lineNumber);
	}
}


- (void)processIncomingString:(NSString*)incomingLine {
	TFStringScanner *scanner = [TFStringScanner scannerWithString:incomingLine];
	if(self.verboseMode) {
		TFLog(@"* %@", incomingLine);
	}
	
	if([scanner scanString:@"wait"]) {
		// Do nothing
		
	}else if([scanner scanString:@"ok"]){
		NSInteger lineNumber = -1;
		
		NSUInteger pos = scanner.location;
		NSString *token = [scanner scanToken];
		if(token && scanner.lastTokenType == TFTokenTypeNumeric) {
			lineNumber = [token integerValue];
		}else{
			scanner.location = pos;
		}
		
		[scanner scanWhitespace];
		NSString *value = [scanner scanToString:@"\n"]; // Scans to end
		
		if(lineNumber > -1) {
			void(^block)(BOOL, NSString*) = self.numberedResponseListenerBlocks[@(lineNumber)];
			if(block) {
				[self.numberedResponseListenerBlocks removeObjectForKey:@(lineNumber)];
				block(YES, value);
			}else{
				TFLog(@"Unhandled OK response for N%d", (int)lineNumber);
			}
		}else{
			if(self.unnumberedResponseListenerBlocks.count) {
				void(^block)(BOOL, NSString*) = self.unnumberedResponseListenerBlocks.firstObject;
				[self.unnumberedResponseListenerBlocks removeObjectAtIndex:0];
				block(YES, value);
			}
		}
		
	}else if([scanner scanString:@"T:"]) {
		double temperature = [[scanner scanToString:@"\n"] doubleValue];
		[self processTemperatureUpdate:temperature];
		
	}else if([scanner scanString:@"Resend:"]) {
		NSInteger lineNumber = [[scanner scanToString:@"\n"] integerValue];
		[self handleResendRequest:lineNumber];
	
	}else if([scanner scanString:@"Error:"]) {
		NSString *errorText = [scanner scanToEnd];
		
		if(self.unnumberedResponseListenerBlocks.count) {
			void(^block)(BOOL, NSString*) = self.unnumberedResponseListenerBlocks.firstObject;
			[self.unnumberedResponseListenerBlocks removeObjectAtIndex:0];
			block(NO, errorText);
		}
		
	}else{
		if(self.verboseMode) {
			TFLog(@"Unhandled input: %@", incomingLine);
		}
	}
}


- (void)processIncomingData {
	NSData *linefeed = [NSData dataWithBytes:"\n" length:1];
	NSUInteger linefeedIndex;
 
	while((linefeedIndex = [self.incomingData tf_indexOfData:linefeed]) != NSNotFound) {
		NSData *line = [self.incomingData subdataWithRange:NSMakeRange(0, linefeedIndex)];
		[self.incomingData replaceBytesInRange:NSMakeRange(0, linefeedIndex+1) withBytes:NULL length:0];
		
		NSString *string = [[NSString alloc] initWithData:line encoding:NSUTF8StringEncoding];
		[self processIncomingString:string];
	}
}


- (void)serialPort:(ORSSerialPort * __nonnull)serialPort didReceiveData:(NSData * __nonnull)data {
	[self.incomingData appendData:data];
	[self processIncomingData];
}


- (void)fetchBedOffsetsWithCompletionHandler:(void(^)(BOOL success, TFPBedLevelOffsets offsets))completionHandler {
	[self sendGCodeString:@"M578" responseHandler:^(BOOL success, NSString *value) {
		TFPBedLevelOffsets offsets;
		if(success) {
			NSDictionary *offsetData = [self dictionaryFromResponseValueString:value];
			offsets.backRight = [offsetData[@"BRO"] doubleValue];
			offsets.backLeft = [offsetData[@"BLO"] doubleValue];
			offsets.frontRight = [offsetData[@"FRO"] doubleValue];
			offsets.frontLeft = [offsetData[@"FLO"] doubleValue];
			offsets.common = [offsetData[@"ZO"] doubleValue];

			completionHandler(YES, offsets);
			
		}else{
			completionHandler(NO, offsets);
		}
	}];
}


- (void)setBedOffsets:(TFPBedLevelOffsets)offsets completionHandler:(void(^)(BOOL success))completionHandler {
	TFPGCode *code = [TFPGCode codeWithString:@"M577"];
	code = [code codeBySettingField:'X' toValue:offsets.backLeft];
	code = [code codeBySettingField:'Y' toValue:offsets.backRight];
	code = [code codeBySettingField:'Z' toValue:offsets.frontRight];
	code = [code codeBySettingField:'E' toValue:offsets.frontLeft];
	code = [code codeBySettingField:'F' toValue:offsets.common];
	
	[self sendGCode:code responseHandler:^(BOOL success, NSString *value) {
		completionHandler(success);
	}];
}


- (void)fetchBacklashValuesWithCompletionHandler:(void(^)(BOOL success, TFPBacklashValues values))completionHandler {
	[self sendGCodeString:@"M572" responseHandler:^(BOOL success, NSString *value) {
		TFPBacklashValues values;
		if(success) {
			NSDictionary *backlashData = [self dictionaryFromResponseValueString:value];
			values.x = [backlashData[@"BX"] doubleValue];
			values.y = [backlashData[@"BY"] doubleValue];
			
			completionHandler(YES, values);
			
		}else{
			completionHandler(NO, values);
		}
	}];
}


- (void)fetchPositionWithCompletionHandler:(void(^)(BOOL success, TFP3DVector *position, double E))completionHandler {
	[self sendGCodeString:@"M114" responseHandler:^(BOOL success, NSString *value) {
		if(success) {
			NSDictionary *params = [self dictionaryFromResponseValueString:value];
			
			TFP3DVector *position = [TFP3DVector vectorWithX:@([params[@"X"] doubleValue]) Y:@([params[@"Y"] doubleValue]) Z:@([params[@"Z"] doubleValue])];
			
			completionHandler(YES, position, [params[@"E"] doubleValue]);
			
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
	[self sendGCodeString:(relative ? @"G91" : @"G90") responseHandler:^(BOOL success, NSString *value) {
		completionHandler(success);
	}];
}


- (void)moveToPosition:(TFP3DVector*)position EPosition:(NSNumber*)E usingFeedRate:(double)F completionHandler:(void(^)(BOOL success))completionHandler {
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
	if(E) {
		code = [code codeBySettingField:'E' toValue:E.doubleValue];
	}
	if(F >= 0) {
		code = [code codeBySettingField:'F' toValue:F];
	}

	[self sendGCode:code responseHandler:^(BOOL success, NSString *value) {
		completionHandler(success);
	}];
}


const double maxMMPerSecond = 60.001;

+ (double)convertFeedRate:(double)feedRate {
	feedRate /= 60;
	feedRate = MIN(feedRate, maxMMPerSecond);
	
	double factor = feedRate / maxMMPerSecond;
	feedRate = 30 + (1 - factor) * 800;
	return feedRate;
}


@end


