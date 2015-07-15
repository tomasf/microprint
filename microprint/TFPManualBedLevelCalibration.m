//
//  TFPManualBedLevelCalibration.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-07-12.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPManualBedLevelCalibration.h"
#import "Extras.h"
#import "TFPGCodeHelpers.h"


const double moveFeedRate = 2900;
const double fineMoveFeedRate = 1000;


@interface TFPManualBedLevelCalibration ()
@property dispatch_source_t keyListener;
@end



@implementation TFPManualBedLevelCalibration


- (instancetype)initWithPrinter:(TFPPrinter *)printer {
	if(!(self = [super initWithPrinter:printer])) return nil;
	
	self.startZ = 2;
	self.heightTarget = 0.3;
	
	return self;
}


- (void)promptForNewZLevelWithCurrent:(double)Z completionHandler:(void(^)(double Z))completionHandler {
	NSString *line = TFPGetInputLine();
	line = [[line lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if([line hasPrefix:@"d"] || [line isEqual:@""]) {
		Z -= 0.05;
		
	} else if ([line hasPrefix:@"u"]){
		Z += 0.05;
		
	} else if ([line hasPrefix:@"n"]){
		completionHandler(Z);
		return;
		
	} else {
		return;
	}
	
	[self.printer moveToPosition:[TFP3DVector zVector:Z] usingFeedRate:fineMoveFeedRate completionHandler:^(BOOL success) {
		if([line isEqual:@""]) {
			TFPEraseLastLine();
		}
		TFLog(@"%.02f mm", Z);
		[self promptForNewZLevelWithCurrent:Z completionHandler:completionHandler];
	}];

}



- (void)promptForZFromPositions:(NSArray*)vectors completionHandler:(void(^)(NSArray *zValues))completionHandler {
	TFP3DVector *position = vectors.firstObject;
	
	[self.printer moveToPosition:position usingFeedRate:moveFeedRate completionHandler:^(BOOL success) {
		TFLog(@"");
		TFLog(@"* Press Return to lower the print head 0.05 mm, enter \"up\" (u) to go back up and \"next\" (n) to %@.", (vectors.count == 1) ? @"finish calibration" : @"go to the next corner");
		
		[self promptForNewZLevelWithCurrent:position.z.doubleValue completionHandler:^(double newZ){
			
			NSArray *remainingPositions = [vectors subarrayWithRange:NSMakeRange(1, vectors.count-1)];
			if(remainingPositions.count) {
				[self promptForZFromPositions:remainingPositions completionHandler:^(NSArray *zValues) {
					NSMutableArray *values = [@[@(newZ)] mutableCopy];
					[values addObjectsFromArray:zValues];
					completionHandler(values);
				}];
				
			}else{
				completionHandler(@[@(newZ)]);
			}
		}];
	}];
}



- (void)start {
	const double initialZ = self.startZ;
	const double targetOffset = self.heightTarget;
	const double minX = 1, minY = 9.5, maxX = 102.9, maxY = 99;
	const double raiseLevel = initialZ + 5;
	
	TFP3DVector *backLeft = [TFP3DVector vectorWithX:@(minX) Y:@(maxY) Z:@(initialZ)];
	TFP3DVector *backRight = [TFP3DVector vectorWithX:@(maxX) Y:@(maxY) Z:@(initialZ)];
	TFP3DVector *frontRight = [TFP3DVector vectorWithX:@(maxX) Y:@(minY) Z:@(initialZ)];
	TFP3DVector *frontLeft = [TFP3DVector vectorWithX:@(minX) Y:@(minY) Z:@(initialZ)];
	NSArray *positions = @[backLeft, backRight, frontRight, frontLeft];
	
	TFP3DVector *moveAwayPosition = [TFP3DVector vectorWithX:@(maxX) Y:@(maxY) Z:@30];
	
	TFPGCodeProgram *preparation = [TFPGCodeProgram programWithLines:@[
																	   [TFPGCode moveHomeCode],
																	   [TFPGCode absoluteModeCode],
																	   [TFPGCode moveWithPosition:[TFP3DVector zVector:raiseLevel] withFeedRate:moveFeedRate],
																	   ]];
	
	[self.printer runGCodeProgram:preparation completionHandler:^(BOOL success) {
		TFLog(@"");
		TFLog(@"*** Bed level calibration ***");
		TFLog(@"We're going to calibrate the height of each of the four corners of your print bed. For each corner, you'll be asked to lower the print head until it reaches a known level above the bed.");
		TFLog(@"Take three sheets of regular paper (or something else that is 0.3 mm thick) and put them between the nozzle and the print bed. Move your sheets around while you lower the print head until you feel resistance. When you feel resistance when trying to move the sheets, we're at the correct height, and you can continue to the next corner.");
		
		[self promptForZFromPositions:positions completionHandler:^(NSArray *zValues) {
			NSAssert(zValues.count == positions.count, @"Invalid prompt position response");
			
			TFPBedLevelOffsets offsets = {.common = -targetOffset};
			offsets.backLeft = [zValues[0] doubleValue];
			offsets.backRight = [zValues[1] doubleValue];
			offsets.frontRight = [zValues[2] doubleValue];
			offsets.frontLeft = [zValues[3] doubleValue];
			
			[self.printer setBedOffsets:offsets completionHandler:^(BOOL success) {
				TFLog(@"Calibration is done. Your new bed offsets were set to %@", TFPBedLevelOffsetsDescription(offsets));
				
				[self.printer moveToPosition:moveAwayPosition usingFeedRate:moveFeedRate completionHandler:^(BOOL success) {
					[self.printer sendGCode:[TFPGCode turnOffMotorsCode] responseHandler:^(BOOL success, NSString *value) {
						exit(EXIT_SUCCESS);
					}];
				}];
			}];
		}];
		
	}];
}

@end
