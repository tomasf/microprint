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
#import "TFPBedLevelCompensator.h"

#import "MAKVONotificationCenter.h"


static const NSUInteger maxLineNumber = 100;
const NSString *TFPPrinterResponseErrorCodeKey = @"ErrorCode";

#define ZERO(x) (x < DBL_EPSILON && x > -DBL_EPSILON)


@interface TFPPrinter (HelpersPrivate)
- (void)fetchBedOffsetsWithCompletionHandler:(void(^)(BOOL success, TFPBedLevelOffsets offsets))completionHandler;
- (void)setBedOffsets:(TFPBedLevelOffsets)offsets completionHandler:(void(^)(BOOL success))completionHandler;
- (void)fetchBedBaseLevelsWithCompletionHandler:(void(^)(BOOL success, TFPBedLevelOffsets offsets))completionHandler;
@end

@interface TFPPrinterContext (Private)
- (instancetype)initWithPrinter:(TFPPrinter*)printer queue:(dispatch_queue_t)queue options:(TFPPrinterContextOptions)options;
@end



typedef NS_OPTIONS(NSUInteger, TFPGCodeOptions) {
	TFPGCodeOptionNoLevelCompensation = 1<<0,
	TFPGCodeOptionNoBacklashCompensation = 1<<1,
	TFPGCodeOptionNoFeedRateConversion = 1<<2,
	
	TFPGCodeOptionPrioritized = 1<<3,
};


@interface TFPPrinterGCodeEntry : NSObject
@property TFPGCode *code;
@property NSInteger lineNumber;
@property TFPGCodeOptions options;

@property dispatch_queue_t responseQueue;
@property (copy) void(^responseBlock)(BOOL success, TFPGCodeResponseDictionary values);
@end


@implementation TFPPrinterGCodeEntry


- (instancetype)initWithCode:(TFPGCode*)code lineNumber:(NSInteger)line options:(TFPGCodeOptions)options responseBlock:(void(^)(BOOL, TFPGCodeResponseDictionary))block queue:(dispatch_queue_t)blockQueue {
	if(!(self = [super init])) return nil;
	
	self.code = code;
	self.lineNumber = line;
	self.responseBlock = block;
	self.responseQueue = blockQueue;
	self.options = options;
	
	return self;
}


