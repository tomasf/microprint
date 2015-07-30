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

#import "MAKVONotificationCenter.h"


static const double extrudeStepLength = 10;
static const double extrudeFeedRate = 210;
static const double minimumZLevelForOperation = 25;



@interface TFPExtrusionOperation ()
@property BOOL retract;
@property BOOL stopped;
@end


@implementation TFPExtrusionOperation


- (instancetype)initWithPrinter:(TFPPrinter*)printer retraction:(BOOL)retract {
	if(!(self = [super initWithPrinter:printer])) return nil;
	
	self.temperature = 215;
	self.retract = retract;
	
	return self;
}


- (void)extrudeStep {
	__weak __typeof__(self) weakSelf = self;
	double extrusionLength = self.retract ? -extrudeStepLength : extrudeStepLength;
	
	[self.printer sendGCode:[TFPGCode codeForExtrusion:extrusionLength feedRate:extrudeFeedRate] responseHandler:^(BOOL success, NSDictionary *value) {
		if(weakSelf.stopped) {
			[weakSelf runEndCode];
		} else {
			[weakSelf extrudeStep];
		}
	}];
}


- (void)stop {
	self.stopped = YES;
}
	 

- (void)runEndCode {
	__weak __typeof__(self) weakSelf = self;
	
	TFPGCodeProgram *end = [TFPGCodeProgram programWithLines:@[
																[TFPGCode absoluteModeCode],
																[TFPGCode codeForTurningOffHeater],
																[TFPGCode turnOffFanCode],
																[TFPGCode turnOffMotorsCode],
																]];
	
	[self.printer runGCodeProgram:end completionHandler:^(BOOL success, NSArray *valueDictionaries) {
		if(weakSelf.extrusionStoppedBlock) {
			weakSelf.extrusionStoppedBlock();
		}
		[self ended];
	}];
}



- (void)start {
	[super start];
	
	__weak TFPPrinter *printer = self.printer;
	__weak __typeof__(self) weakSelf = self;
	
	id<MAKVOObservation> token = [printer addObserver:nil keyPath:@"heaterTemperature" options:0 block:^(MAKVONotification *notification) {
		if(printer.heaterTemperature > 0 && weakSelf.heatingProgressBlock) {
			weakSelf.heatingProgressBlock(printer.heaterTemperature);
		}
	}];
	
	TFPGCodeProgram *prep = [TFPGCodeProgram programWithLines:@[
																[TFPGCode codeForSettingFanSpeed:255],
																[TFPGCode codeForHeaterTemperature:self.temperature waitUntilDone:NO],
																[TFPGCode absoluteModeCode],
																]];
	
	TFPGCodeProgram *heatAndWait = [TFPGCodeProgram programWithLines:@[
																	   [TFPGCode codeForHeaterTemperature:self.temperature waitUntilDone:YES],
																	   [TFPGCode relativeModeCode],
																	   ]];
	
	
	[printer runGCodeProgram:prep completionHandler:^(BOOL success, NSArray *valueDictionaries) {
		[printer fetchPositionWithCompletionHandler:^(BOOL success, TFP3DVector *position, NSNumber *E) {
			TFP3DVector *raisedPosition = [TFP3DVector zVector:MAX(position.z.doubleValue, minimumZLevelForOperation)];
			
			if(weakSelf.movingStartedBlock) {
				weakSelf.movingStartedBlock();
			}
			
			[printer moveToPosition:raisedPosition usingFeedRate:3000 completionHandler:^(BOOL success) {
				if(weakSelf.stopped) {
					[weakSelf runEndCode];
					return;
				}
				
				if(weakSelf.heatingStartedBlock) {
					weakSelf.heatingStartedBlock();
				}
				
				[printer runGCodeProgram:heatAndWait completionHandler:^(BOOL success, NSArray *valueDictionaries) {
					[token remove];
					if(weakSelf.stopped) {
						[weakSelf runEndCode];
						return;
					}

					if(weakSelf.extrusionStartedBlock) {
						weakSelf.extrusionStartedBlock();
					}
					
					[weakSelf extrudeStep];
				}];
			}];
		}];
	}];
}


- (NSString *)activityDescription {
	return self.retract ? @"Retracting" : @"Extruding";
}


@end