//
//  TFPPrintJob.m
//  MicroPrint
//
//  Created by Tomas Franzén on Thu 2015-06-25.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrintJob.h"
#import "TFPGCode.h"
#import "TFPExtras.h"
#import "TFPGCodeHelpers.h"

@import IOKit.pwr_mgt;
#import "MAKVONotificationCenter.h"



@interface TFPPrintJob ()
@property dispatch_queue_t printQueue;

@property TFPPrintParameters *parameters;
@property (readwrite) TFPGCodeProgram *program;
@property IOPMAssertionID powerAssertionID;

@property NSInteger codeOffset;
@property uint64_t startTime;

@property BOOL aborted;

@property double targetTemperature;
@property NSUInteger pendingRequestCount;
@property (readwrite) NSUInteger completedRequests;
@end



@implementation TFPPrintJob


- (instancetype)initWithProgram:(TFPGCodeProgram*)program printer:(TFPPrinter*)printer printParameters:(TFPPrintParameters*)params {
	if(!(self = [super initWithPrinter:printer])) return nil;
	
	self.printQueue = dispatch_queue_create("se.tomasf.microprint.printJob", DISPATCH_QUEUE_SERIAL);
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


// Called on print queue
- (void)sendCode:(TFPGCode*)code completionHandler:(void(^)())completionHandler {
	if(code.hasFields) {
		[self.printer sendGCode:code responseHandler:^(BOOL success, NSDictionary *value) {
			completionHandler();
		} responseQueue:self.printQueue];
	}else{
		completionHandler();
	}
}


// Called on print queue
- (void)sendGCode:(TFPGCode*)code {
	__weak __typeof__(self) weakSelf = self;
	
	if(self.parameters.verbose) {
		TFLog(@"Sending %@", code);
	}
	
	uint64_t sendTime = TFNanosecondTime();
	self.pendingRequestCount++;
	
	[self sendCode:code completionHandler:^{
		weakSelf.pendingRequestCount--;
		dispatch_async(dispatch_get_main_queue(), ^{
			weakSelf.completedRequests++;
		});
		
		[weakSelf sendMoreIfNeeded];
		if(weakSelf.parameters.verbose) {
			TFLog(@"%d of %d codes. Got response for %@ after %.03f s", (int)weakSelf.completedRequests, (int)weakSelf.program.lines.count, code, ((double)(TFNanosecondTime()-sendTime)) / NSEC_PER_SEC);
		}
		if(weakSelf.progressBlock && !self.aborted) {
			dispatch_async(dispatch_get_main_queue(), ^{
				weakSelf.progressBlock();
			});
		}
	}];
	
	NSInteger M = [code valueForField:'M' fallback:-1];
	if(M == 104 || M == 109) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self.targetTemperature = [code valueForField:'S'];
		});
	}
}


// Called on print queue
- (TFPGCode*)popNextLine {	
	while(self.codeOffset < self.program.lines.count && ![self.program.lines[self.codeOffset] hasFields]) {
		self.codeOffset++;
		dispatch_async(dispatch_get_main_queue(), ^{
			self.completedRequests++;
		});
	}
	
	if(self.codeOffset >= self.program.lines.count) {
		return nil;
	}
	
	TFPGCode *code = self.program.lines[self.codeOffset];
	self.codeOffset++;
	
	return code;
}


// Called on print queue
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
	
	dispatch_async(dispatch_get_main_queue(), ^{
		if(self.completedRequests >= self.program.lines.count) {
			[self jobDidComplete];
		}		
	});
}


- (void)start {
	[super start];
	__weak __typeof__(self) weakSelf = self;
	
	self.codeOffset = 0;
	self.pendingRequestCount = 0;
	self.completedRequests = 0;
	self.startTime = TFNanosecondTime();
	
	if(self.parameters.verbose) {
		self.printer.incomingCodeBlock = ^(NSString *line){
			TFLog(@"< %@", line);
		};
		self.printer.outgoingCodeBlock = ^(NSString *line){
			TFLog(@"> %@", line);
		};
	}
	
	dispatch_async(self.printQueue, ^{
		[self sendMoreIfNeeded];
	});
	
	[self.printer addObserver:self keyPath:@"heaterTemperature" options:0 block:^(MAKVONotification *notification) {
		double temp = weakSelf.printer.heaterTemperature;
		if(temp < 0) {
			weakSelf.targetTemperature = 0;
		}else if(weakSelf.targetTemperature > 0 && weakSelf.heatingProgressBlock){
			weakSelf.heatingProgressBlock(weakSelf.targetTemperature, temp);
		}
	}];
	
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
					   [TFPGCode codeForExtrusion:-5 feedRate:retractFeedRate],
					   [TFPGCode moveWithPosition:[TFP3DVector zVector:1] feedRate:raiseFeedRate],
					   [TFPGCode codeForExtrusion:-4 feedRate:retractFeedRate],
					   [TFPGCode moveWithPosition:[TFP3DVector zVector:4] feedRate:raiseFeedRate],
					   [TFPGCode absoluteModeCode],
					   
					   [TFPGCode moveWithPosition:[TFP3DVector yVector:84] feedRate:-1],
					   [TFPGCode turnOffFanCode],
					   [TFPGCode turnOffMotorsCode],
					   [TFPGCode codeForTurningOffHeater],
					   ];
	
	[self.printer runGCodeProgram:[TFPGCodeProgram programWithLines:codes] completionHandler:^(BOOL success, NSArray *valueDictionaries) {
		completionHandler();
	} responseQueue:self.printQueue];
}


- (void)abort {
	dispatch_async(self.printQueue, ^{
		self.aborted = YES;
		
		[self sendAbortSequenceWithCompletionHandler:^{
			dispatch_async(dispatch_get_main_queue(), ^{
				[self jobEnded];
				
				if(self.abortionBlock) {
					self.abortionBlock();
				}
			});
		}];
	});
}


- (NSString *)activityDescription {
	return @"Printing";
}


@end