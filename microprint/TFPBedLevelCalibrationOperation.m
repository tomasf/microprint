//
//  TFPBedHeightCalibrationOperation.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPBedLevelCalibrationOperation.h"
#import "TFPPrinter.h"
#import "Extras.h"
#import "TFPGCodeProgram.h"
#import "TFPPrintJob.h"
#import "TFPPreprocessing.h"
#import "TFStringScanner.h"


@interface TFPBedLevelCalibrationOperation ()
@property TFPPrintParameters *parameters;
@property TFPPrintJob *printJob;
@end


@implementation TFPBedLevelCalibrationOperation


+ (TFPGCodeProgram*)testBorderProgram {
	static TFPGCodeProgram *program;
	if(!program) {
		NSString *string = (@"M106 \n"
							@"M109 S215 \n"
							@"G90 \n"
							@"G0 X1 Y9.5 Z0.15 F900 \n"
							@"G0 Z0.4 E6 \n"
							@"G4 S3 \n"
							@"G0 E6.3 \n"
							@"G0 X102.9 Y9.5 Z0.4 E42.73402 \n"
							@"G4 S3 \n"
							@"G0 E43.03402 \n"
							@"G0 X102.9 Y99 Z0.4 E75.03445 \n"
							@"G4 S3 \n"
							@"G0 E75.33446 \n"
							@"G0 X1 Y99 Z0.4 E111.7685 \n"
							@"G4 S3 \n"
							@"G0 E112.0685 \n"
							@"G0 X1 Y9.5 Z0.4 E144.0689 \n"
							@"G4 S3 \n"
							@"G0 E144.3689 \n"
							@"G0 X-0.5 Y8 Z0.4 E145.8858 \n"
							@"G0 X-2 Y6.5 Z2.4 E151.1951 \n"
							@"G0 E148.1951 \n"
							@"G0 X102.9 Y99 Z20 \n"
							);
		program = [[TFPGCodeProgram alloc] initWithString:string];
	}
	return program;
}


- (void)calculateNewOffsetsForBackLeft:(double)backLeft backRight:(double)backRight frontRight:(double)frontRight frontLeft:(double)frontLeft {
	const double target = 0.4;
	
	double backLeftDelta = target - backLeft;
	double backRightDelta = target - backRight;
	double frontRightDelta = target - frontRight;
	double frontLeftDelta = target - frontLeft;
	
	TFPBedLevelOffsets offsets = self.parameters.bedLevelOffsets;
	offsets.backLeft += backLeftDelta;
	offsets.backRight += backRightDelta;
	offsets.frontRight += frontRightDelta;
	offsets.frontLeft += frontLeftDelta;
	
	[self.printer setBedOffsets:offsets completionHandler:^(BOOL success) {
		TFLog(@"New bed offsets: %@", TFPBedLevelOffsetsDescription(offsets));
		TFLog(@"Done. You might want to try running this calibration a few more times.");
		exit(EXIT_SUCCESS);
	}];
}


- (void)promptForValues {
	TFLog(@"");
	TFLog(@"Printing is done. Remove the print from the bed, keeping track of which side is which.");
	TFLog(@"Measure the height of the border at each corner (or near each corner; there's often a blob there) a few times and enter the measurements. You can take several measurements per corner and MicroPrint will average them for you.");
	TFLog(@"Specify one or more heights per corner, separated by spaces.");
	
	[self promptForMeasurementsWithLabel:@"Back-left corner heights" completionHandler:^(double backLeft) {
		[self promptForMeasurementsWithLabel:@"Back-right corner heights" completionHandler:^(double backRight) {
			[self promptForMeasurementsWithLabel:@"Front-right corner heights" completionHandler:^(double frontRight) {
				[self promptForMeasurementsWithLabel:@"Front-left corner heights" completionHandler:^(double frontLeft) {
					[self calculateNewOffsetsForBackLeft:backLeft backRight:backRight frontRight:frontRight frontLeft:frontLeft];
				}];
			}];
		}];
	}];
}


- (void)promptForMeasurementsWithLabel:(NSString*)label completionHandler:(void(^)(double value))completionHandler {
	__weak __typeof__(self) weakSelf = self;
	setbuf(stdout, NULL);
	printf("%s: ", label.UTF8String);
	
	static NSCharacterSet *valueCharacterSet;
	if(!valueCharacterSet) {
		valueCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789.,"];
	}
	
	TFPListenForInputLine(^(NSString *line) {
		TFStringScanner *scanner = [TFStringScanner scannerWithString:line];
		
		double sum = 0;
		NSUInteger count = 0;
		
		while(!scanner.atEnd) {
			[scanner scanWhitespace];
			NSString *valueString = [scanner scanStringFromCharacterSet:valueCharacterSet];
			
			if(!valueString && scanner.isAtEnd) {
				break;
			}else if(!valueString) {
				TFLog(@"Invalid measurement!");
				[weakSelf promptForMeasurementsWithLabel:label completionHandler:completionHandler];
				return;
			}
			
			valueString = [valueString stringByReplacingOccurrencesOfString:@"," withString:@"."];
			double value = [valueString doubleValue];
			
			if(value > DBL_EPSILON) {
				sum += value;
				count++;
			}
		}
		
		completionHandler(sum / count);
	});
}


- (void)printTestBorder {
	__weak __typeof__(self) weakSelf = self;
	
	[self.printer fillInOffsetAndBacklashValuesInPrintParameters:self.parameters completionHandler:^(BOOL success) {
		if(!success) {
			TFLog(@"Failed to fetch bed offset or backlash values :(");
			exit(EXIT_FAILURE);
		}
		
		TFPGCodeProgram *program = [TFPPreprocessing programByPreprocessingProgram:[self.class testBorderProgram] usingParameters:self.parameters];
		weakSelf.printJob = [[TFPPrintJob alloc] initWithProgram:program printer:weakSelf.printer printParameters:weakSelf.parameters];

		weakSelf.printJob.completionBlock = ^(NSTimeInterval duration) {
			[weakSelf promptForValues];
		};
		
		weakSelf.printJob.abortionBlock = ^(NSTimeInterval duration) {
			exit(EXIT_SUCCESS);
		};
		
		TFLog(@"Printing 0.4 mm test border...");
		[weakSelf.printJob start];
		
	}];
}


- (void)startWithPrintParameters:(TFPPrintParameters*)params {
	self.parameters = params;
	[self printTestBorder];
}


@end