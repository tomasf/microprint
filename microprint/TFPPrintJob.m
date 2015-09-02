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
#import "TFPStopwatch.h"

@import IOKit.pwr_mgt;
#import "MAKVONotificationCenter.h"



@interface TFPPrintJob ()
@property dispatch_queue_t printQueue;

@property TFPPrintParameters *parameters;
@property (readwrite) TFPGCodeProgram *program;
@property IOPMAssertionID powerAssertionID;

@property NSInteger codeOffset;

@property (readwrite) TFPPrintJobState state;
@property BOOL aborted;

@property BOOL paused;
@property TFPAbsolutePosition pausePosition;
@property double pauseTemperature;
@property double pauseFeedRate;

@property double targetTemperature;
@property NSUInteger pendingRequestCount;
@property (readwrite) NSUInteger completedRequests;

@property (readwrite) TFPOperationStage stage;

@property TFPStopwatch *stopwatch;
@end



@implementation TFPPrintJob
@synthesize stage=_stage;


- (instancetype)initWithProgram:(TFPGCodeProgram*)program printer:(TFPPrinter*)printer printParameters:(TFPPrintParameters*)params {
	if(!(self = [super initWithPrinter:printer])) return nil;
	
	self.printQueue = dispatch_queue_create("se.tomasf.microprint.printJob", DISPATCH_QUEUE_SERIAL);
	self.program = program;
	self.parameters = params;
	
	self.stopwatch = [TFPStopwatch new];
	
	return self;
}


- (dispatch_queue_t)printerContextQueue {
	return self.printQueue;
}


- (void)jobEnded {
	[self ended];
	
	if(self.powerAssertionID != kIOPMNullAssertionID) {
		IOPMAssertionRelease(self.powerAssertionID);
	}
}


- (NSTimeInterval)elapsedTime {
	return self.stopwatch.elapsedTime;
}


- (void)jobDidComplete {
	[self.stopwatch stop];
	[self jobEnded];
	
	if(self.completionBlock) {
		self.completionBlock();
	}
}


// Called on any queue
- (void)setStateOnMainQueue:(TFPPrintJobState)state {
	dispatch_async(dispatch_get_main_queue(), ^{
		self.state = state;
	});
}


// Called on print queue
- (void)sendCode:(TFPGCode*)code completionHandler:(void(^)())completionHandler {
	if(code.hasFields) {
		[self.context sendGCode:code responseHandler:^(BOOL success, NSDictionary *value) {
			completionHandler();
		}];
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
				if(weakSelf.progressBlock) {
					weakSelf.progressBlock();
				}
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
	if(self.aborted || self.paused) {
		return;
	}
	
	while(self.pendingRequestCount < 1) {
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


- (BOOL)start {
	if(![super start]) {
		return NO;
	}
	__weak __typeof__(self) weakSelf = self;
	
	self.codeOffset = 0;
	self.pendingRequestCount = 0;
	self.completedRequests = 0;

	[self.stopwatch start];
	
	self.stage = TFPOperationStageRunning;
	[self setStateOnMainQueue:TFPPrintJobStatePrinting];
	
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
	
	return YES;
}


- (void)sendAbortSequenceWithCompletionHandler:(void(^)())completionHandler {
	const double retractFeedRate = 1500;
	const double raiseFeedRate = 870;
	
	NSArray *codes = @[
					   [TFPGCode relativeModeCode],
					   [TFPGCode codeForExtrusion:-2 feedRate:retractFeedRate],
					   [TFPGCode moveWithPosition:[TFP3DVector zVector:5] feedRate:raiseFeedRate],
					   [TFPGCode absoluteModeCode],
					   
					   [TFPGCode moveWithPosition:[TFP3DVector xyVectorWithX:90 y:84] feedRate:2000],
					   [TFPGCode turnOffFanCode],
					   [TFPGCode turnOffMotorsCode],
					   [TFPGCode codeForTurningOffHeater],
					   ];
	
	[self.context runGCodeProgram:[TFPGCodeProgram programWithLines:codes] completionHandler:^(BOOL success, NSArray *valueDictionaries) {
		completionHandler();
	}];
}


- (void)abort {
	if(self.state != TFPPrintJobStatePrinting && self.state != TFPPrintJobStatePaused) {
		return;
	}
	self.stage = TFPOperationStageEnding;
	[self setStateOnMainQueue:TFPPrintJobStateAborting];
	[self.stopwatch stop];
	
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


- (void)pause {
	if(self.state != TFPPrintJobStatePrinting) {
		return;
	}
	[self setStateOnMainQueue:TFPPrintJobStatePausing];
	[self.stopwatch stop];
	
	dispatch_async(self.printQueue, ^{
		self.paused = YES;
		[self.context sendGCode:[TFPGCode waitForCompletionCode] responseHandler:^(BOOL success, TFPGCodeResponseDictionary value) {
			self.pausePosition = self.printer.position;
			self.pauseFeedRate = self.printer.feedrate;
			self.pauseTemperature = self.printer.heaterTargetTemperature;
			
			const double raiseLength = 20;
			const double stationaryRetractAmount = 5;
			const double raiseRetractAmount = 1;
			TFP3DVector *raisedPosition = [TFP3DVector zVector:raiseLength];
			
			[self.context setRelativeMode:YES completionHandler:nil];
			[self.context sendGCode:[TFPGCode codeForExtrusion:-stationaryRetractAmount feedRate:3000] responseHandler:nil];
			[self.context sendGCode:[TFPGCode moveWithPosition:raisedPosition extrusion:@(-raiseRetractAmount) feedRate:3000] responseHandler:nil];
			[self.context setRelativeMode:NO completionHandler:nil];
			[self.context sendGCode:[TFPGCode codeForTurningOffHeater] responseHandler:nil];
			[self.context waitForExecutionCompletionWithHandler:^{
				[self setStateOnMainQueue:TFPPrintJobStatePaused];
			}];
		}];
	});
}


- (void)resume {
	if(self.state != TFPPrintJobStatePaused) {
		return;
	}
	
	[self setStateOnMainQueue:TFPPrintJobStateResuming];
	dispatch_async(self.printQueue, ^{
		NSLog(@"Resuming from position X %.02f, Y %.02f, Z %.02f, E %.02f, temperature %.0f, feed rate: %.0f",
			  self.pausePosition.x, self.pausePosition.y, self.pausePosition.z, self.pausePosition.e, self.pauseTemperature, self.pauseFeedRate);
		
		[self.context sendGCode:[TFPGCode codeForHeaterTemperature:self.pauseTemperature waitUntilDone:YES] responseHandler:nil];
		[self.context moveToPosition:[TFP3DVector vectorWithX:@(self.pausePosition.x) Y:@(self.pausePosition.y) Z:@(self.pausePosition.z)] usingFeedRate:3000 completionHandler:nil];
		[self.context sendGCode:[TFPGCode codeForResettingPosition:nil extrusion:@(self.pausePosition.e - 5.5)] responseHandler:nil];
		[self.context sendGCode:[TFPGCode codeForSettingFeedRate:self.pauseFeedRate] responseHandler:nil];
		
		[self.context waitForExecutionCompletionWithHandler:^{
			self.paused = NO;
			[self setStateOnMainQueue:TFPPrintJobStatePrinting];
			dispatch_async(dispatch_get_main_queue(), ^{
				[self.stopwatch start];
			});
			[self sendMoreIfNeeded];
		}];
	});
}



- (TFPOperationKind)kind {
	return TFPOperationKindPrintJob;
}


- (NSString *)activityDescription {
	return @"Printing";
}


@end