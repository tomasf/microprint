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
#import "TFP3DVector.h"

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
@property (copy) void(^heatingCancelBlock)();

@property BOOL pendingRequest;
@property (readwrite) NSUInteger completedRequests;

@property (readwrite) TFPOperationStage stage;
@property TFPStopwatch *stopwatch;

@property (copy, readwrite) NSArray<TFPPrintLayer*> *layers;
@property NSUInteger previousLayerIndex;

@property BOOL paused;
@property TFPAbsolutePosition pausePosition;
@property double pauseTemperature;
@property double pauseFeedRate;
@end



@implementation TFPPrintJob
@synthesize stage=_stage;


- (instancetype)initWithProgram:(TFPGCodeProgram*)program printer:(TFPPrinter*)printer printParameters:(TFPPrintParameters*)params {
	if(!(self = [super initWithPrinter:printer])) return nil;
	
	self.printQueue = dispatch_queue_create("se.tomasf.microprint.printJob", DISPATCH_QUEUE_SERIAL);
	self.program = program;
	self.parameters = params;
	
	self.stopwatch = [TFPStopwatch new];
	self.layers = [program determineLayers];
	
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


- (BOOL)shouldSkipCode:(TFPGCode*)code {
	NSInteger M = [code valueForField:'M' fallback:-1];
	return (M == 104 || M == 106 || M == 107 || M == 109);
}


// Called on print queue
- (void)sendCode:(TFPGCode*)code completionHandler:(void(^)())completionHandler {
	if([self shouldSkipCode:code]) {
		completionHandler();
		
	} else {
		[self.context sendGCode:code responseHandler:^(BOOL success, NSDictionary *value) {
			completionHandler();
		}];
	}
}


// Called on print queue
- (void)sendGCode:(TFPGCode*)code {
	__weak __typeof__(self) weakSelf = self;
	
	uint64_t sendTime = TFNanosecondTime();
	self.pendingRequest = YES;
	
	[self sendCode:code completionHandler:^{
		weakSelf.pendingRequest = NO;
		
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
}


// Called on print queue
- (TFPGCode*)popNextLine {
	while(self.codeOffset < self.program.lines.count && !self.program.lines[self.codeOffset].hasFields) {
		self.codeOffset++;
		dispatch_async(dispatch_get_main_queue(), ^{
			self.completedRequests++;
		});
		TFPGCode *code = self.program.lines[self.codeOffset];
		if(!code.hasFields && code.comment.length) {
			[self.printer sendNotice:@"Comment: %@", code.comment];
		}
	}
	
	if(self.codeOffset >= self.program.lines.count) {
		return nil;
	}
	
	TFPGCode *code = self.program.lines[self.codeOffset];
	self.codeOffset++;
	
	return code;
}


- (NSUInteger)layerIndexAtCodeOffset:(NSUInteger)offset {
	return [self.layers indexesOfObjectsPassingTest:^BOOL(TFPPrintLayer *layer, NSUInteger index, BOOL *stop) {
		return NSLocationInRange(offset, layer.lineRange);
	}].firstIndex;
}


- (BOOL)adjustTemperatureIfNeeded {
	if (!self.parameters.useThermalBonding) {
		return NO;
	}
	
	NSUInteger layerIndex = [self layerIndexAtCodeOffset:self.codeOffset];
	if(layerIndex != self.previousLayerIndex) {
		self.previousLayerIndex = layerIndex;
		
		if(layerIndex == 0 || layerIndex == 1) {
			double temperature = self.parameters.temperature;
			if(layerIndex == 0) {
				temperature += 10;
			}
			
			//NSLog(@"Heating to %.0f for layer %ld", temperature, (long)layerIndex);
			
			[self.context sendGCode:[TFPGCode codeForHeaterTemperature:temperature waitUntilDone:YES] responseHandler:^(BOOL success, TFPGCodeResponseDictionary value) {
				[self sendMoreIfNeeded];
			}];
			
			return YES;
		}
	}
	return NO;
}


// Called on print queue
- (void)sendMoreIfNeeded {
	if(self.aborted || self.paused) {
		return;
	}
	
	if([self adjustTemperatureIfNeeded]) {
		return;
	}
	
	if(!self.pendingRequest) {
		TFPGCode *code = [self popNextLine];
		if(code) {
			[self sendGCode:code];
		}
	}
	
	dispatch_async(dispatch_get_main_queue(), ^{
		if(self.completedRequests >= self.program.lines.count) {
			[self runPostamble];
		}		
	});
}


- (void)startMainProgram {
	if(self.aborted) {
		return;
	}
	
	self.stage = TFPOperationStageRunning;
	[self setStateOnMainQueue:TFPPrintJobStatePrinting];
	
	dispatch_async(self.printQueue, ^{
		[self sendMoreIfNeeded];
	});
}


- (void)runPreamble {
	self.stage = TFPOperationStagePreparation;
	[self setStateOnMainQueue:TFPPrintJobStatePreparing];

	TFPPrintParameters *parameters = self.parameters;
	
	NSArray *part1 = @[[TFPGCode codeForSettingFanSpeed:parameters.filament.fanSpeed],
					   [TFPGCode codeForHeaterTemperature:parameters.temperature waitUntilDone:NO],
					   [TFPGCode absoluteModeCode],
					   [TFPGCode moveWithPosition:[TFP3DVector zVector:5] feedRate:2900],
					   [TFPGCode moveHomeCode]];
	
	NSArray *part2 = @[[TFPGCode relativeModeCode],
					   [TFPGCode codeForExtrusion:2 feedRate:2000],
					   [TFPGCode resetExtrusionCode],
					   [TFPGCode absoluteModeCode],
					   [TFPGCode codeForSettingFeedRate:2400]];
	
	[self.context runGCodeProgram:[TFPGCodeProgram programWithLines:part1] completionHandler:^(BOOL success, NSArray<TFPGCodeResponseDictionary> *values) {
		if(self.aborted) {
			return;
		}
		
		TFMainThread(^{
			self.heatingCancelBlock = [self.context setHeaterTemperatureAsynchronously:parameters.temperature progressBlock:^(double currentTemperature) {
				
			} completionBlock:^{
				[self.context runGCodeProgram:[TFPGCodeProgram programWithLines:part2] completionHandler:^(BOOL success, NSArray<TFPGCodeResponseDictionary> *values) {
					[self startMainProgram];
				}];
			 
			}];
		});
	}];
}


- (void)runPostamble {
	self.stage = TFPOperationStageEnding;
	[self setStateOnMainQueue:TFPPrintJobStateFinishing];

	double Z = MAX(self.printer.position.z, MIN(self.printer.position.z + 25, 110));

	TFP3DVector *backPosition = (Z > 60) ? [TFP3DVector xyVectorWithX:90 y:84] : [TFP3DVector xyVectorWithX:95 y:95];
	backPosition = [backPosition vectorBySettingZ:Z];
	
	NSArray *postamble = @[
						   [TFPGCode codeForTurningOffHeater],
						   [TFPGCode moveWithPosition:backPosition feedRate:-1],
						   [TFPGCode turnOffFanCode],
						   [TFPGCode turnOffMotorsCode],
						   ];
	[self.context runGCodeProgram:[TFPGCodeProgram programWithLines:postamble] completionHandler:^(BOOL success, NSArray<TFPGCodeResponseDictionary> *values) {
		TFMainThread(^{
			[self jobDidComplete];
		});
	}];
}


- (BOOL)start {
	if(![super start]) {
		return NO;
	}
	__weak __typeof__(self) weakSelf = self;
	
	self.codeOffset = 0;
	self.pendingRequest = NO;
	self.completedRequests = 0;

	[self.stopwatch start];
	[self runPreamble];
	
	[self.printer addObserver:self keyPath:@"heaterTemperature" options:0 block:^(MAKVONotification *notification) {
		double temp = weakSelf.printer.heaterTemperature;
		if(weakSelf.printer.heaterTargetTemperature > 0 && weakSelf.heatingProgressBlock){
			weakSelf.heatingProgressBlock(weakSelf.printer.heaterTargetTemperature, temp);
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
		if(self.heatingCancelBlock) {
			self.heatingCancelBlock();
			self.heatingCancelBlock = nil;
		}
		
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