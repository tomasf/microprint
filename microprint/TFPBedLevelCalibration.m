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


const double moveFeedRate = 2900;
const double fineMoveFeedRate = 1000;
const double adjustmentAmount = 0.05;


@interface TFPBedLevelCalibration ()
@property (readwrite) double currentLevel;
@property (copy) void(^continueBlock)(double level);
@property BOOL adjusting;
@property (readwrite) TFPOperationStage stage;
@end



@implementation TFPBedLevelCalibration
@synthesize stage=_stage;


- (void)moveToNewLevel:(double)level {
	self.currentLevel = level;
	
	if(!self.adjusting) {
		self.adjusting = YES;
		
		[self.printer moveToPosition:[TFP3DVector zVector:level] usingFeedRate:fineMoveFeedRate completionHandler:^(BOOL success) {
			self.adjusting = NO;
			
			if(fabs(self.currentLevel - level) > 0.01) {
				[self moveToNewLevel:self.currentLevel];
			}
		}];
	}
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

	[weakSelf.printer moveToPosition:moveAwayPosition usingFeedRate:moveFeedRate completionHandler:^(BOOL success) {
		[weakSelf.printer sendGCode:[TFPGCode turnOffMotorsCode] responseHandler:^(BOOL success, NSDictionary *value) {
			[super ended];
		}];
	}];
}


- (void)promptForZFromPositions:(NSArray*)vectors index:(NSUInteger)positionIndex zOffset:(double)zOffset completionHandler:(void(^)(NSArray *zValues))completionHandler {
	__weak __typeof__(self) weakSelf = self;
	
	TFP3DVector *position = vectors.firstObject;
	TFP3DVector *offsetPosition = [position vectorByAdjustingZ:zOffset];
	
	self.didStartMovingHandler();
	[weakSelf.printer moveToPosition:offsetPosition usingFeedRate:moveFeedRate completionHandler:^(BOOL success) {
		[weakSelf.printer moveToPosition:position usingFeedRate:moveFeedRate completionHandler:^(BOOL success) {
			[weakSelf.printer waitForMoveCompletionWithHandler:^{
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


- (void)startAtLevel:(double)initialZ heightTarget:(double)targetOffset {
	[super start];
	__weak __typeof__(self) weakSelf = self;
	self.stage = TFPOperationStagePreparation;

	const double minX = 1, minY = 9.5, maxX = 102.9, maxY = 99;
	const double raiseLevel = 5;
	
	TFP3DVector *backLeft = [TFP3DVector vectorWithX:@(minX) Y:@(maxY) Z:@(initialZ)];
	TFP3DVector *backRight = [TFP3DVector vectorWithX:@(maxX) Y:@(maxY) Z:@(initialZ)];
	TFP3DVector *frontRight = [TFP3DVector vectorWithX:@(maxX) Y:@(minY) Z:@(initialZ)];
	TFP3DVector *frontLeft = [TFP3DVector vectorWithX:@(minX) Y:@(minY) Z:@(initialZ)];
	NSArray *positions = @[backLeft, backRight, frontRight, frontLeft];
	
	TFP3DVector *moveAwayPosition = [TFP3DVector vectorWithX:@(maxX) Y:@(maxY) Z:@20];
	
	TFPGCodeProgram *preparation = [TFPGCodeProgram programWithLines:@[
																	   [TFPGCode moveWithPosition:[TFP3DVector zVector:initialZ+raiseLevel] feedRate:moveFeedRate],
																	   [TFPGCode moveHomeCode],
																	   [TFPGCode absoluteModeCode],
																	   ]];
	
	[weakSelf.printer runGCodeProgram:preparation completionHandler:^(BOOL success, NSArray *valueDictionaries) {
		self.stage = TFPOperationStageRunning;

		[weakSelf promptForZFromPositions:positions index:0 zOffset:raiseLevel completionHandler:^(NSArray *zValues) {
			self.stage = TFPOperationStageEnding;
			NSAssert(zValues.count == positions.count, @"Invalid prompt position response");
			
			TFPBedLevelOffsets offsets = {.common = -targetOffset};
			offsets.backLeft = [zValues[0] doubleValue];
			offsets.backRight = [zValues[1] doubleValue];
			offsets.frontRight = [zValues[2] doubleValue];
			offsets.frontLeft = [zValues[3] doubleValue];
			
			weakSelf.printer.bedLevelOffsets = offsets;
			weakSelf.didStartMovingHandler();
			
			[weakSelf.printer moveToPosition:moveAwayPosition usingFeedRate:moveFeedRate completionHandler:^(BOOL success) {
				[weakSelf.printer sendGCode:[TFPGCode turnOffMotorsCode] responseHandler:^(BOOL success, NSDictionary *value) {
					weakSelf.didFinishHandler();
					[weakSelf ended];
				}];
			}];
		}];
	}];
}


- (TFPOperationKind)kind {
	return TFPOperationKindCalibration;
}


- (NSString *)activityDescription {
	return @"Calibrating Bed Level";
}


@end