//
//  TFPPrintJob.m
//  MicroPrint
//
//  Created by Tomas Franzén on Thu 2015-06-25.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrintJob.h"
#import "TFPGCode.h"
#import "Extras.h"
#import "TFPGCodeHelpers.h"


@import IOKit.pwr_mgt;
#import "MAKVONotificationCenter.h"


static const uint16_t lineNumberWrapAround = 100;


@interface TFPPrintJob ()
@property TFPPrintParameters *parameters;
@property (readwrite) TFPGCodeProgram *program;
@property IOPMAssertionID powerAssertionID;

@property NSInteger codeOffset;
@property NSUInteger lineNumber;
@property uint64_t startTime;

@property BOOL aborted;

@property double targetTemperature;
@property NSUInteger pendingRequestCount;
@property (readwrite) NSUInteger completedRequests;
@property NSMutableDictionary *sentCodeRegistry;
@end



@implementation TFPPrintJob


- (instancetype)initWithProgram:(TFPGCodeProgram*)program printer:(TFPPrinter*)printer printParameters:(TFPPrintParameters*)params {
	if(!(self = [super initWithPrinter:printer])) return nil;
	
	self.program = program;
	self.parameters = params;
	
	return self;
}


- (void)jobEnded {
	[self ended];
	
	if(self.powerAssertionID != kIOPMNullAssertionID) {
		IOPMAssertionRelease(self.powerAssertionID);
	}
}


- (NSTimeInterval)elapsedTime {
	if(self.startTime == 0) {
		return 0;
	}else{
		return ((double)(TFNanosecondTime() - self.startTime)) / NSEC_PER_SEC;
	}
}


- (void)jobDidComplete {
	[self jobEnded];
	
	if(self.completionBlock) {
		self.completionBlock();
	}
}


- (void)sendCode:(TFPGCode*)code completionHandler:(void(^)())completionHandler {
	if(code.hasFields) {
		[self.printer sendGCode:code responseHandler:^(BOOL success, NSString *value) {
			completionHandler();
		}];
	}else{
		completionHandler();
	}
}



- (void)sendGCode:(TFPGCode*)code {
	__weak __typeof__(self) weakSelf = self;
	
	if(self.parameters.verbose) {
		TFLog(@"Sending %@", code);
	}
	
	uint64_t sendTime = TFNanosecondTime();
	self.pendingRequestCount++;
	
	[self sendCode:code completionHandler:^{
		weakSelf.pendingRequestCount--;
		weakSelf.completedRequests++;
		[weakSelf sendMoreIfNeeded];
		if(weakSelf.parameters.verbose) {
			TFLog(@"%d of %d codes. Got response for %@ after %.03f s", (int)weakSelf.completedRequests, (int)weakSelf.program.lines.count, code, ((double)(TFNanosecondTime()-sendTime)) / NSEC_PER_SEC);
		}
		if(weakSelf.progressBlock && !self.aborted) {
			weakSelf.progressBlock();
		}
	}];
	
	NSInteger M = [code valueForField:'M' fallback:-1];
	if(M == 104 || M == 109) {
		self.targetTemperature = [code valueForField:'S'];
	}
}


- (TFPGCode*)popNextLine {
	if(self.codeOffset >= self.program.lines.count) {
		return nil;
	}
	
	if(self.lineNumber == lineNumberWrapAround) {
		[self sendLineNumberReset];
	}
	
	TFPGCode *code = self.program.lines[self.codeOffset];
	self.codeOffset++;
	
	code = [code codeBySettingLineNumber:self.lineNumber];
	self.sentCodeRegistry[@(self.lineNumber)] = code;
	self.lineNumber++;
	
	return code;
}


- (void)sendMoreIfNeeded {
	if(self.aborted) {
		return;
	}
	
	while(self.pendingRequestCount < self.parameters.bufferSize) {
		TFPGCode *code = [self popNextLine];
		if(!code) {
			break;
		}
		[self sendGCode:code];
	}
	
	if(self.completedRequests >= self.program.lines.count) {
		[self jobDidComplete];
	}
}


- (void)sendLineNumberReset {
	TFPGCode *reset = [TFPGCode codeForSettingLineNumber:0];
	
	[self.printer sendGCode:reset responseHandler:^(BOOL success, NSString *value) {
	}];
	self.lineNumber = 1;
	self.sentCodeRegistry[@(0)] = reset;
}


- (void)start {
	[super start];
	__weak __typeof__(self) weakSelf = self;
	
	self.codeOffset = 0;
	self.pendingRequestCount = 0;
	self.completedRequests = 0;
	self.startTime = TFNanosecondTime();
	self.sentCodeRegistry = [NSMutableDictionary new];
	
	self.printer.verboseMode = self.parameters.verbose;
	
	[self sendLineNumberReset];
	[self sendMoreIfNeeded];
	
	[self.printer addObserver:self keyPath:@"heaterTemperature" options:0 block:^(MAKVONotification *notification) {
		double temp = weakSelf.printer.heaterTemperature;
		if(temp < 0) {
			weakSelf.targetTemperature = 0;
		}else if(weakSelf.targetTemperature > 0 && weakSelf.heatingProgressBlock){
			weakSelf.heatingProgressBlock(weakSelf.targetTemperature, temp);
		}
	}];
	
	self.printer.resendHandler = ^(NSUInteger lineNumber){
		if(weakSelf.parameters.verbose) {
			TFLog(@"Re-sending line N%d", (int)lineNumber);
		}
		
		TFPGCode *code = weakSelf.sentCodeRegistry[@(lineNumber)];
		code = [code codeBySettingField:'N' toValue:lineNumber];
		
		// Last block is cancelled, decrement pending to balance
		weakSelf.pendingRequestCount--;
		[weakSelf sendGCode:code];
	};
	
	
	IOReturn asserted = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep, kIOPMAssertionLevelOn, CFSTR("MicroPrint print job"), &(self->_powerAssertionID));
	if (asserted != kIOReturnSuccess) {
		TFLog(@"Failed to assert kIOPMAssertionTypeNoIdleSleep!");
		self.powerAssertionID = kIOPMNullAssertionID;
	}
}


- (void)sendAbortSequenceWithCompletionHandler:(void(^)())completionHandler {
	const double retractFeedRate = 1995;
	const double raiseFeedRate = 870;
	
	NSArray *codes = @[
					   [TFPGCode relativeModeCode],
					   [TFPGCode codeForExtrusion:-5 withFeedRate:retractFeedRate],
					   [TFPGCode moveWithPosition:[TFP3DVector zVector:1] withFeedRate:raiseFeedRate],
					   [TFPGCode codeForExtrusion:-4 withFeedRate:retractFeedRate],
					   [TFPGCode moveWithPosition:[TFP3DVector zVector:4] withFeedRate:raiseFeedRate],
					   [TFPGCode absoluteModeCode],
					   
					   [TFPGCode moveWithPosition:[TFP3DVector yVector:84] withFeedRate:-1],
					   [TFPGCode turnOffFanCode],
					   [TFPGCode stopCode],
					   ];
	
	[self.printer runGCodeProgram:[TFPGCodeProgram programWithLines:codes] completionHandler:^(BOOL success) {
		completionHandler();
	}];
}


- (void)abort {	
	self.aborted = YES;
	
	[self sendAbortSequenceWithCompletionHandler:^{
		[self jobEnded];
		
		if(self.abortionBlock) {
			self.abortionBlock();
		}
	}];
}


- (NSString *)activityDescription {
	return @"Printing";
}


@end