+ (instancetype)lineNumberResetEntry {
	return [[self alloc] initWithCode:[TFPGCode codeForSettingLineNumber:0] lineNumber:0 options:0 responseBlock:nil queue:nil];
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



typedef NS_ENUM(NSUInteger, TFPMovementDirection) {
	TFPMovementDirectionNeutral,
	TFPMovementDirectionNegative,
	TFPMovementDirectionPositive,
};



@interface TFPPrinter ()
@property (readwrite) TFPPrinterConnection *connection;
@property dispatch_queue_t communicationQueue;

@property BOOL connectionFinished;
@property (readwrite) BOOL pendingConnection;
@property NSMutableArray<void(^)(NSError*)> *establishmentBlocks;

@property (readwrite) TFPPrinterColor color;
@property (readwrite, copy) NSString *serialNumber;
@property (readwrite, copy) NSString *firmwareVersion;

@property (readwrite) double feedrate;
@property (readwrite) double heaterTemperature;
@property (readwrite) BOOL hasValidZLevel;
@property (nonatomic, readwrite) TFPBedLevelOffsets bedBaseOffsets;
@property (readwrite) NSComparisonResult firmwareVersionComparedToTestedRange;

@property TFPBedLevelCompensator *bedLevelCompensator;
@property double positionX;
@property double positionY;
@property double positionZ;
@property double unadjustedPositionZ;
@property BOOL relativeMode;
@property double currentFeedRate;
@property BOOL needsFeedRateReset;

@property TFPMovementDirection movementDirectionX;
@property TFPMovementDirection movementDirectionY;
@property double adjustmentX;
@property double adjustmentY;

@property TFPPrinterGCodeEntry *pendingCodeEntry;
@property NSMutableArray<TFPPrinterGCodeEntry*> *queuedCodeEntries;
@property NSUInteger lineNumberCounter;
@property NSMutableDictionary<NSNumber*, TFPGCode*> *codeRegistry;

@property (unsafe_unretained) TFPPrinterContext *primaryContext;
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
		TFMainThread(^{
			if(weakSelf.incomingCodeBlock && ![string isEqual:@"wait"]) {
				weakSelf.incomingCodeBlock(string);
			}
		});
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
	
	[self addObserver:self keyPath:@[@"bedLevelOffsets", @"bedBaseOffsets"] options:0 block:^(MAKVONotification *notification) {
		TFPBedLevelOffsets offsets = weakSelf.bedLevelOffsets;
		offsets.backLeft += weakSelf.bedBaseOffsets.backLeft;
		offsets.backRight += weakSelf.bedBaseOffsets.backRight;
		offsets.frontLeft += weakSelf.bedBaseOffsets.frontLeft;
		offsets.frontRight += weakSelf.bedBaseOffsets.frontRight;
		offsets.common += weakSelf.bedBaseOffsets.common;
		
		dispatch_async(weakSelf.communicationQueue, ^{
			[weakSelf sendNotice:@"Re-adjusted bed level compensator for %@", TFPBedLevelOffsetsDescription(offsets)];
			weakSelf.bedLevelCompensator = [[TFPBedLevelCompensator alloc] initWithBedLevel:offsets];
		});
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
	
	[self fetchBacklashValuesWithCompletionHandler:^(BOOL success, TFPBacklashValues values) {
		if(success) {
			[self willChangeValueForKey:@"backlashValues"];
			_backlashValues = values;
			[self didChangeValueForKey:@"backlashValues"];
		}
	}];
	
	[self fetchBedBaseLevelsWithCompletionHandler:^(BOOL success, TFPBedLevelOffsets offsets) {
		if(success) {
			self.bedBaseOffsets = offsets;
		}
	}];
	
	[self syncPositionFastTracked:NO];
}


- (void)setBedLevelOffsets:(TFPBedLevelOffsets)bedLevelOffsets {
	_bedLevelOffsets = bedLevelOffsets;
	[self setBedOffsets:bedLevelOffsets completionHandler:nil];
}


- (void)setBacklashValues:(TFPBacklashValues)backlashValues {
	_backlashValues = backlashValues;
	[self setBacklashValues:backlashValues completionHandler:nil];
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
		TFPPrinterGCodeEntry *entry = [[TFPPrinterGCodeEntry alloc] initWithCode:code lineNumber:lineNumber options:0 responseBlock:nil queue:nil];
		[self.queuedCodeEntries insertObject:entry atIndex:0];
		[self dequeueCode];
	} else {
		// Deep shit
	}
}


- (void)sendGCode:(TFPGCode*)code responseHandler:(void(^)(BOOL success, NSDictionary<NSString *, NSString*> *value))block {
	[self sendGCode:code responseHandler:block responseQueue:dispatch_get_main_queue()];
}


// On communication queue here
- (void)dequeueCode {
	if(self.pendingCodeEntry) {
		return;
	}
	
	TFPPrinterGCodeEntry *entry = self.queuedCodeEntries.firstObject;
	if(entry) {
		[self.queuedCodeEntries removeObjectAtIndex:0];
		
		TFPGCode *code = entry.code;
		BOOL supplement = NO;
		code = [self adjustCodeForCalibrationIfNeeded:code options:entry.options supplement:&supplement];
		
		if(supplement) {
			[self.queuedCodeEntries insertObject:entry atIndex:0];
			entry = [[TFPPrinterGCodeEntry alloc] initWithCode:code lineNumber:-1 options:entry.options responseBlock:nil queue:nil];
		}
		code = [self adjustLineBeforeSending:code];
		self.pendingCodeEntry = entry;
		
		[self.connection sendGCode:code];
		
		TFMainThread(^{
			if(self.outgoingCodeBlock) {
				self.outgoingCodeBlock(code.ASCIIRepresentation);
			}
		});
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


// On communication queue here
- (TFPGCode*)adjustLineBeforeSending:(TFPGCode*)code {
	NSInteger G = [code valueForField:'G' fallback:-1];
	
	if(G > -1 && [code hasField:'F']) {
		double feedRate = code.feedRate;
		feedRate = [self convertToM3DSpecificFeedRate:feedRate];
		code = [code codeBySettingField:'F' toValue:feedRate];
	}
	
	return code;
}


- (TFPMovementDirection)directionForDelta:(double)delta {
	if(delta > DBL_EPSILON) {
		return TFPMovementDirectionPositive;
	}else if(delta < -DBL_EPSILON) {
		return TFPMovementDirectionNegative;
	}else{
		return TFPMovementDirectionNeutral;
	}
}


- (TFPGCode*)adjustCodeForCalibrationIfNeeded:(TFPGCode*)code options:(TFPGCodeOptions)options supplement:(BOOL*)supplement {
	NSInteger G = [code valueForField:'G' fallback:-1];

	BOOL backlashEnabled = !(options & TFPGCodeOptionNoBacklashCompensation);
	BOOL levelAdjustmentEnabled = !(options & TFPGCodeOptionNoLevelCompensation);
	
	
	if(G == 0 || G == 1) {
		if([code hasField:'X'] || [code hasField:'Y'] || [code hasField:'Z']) {
			double X, Y, Z;
			if(self.relativeMode) {
				X = self.positionX + [code valueForField:'X' fallback:0];
				Y = self.positionY + [code valueForField:'Y' fallback:0];
				Z = self.unadjustedPositionZ + [code valueForField:'Z' fallback:0];
			}else{
				X = [code valueForField:'X' fallback:self.positionX];
				Y = [code valueForField:'Y' fallback:self.positionY];
				Z = [code valueForField:'Z' fallback:self.unadjustedPositionZ];
			}
			
			double zAdjustment = [self.bedLevelCompensator zAdjustmentAtX:X Y:Y];
			
			TFPMovementDirection newDirectionX = [self directionForDelta:X - self.positionX];
			TFPMovementDirection newDirectionY = [self directionForDelta:Y - self.positionY];
			BOOL doBacklashX = NO, doBacklashY = NO;
			
			
			if(newDirectionX != TFPMovementDirectionNeutral && newDirectionX != self.movementDirectionX && self.movementDirectionX != TFPMovementDirectionNeutral) {
				self.adjustmentX += (newDirectionX == TFPMovementDirectionPositive ? self.backlashValues.x : -self.backlashValues.x);
				doBacklashX = YES;
			}
			
			if(newDirectionY != TFPMovementDirectionNeutral && newDirectionY != self.movementDirectionY && self.movementDirectionY != TFPMovementDirectionNeutral) {
				self.adjustmentY += (newDirectionY == TFPMovementDirectionPositive ? self.backlashValues.y : -self.backlashValues.y);
				doBacklashY = YES;
			}
			
			
			if(newDirectionX != TFPMovementDirectionNeutral)
				self.movementDirectionX = newDirectionX;
			if(newDirectionY != TFPMovementDirectionNeutral)
				self.movementDirectionY = newDirectionY;

			if((doBacklashX || doBacklashY) && backlashEnabled) {
				TFPGCode *backlashCode = [TFPGCode codeWithField:'G' value:0];
				backlashCode = [backlashCode codeBySettingField:'F' toValue:self.backlashValues.speed];
				backlashCode = [backlashCode codeBySettingComment:@"AUTO-BACKLASH"];
				
				if(doBacklashX) {
					backlashCode = [backlashCode codeBySettingField:'X' toValue:self.positionX + self.adjustmentX];
				}
				if(doBacklashY) {
					backlashCode = [backlashCode codeBySettingField:'Y' toValue:self.positionY + self.adjustmentY];
				}
				
				self.needsFeedRateReset = YES;
				*supplement = YES;
				code = backlashCode;
				
			}else{
				double newZ = Z + zAdjustment;
				if (self.relativeMode) {
					newZ -= self.unadjustedPositionZ;
				}
				
				if(levelAdjustmentEnabled) {
					code = [code codeBySettingField:'Z' toValue:newZ];
				}
				
				if([code hasField:'X'] && !self.relativeMode && backlashEnabled) {
					code = [code codeByAdjustingField:'X' offset:self.adjustmentX];
				}
				
				if([code hasField:'Y'] && !self.relativeMode && backlashEnabled) {
					code = [code codeByAdjustingField:'Y' offset:self.adjustmentY];
				}
				
				if(self.needsFeedRateReset) {
					if(![code hasField:'F']) {
						code = [code codeBySettingField:'F' toValue:self.currentFeedRate];
					}
					self.needsFeedRateReset = NO;
				}
				
				if([code hasField:'F']) {
					self.currentFeedRate = [code valueForField:'F'];
					TFMainThread(^{
						self.feedrate = [code valueForField:'F'];
					});
				}
			}
			
			self.positionX = X;
			self.positionY = Y;
			self.positionZ = Z + zAdjustment;
			self.unadjustedPositionZ = Z;
			
		} else if([code hasField:'F']) {
			self.currentFeedRate = [code valueForField:'F'];
			TFMainThread(^{
				self.feedrate = [code valueForField:'F'];
			});
		}
		
	} else if(G == 28) {
		[self syncPositionFastTracked:YES];
		self.movementDirectionX = TFPMovementDirectionNegative;
		self.movementDirectionY = TFPMovementDirectionNegative;
		self.adjustmentX = 0;
		self.adjustmentY = 0;
		
	} else if(G == 90) {
		self.relativeMode = NO;
		
	} else if(G == 91) {
		self.relativeMode = YES;
	}
	
	return code;
}


- (void)syncPositionFastTracked:(BOOL)fastTracked {
	TFPGCodeOptions options = (fastTracked ? TFPGCodeOptionPrioritized : 0);
	[self sendGCode:[TFPGCode codeForGettingPosition] options:options responseHandler:nil responseQueue:self.communicationQueue];
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


- (void)sendGCode:(TFPGCode*)inputCode options:(TFPGCodeOptions)options responseHandler:(void(^)(BOOL success, NSDictionary<NSString *, NSString*> *value))block responseQueue:(dispatch_queue_t)queue {
	if([self sendReplacementsForGCodeIfNeeded:inputCode responseHandler:block responseQueue:queue]) {
		return;
	}
	
	BOOL prio = options & TFPGCodeOptionPrioritized;
	
	dispatch_async(self.communicationQueue, ^{
		TFPGCode *code = inputCode;
		NSInteger lineNumber = -1;
		if([self codeNeedsLineNumber:code] && !prio) {
			lineNumber = [self consumeLineNumber];
			code = [inputCode codeBySettingLineNumber:lineNumber];
			self.codeRegistry[@(lineNumber)] = code;
		}
		
		TFPPrinterGCodeEntry *entry = [[TFPPrinterGCodeEntry alloc] initWithCode:code lineNumber:lineNumber options:options responseBlock:block queue:queue];
		if(prio) {
			[self.queuedCodeEntries insertObject:entry atIndex:0];
		}else{
			[self.queuedCodeEntries addObject:entry];
		}
		[self dequeueCode];
	});
}


- (void)sendGCode:(TFPGCode*)inputCode responseHandler:(void(^)(BOOL success, NSDictionary<NSString *, NSString*> *value))block responseQueue:(dispatch_queue_t)queue {
	[self sendGCode:inputCode options:0 responseHandler:block responseQueue:queue];
}


- (void)runGCodeProgram:(TFPGCodeProgram *)program options:(TFPGCodeOptions)options previousValues:(NSArray*)previousValues completionHandler:(void (^)(BOOL success, NSArray *valueDictionaries))completionHandler responseQueue:(dispatch_queue_t)queue {
	if(previousValues.count < program.lines.count) {
		TFPGCode *code = program.lines[previousValues.count];
		[self sendGCode:code options:options responseHandler:^(BOOL success, NSDictionary *value) {
			if(success) {
				NSMutableArray *newValues = [previousValues mutableCopy];
				[newValues addObject:value];
				[self runGCodeProgram:program options:options previousValues:newValues completionHandler:completionHandler responseQueue:queue];
			}else{
				if(completionHandler) {
					dispatch_async(queue ?: dispatch_get_main_queue(), ^{
						completionHandler(NO, previousValues);
					});
				}
			}
		} responseQueue:queue];
	}else{
		if(completionHandler) {
			dispatch_async(queue ?: dispatch_get_main_queue(), ^{
				completionHandler(YES, previousValues);
			});
		}
	}
}


- (TFPPrinterContext*)acquireContextWithOptions:(TFPPrinterContextOptions)options queue:(dispatch_queue_t)queue {
	if(self.primaryContext && !(options & TFPPrinterContextOptionConcurrent)) {
		return nil;
	}
	
	TFPPrinterContext *context = [[TFPPrinterContext alloc] initWithPrinter:self queue:queue options:options];
	if(!(options & TFPPrinterContextOptionConcurrent)) {
		self.primaryContext = context;
	}
	return context;
}


- (void)invalidateContext:(TFPPrinterContext*)context {
	if(self.primaryContext == context) {
		self.primaryContext = nil;
	}
}


- (void)runGCodeProgram:(TFPGCodeProgram*)program options:(TFPGCodeOptions)options completionHandler:(void(^)(BOOL success, NSArray<TFPGCodeResponseDictionary> *values))completionHandler responseQueue:(dispatch_queue_t)queue {
	[self runGCodeProgram:program options:options previousValues:@[] completionHandler:completionHandler responseQueue:queue];
}


- (void)runGCodeProgram:(TFPGCodeProgram*)program completionHandler:(void(^)(BOOL success, NSArray<TFPGCodeResponseDictionary> *values))completionHandler {
	[self runGCodeProgram:program options:0 completionHandler:completionHandler responseQueue:dispatch_get_main_queue()];
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
	TFMainThread(^{
		if(temperature != self.heaterTemperature) {
			self.heaterTemperature = temperature;
		}
	});
}


- (void)updateStateForResponse:(NSDictionary<NSString*, NSString*> *)values entry:(TFPPrinterGCodeEntry*)entry {
	NSInteger M = [entry.code valueForField:'M' fallback:-1];
	
	if(M == 114) {
		if(values[@"X"]) {
			self.positionX = values[@"X"].doubleValue;
		}
		if(values[@"Y"]) {
			self.positionY = values[@"Y"].doubleValue;
		}
		if(values[@"Z"]) {
			self.positionZ = values[@"Z"].doubleValue;
			self.unadjustedPositionZ = self.positionZ - [self.bedLevelCompensator zAdjustmentAtX:self.positionX Y:self.positionY];
		}
		
		[self sendNotice:@"Synced position to (%.02f, %.02f, %.02f [%.02f])", self.positionX, self.positionY, self.unadjustedPositionZ, self.positionZ];
	}
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
			[self updateStateForResponse:value entry:entry];
			
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



@interface TFPPrinterContext ()
@property dispatch_queue_t queue;
@property (readwrite) TFPPrinter *printer;
@property TFPGCodeOptions codeOptions;
@end


@implementation TFPPrinterContext


- (instancetype)initWithPrinter:(TFPPrinter*)printer queue:(dispatch_queue_t)queue options:(TFPPrinterContextOptions)options {
	if(!(self = [super init])) return nil;
	
	self.printer = printer;
	self.queue = queue;
	
	TFPGCodeOptions codeOptions = 0;
	if(options & TFPPrinterContextOptionDisableLevelCompensation) {
		codeOptions |= TFPGCodeOptionNoLevelCompensation;
	}
	if(options & TFPPrinterContextOptionDisableBacklashCompensation) {
		codeOptions |= TFPGCodeOptionNoBacklashCompensation;
	}
	if(options & TFPPrinterContextOptionDisableFeedRateConversion) {
		codeOptions |= TFPGCodeOptionNoFeedRateConversion;
	}
	
	self.codeOptions = codeOptions;
	
	return self;
}


- (void)dealloc {
	[self invalidate];
}


- (void)invalidate {
	[self.printer invalidateContext:self];
	self.printer = nil;
}


- (void)sendGCode:(TFPGCode*)code responseHandler:(void(^)(BOOL success, TFPGCodeResponseDictionary value))block {
	[self.printer sendGCode:code options:self.codeOptions responseHandler:block responseQueue:self.queue];
}


- (void)runGCodeProgram:(TFPGCodeProgram*)program completionHandler:(void(^)(BOOL success, NSArray<TFPGCodeResponseDictionary> *values))completionHandler {
	[self.printer runGCodeProgram:program options:self.codeOptions completionHandler:completionHandler responseQueue:self.queue];
}


@end