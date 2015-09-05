//
//  TFPExtrusionOperation.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPExtrusionOperation.h"
#import "TFPExtras.h"
#import "TFPGCodeHelpers.h"
#import "TFP3DVector.h"

#import "TFAsyncOperationCoalescer.h"
#import "MAKVONotificationCenter.h"


static const double extrudeStepLength = 0.5;
static const double extrudeFeedRate = 210;
static const double minimumZLevelForOperation = 25;



@interface TFPExtrusionOperation ()
@property BOOL retract;
@property BOOL stopped;

@property (readwrite) TFPOperationStage stage;

@property (copy) void(^cancelHeatingBlock)();
@property (copy) void(^cancelMovingBlock)();
@end



@implementation TFPExtrusionOperation
@synthesize stage=_stage;


- (instancetype)initWithPrinter:(TFPPrinter*)printer retraction:(BOOL)retract {
	if(!(self = [super initWithPrinter:printer])) return nil;
	
	if(retract) {
		self.temperature = 275;
	}else{
		self.temperature = 230;
	}
	self.retract = retract;
	
	return self;
}


- (void)extrudeStep {
	__weak __typeof__(self) weakSelf = self;
	double extrusionLength = self.retract ? -extrudeStepLength : extrudeStepLength;
	
	[self.printer sendGCode:[TFPGCode codeForExtrusion:extrusionLength feedRate:extrudeFeedRate] responseHandler:^(BOOL success, NSDictionary *value) {
		if(weakSelf.stopped) {
			[weakSelf runEndCodeIncludingRetraction:YES];
		} else {
			[weakSelf extrudeStep];
		}
	}];
}


- (void)stop {
	if(self.cancelHeatingBlock) {
		// Prep stage
		self.cancelHeatingBlock();
		self.cancelMovingBlock();
		
		self.cancelMovingBlock = nil;
		self.cancelHeatingBlock = nil;
		[self runEndCodeIncludingRetraction:NO];
	}
	
	self.stopped = YES;
}
	 

- (void)runEndCodeIncludingRetraction:(BOOL)retractIfNeeded {
	__weak __typeof__(self) weakSelf = self;
	
	NSMutableArray *steps = [@[
							  [TFPGCode absoluteModeCode],
							  [TFPGCode codeForTurningOffHeater],
							  [TFPGCode turnOffFanCode],
							  [TFPGCode turnOffMotorsCode],
							  ] mutableCopy];
	if(!self.retract && retractIfNeeded) {
		[steps insertObject:[TFPGCode codeForExtrusion:-2 feedRate:extrudeFeedRate] atIndex:0];
	}
	
	self.stage = TFPOperationStageEnding;
	
	TFPGCodeProgram *end = [TFPGCodeProgram programWithLines:steps];
	[self.context runGCodeProgram:end completionHandler:^(BOOL success, NSArray *valueDictionaries) {
		if(weakSelf.extrusionStoppedBlock) {
			weakSelf.extrusionStoppedBlock();
		}
		[self ended];
	}];
}



- (BOOL)start {
	if(![super start]) {
		return NO;
	}
	self.stage = TFPOperationStagePreparation;
	
	__weak TFPPrinter *printer = self.printer;
	__weak __typeof__(self) weakSelf = self;
	

	[self.context sendGCode:[TFPGCode codeForSettingFanSpeed:255] responseHandler:nil];
	[self.context sendGCode:[TFPGCode absoluteModeCode] responseHandler:nil];

	[printer fetchPositionWithCompletionHandler:^(BOOL success, TFP3DVector *position, NSNumber *E) {

		TFAsyncOperationCoalescer *coalescer = [TFAsyncOperationCoalescer new];
		
		void(^heatingProgressBlock)(double progress) = [coalescer addOperation];
		self.cancelHeatingBlock = [self.context setHeaterTemperatureAsynchronously:self.temperature progressBlock:^(double currentTemperature) {
			heatingProgressBlock(currentTemperature / weakSelf.temperature);
		} completionBlock:^{
			heatingProgressBlock(1);
		}];
		
		
		TFP3DVector *raisedPosition = [TFP3DVector zVector:MAX(position.z.doubleValue, minimumZLevelForOperation)];
		void(^moveProgressBlock)(double progress) = [coalescer addOperation];
		self.cancelMovingBlock = [self.context moveAsynchronouslyToPosition:raisedPosition feedRate:3000 progressBlock:^(double fraction, TFP3DVector *position) {
			moveProgressBlock(fraction);
		} completionBlock:^{
			moveProgressBlock(1);
		}];
		
		coalescer.progressUpdateBlock = ^(double progress) {
			if(weakSelf.preparationProgressBlock) {
				weakSelf.preparationProgressBlock(progress);
			}
		};
		
		coalescer.completionBlock = ^{
			if(weakSelf.extrusionStartedBlock) {
				weakSelf.extrusionStartedBlock();
			}
			weakSelf.stage = TFPOperationStageRunning;
			
			[printer sendGCode:[TFPGCode relativeModeCode] responseHandler:nil];
			[weakSelf extrudeStep];
		};
	}];
	
	return YES;
}


- (TFPOperationKind)kind {
	return TFPOperationKindUtility;
}


- (NSString *)activityDescription {
	return self.retract ? @"Retracting" : @"Extruding";
}


@end