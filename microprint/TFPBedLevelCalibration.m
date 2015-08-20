//
//  TFPManualBedLevelCalibration.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-07-12.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPBedLevelCalibration.h"
#import "TFPExtras.h"
#import "TFPGCodeHelpers.h"
#import "TFPBedLevelCompensator.h"


const double moveFeedRate = 2900;
const double fineMoveFeedRate = 1000;
const double adjustmentAmount = 0.05;


@interface TFPBedLevelCalibration ()
@property (readwrite) double currentLevel;
@property double zCompensation;

@property (copy) void(^continueBlock)(double level);
@property (readwrite) TFPOperationStage stage;

@property TFPBedLevelCompensator *compensator;
@end



@implementation TFPBedLevelCalibration
@synthesize stage=_stage;


- (void)moveToNewLevel:(double)level {
	self.currentLevel = level;
	[self.context moveToPosition:[TFP3DVector zVector:level + self.zCompensation] usingFeedRate:fineMoveFeedRate completionHandler:nil];
}


- (void)adjustUp {
	[self moveToNewLevel:self.currentLevel + adjustmentAmount];
}


- (void)adjustDown {
	[self moveToNewLevel:self.currentLevel - adjustmentAmount];
}


- (void)continue {
	self.continueBlock(self.currentLevel);
	self.continueBlock = nil;
}


- (void)stop {
	__weak __typeof__(self) weakSelf = self;
	const double maxX = 102.9, maxY = 99;
	TFP3DVector *moveAwayPosition = [TFP3DVector vectorWithX:@(maxX) Y:@(maxY) Z:@20];

	[weakSelf.context moveToPosition:moveAwayPosition usingFeedRate:moveFeedRate completionHandler:^(BOOL success) {
		[weakSelf.context sendGCode:[TFPGCode turnOffMotorsCode] responseHandler:^(BOOL success, NSDictionary *value) {
			[super ended];
		}];
	}];
}


- (void)promptForZFromPositions:(NSArray*)vectors index:(NSUInteger)positionIndex zOffset:(double)zOffset completionHandler:(void(^)(NSArray<NSNumber*> *zValues))completionHandler {
	__weak __typeof__(self) weakSelf = self;
	
	TFP3DVector *position = vectors.firstObject;
	TFP3DVector *offsetPosition = [position vectorByAdjustingZ:zOffset];
	self.zCompensation = [self.compensator zAdjustmentAtX:position.x.doubleValue Y:position.y.doubleValue];
	
	self.didStartMovingHandler();
	[weakSelf.context moveToPosition:offsetPosition usingFeedRate:moveFeedRate completionHandler:^(BOOL success) {
		[weakSelf.context moveToPosition:position usingFeedRate:moveFeedRate completionHandler:^(BOOL success) {
			[weakSelf.context waitForMoveCompletionWithHandler:^{
				weakSelf.currentLevel = position.z.doubleValue;
				
				weakSelf.didStopAtCornerHandler(positionIndex);
				weakSelf.continueBlock = ^(double newZ){
					
					NSArray *remainingPositions = [vectors subarrayWithRange:NSMakeRange(1, vectors.count-1)];
					if(remainingPositions.count) {
						[weakSelf promptForZFromPositions:remainingPositions index:positionIndex+1 zOffset:zOffset completionHandler:^(NSArray *zValues) {
							NSMutableArray *values = [@[@(newZ)] mutableCopy];
							[values addObjectsFromArray:zValues];
							completionHandler(values);
						}];
						
					}else{
						completionHandler(@[@(newZ)]);
					}
				};
			}];
		}];
	}];
}


- (BOOL)startAtLevel:(double)initialZ heightTarget:(double)targetOffset {
	if(![super start]) {
		return NO;
	}
	__weak __typeof__(self) weakSelf = self;
	self.stage = TFPOperationStagePreparation;

	self.compensator = [[TFPBedLevelCompensator alloc] initWithBedLevel:self.printer.bedBaseOffsets]; // Base offsets, but not calibration level
	
	const double minX = 9, minY = 5, maxX = 99, maxY = 95;
	const double raiseLevel = 5;
	
	TFP3DVector *backLeft = [TFP3DVector vectorWithX:@(minX) Y:@(maxY) Z:@(initialZ)];
	TFP3DVector *backRight = [TFP3DVector vectorWithX:@(maxX) Y:@(maxY) Z:@(initialZ)];
	TFP3DVector *frontRight = [TFP3DVector vectorWithX:@(maxX) Y:@(minY) Z:@(initialZ)];
	TFP3DVector *frontLeft = [TFP3DVector vectorWithX:@(minX) Y:@(minY) Z:@(initialZ)];
	TFP3DVector *center = [TFP3DVector vectorWithX:@(54) Y:@(50) Z:@(initialZ)];
	NSArray *positions = @[center, backLeft, backRight, frontRight, frontLeft];
	
	TFP3DVector *moveAwayPosition = [TFP3DVector vectorWithX:@(maxX) Y:@(maxY) Z:@20];
	
	TFPGCodeProgram *preparation = [TFPGCodeProgram programWithLines:@[
																	   [TFPGCode moveWithPosition:[TFP3DVector zVector:initialZ+raiseLevel] feedRate:moveFeedRate],
																	   [TFPGCode moveHomeCode],
																	   [TFPGCode absoluteModeCode],
																	   ]];
	
	[weakSelf.context runGCodeProgram:preparation completionHandler:^(BOOL success, NSArray *valueDictionaries) {
		self.stage = TFPOperationStageRunning;

		[weakSelf promptForZFromPositions:positions index:0 zOffset:raiseLevel completionHandler:^(NSArray<NSNumber*> *zValues) {
			self.stage = TFPOperationStageEnding;
			NSAssert(zValues.count == positions.count, @"Invalid prompt position response");
			
			TFPBedLevelOffsets offsets = {};
			double centerValue = zValues[TFPBedLevelCalibrationCornerCenter].doubleValue;
			
			offsets.common = centerValue - targetOffset;
			offsets.backLeft = [zValues[TFPBedLevelCalibrationCornerBackLeft] doubleValue] - centerValue;
			offsets.backRight = [zValues[TFPBedLevelCalibrationCornerBackRight] doubleValue] - centerValue;
			offsets.frontRight = [zValues[TFPBedLevelCalibrationCornerBackFrontRight] doubleValue] - centerValue;
			offsets.frontLeft = [zValues[TFPBedLevelCalibrationCornerBackFrontLeft] doubleValue] - centerValue;
			
			weakSelf.printer.bedLevelOffsets = offsets;
			weakSelf.didStartMovingHandler();
			
			[weakSelf.context moveToPosition:moveAwayPosition usingFeedRate:moveFeedRate completionHandler:^(BOOL success) {
				[weakSelf.context sendGCode:[TFPGCode turnOffMotorsCode] responseHandler:^(BOOL success, NSDictionary *value) {
					weakSelf.didFinishHandler();
					[weakSelf ended];
				}];
			}];
		}];
	}];
	
	return YES;
}


- (TFPPrinterContextOptions)printerContextOptions {
	return TFPPrinterContextOptionDisableLevelCompensation;
}


- (TFPOperationKind)kind {
	return TFPOperationKindCalibration;
}


- (NSString *)activityDescription {
	return @"Calibrating Bed Level";
}


@end