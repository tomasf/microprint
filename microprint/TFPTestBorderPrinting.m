//
//  TFPTestBorderPrinting.m
//  microprint
//
//  Created by Tomas Franzén on Fri 2015-07-17.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPTestBorderPrinting.h"
#import "TFPGCodeHelpers.h"


@implementation TFPTestBorderPrinting


+ (TFPGCodeProgram*)testBorderProgram {
	const double minX = 1;
	const double minY = 9.5;
	const double maxX = 102.9;
	const double maxY = 99;
	
	const double initialZ = 0.15;
	const double Z = 0.4;
	const NSUInteger cornerWaitTime = 3;
	const double cornerExtrusion = 0.3;
	const double extrusionPerMM = 0.35755;
	
	const double temperature = 215;
	const double feedrate = 900;
	
	const double deltaX = maxX - minX;
	const double deltaY = maxY - minY;
	const double deltaXE = deltaX * extrusionPerMM;
	const double deltaYE = deltaY * extrusionPerMM;
	
	const double initialExtrusion = 8;
	const double finalRetraction = 7.5;

	const double finalOffset = -1.5;
	
	NSArray *codes = @[
					   [TFPGCode absoluteModeCode],
					   [TFPGCode moveHomeCode],
					   [TFPGCode moveWithPosition:[TFP3DVector vectorWithX:@(minX) Y:@(minY) Z:@(initialZ)] withRawFeedRate:feedrate],
					   [TFPGCode turnOnFanCode],
					   [TFPGCode codeForHeaterTemperature:temperature waitUntilDone:YES],
					   
					   [TFPGCode moveWithPosition:[TFP3DVector zVector:Z] extrusion:@(initialExtrusion) withRawFeedRate:-1],
					   [TFPGCode waitCodeWithDuration:cornerWaitTime],
					   [TFPGCode relativeModeCode],
					   [TFPGCode codeForExtrusion:cornerExtrusion withFeedRate:-1],
					   
					   [TFPGCode moveWithPosition:[TFP3DVector xVector:deltaX] extrusion:@(deltaXE) withRawFeedRate:-1],
					   [TFPGCode waitCodeWithDuration:cornerWaitTime],
					   [TFPGCode codeForExtrusion:cornerExtrusion withFeedRate:-1],
					   
					   [TFPGCode moveWithPosition:[TFP3DVector yVector:deltaY] extrusion:@(deltaYE) withRawFeedRate:-1],
					   [TFPGCode waitCodeWithDuration:cornerWaitTime],
					   [TFPGCode codeForExtrusion:cornerExtrusion withFeedRate:-1],
					   
					   [TFPGCode moveWithPosition:[TFP3DVector xVector:-deltaX] extrusion:@(deltaXE) withRawFeedRate:-1],
					   [TFPGCode waitCodeWithDuration:cornerWaitTime],
					   [TFPGCode codeForExtrusion:cornerExtrusion withFeedRate:-1],
					   
					   [TFPGCode moveWithPosition:[TFP3DVector yVector:-deltaY] extrusion:@(deltaYE) withRawFeedRate:-1],
					   [TFPGCode waitCodeWithDuration:cornerWaitTime],
					   [TFPGCode codeForExtrusion:cornerExtrusion withFeedRate:-1],
					   
					   
					   [TFPGCode moveWithPosition:[TFP3DVector vectorWithX:@(finalOffset) Y:@(finalOffset) Z:nil] extrusion:@1.5 withRawFeedRate:-1],
					   [TFPGCode moveWithPosition:[TFP3DVector vectorWithX:@(finalOffset) Y:@(finalOffset) Z:@3] extrusion:@5.3 withRawFeedRate:-1],
					   [TFPGCode codeForExtrusion:-finalRetraction withRawFeedRate:-1],
					   
					   [TFPGCode absoluteModeCode],
					   [TFPGCode moveWithPosition:[TFP3DVector xyVectorWithX:maxX y:maxY] withRawFeedRate:3000],
					   [TFPGCode moveWithPosition:[TFP3DVector zVector:20] withFeedRate:-1],
					   
					   [TFPGCode codeForTurningOffHeater],
					   [TFPGCode turnOffFanCode],
					   [TFPGCode turnOffMotorsCode],
					   ];
	
	return [[TFPGCodeProgram alloc] initWithLines:codes];
}



@end
