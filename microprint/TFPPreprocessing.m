//
//  TFPPreprocessing.m
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-09.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPreprocessing.h"
#import "TFPBasicPreparationPreprocessor.h"
#import "TFPBedCompensationPreprocessor.h"
#import "TFPBacklashPreprocessor.h"
#import "TFPFeedRateConversionPreprocessor.h"
#import "TFPThermalBondingPreprocessor.h"
#import "TFPWaveBondingPreprocessor.h"

@implementation TFPPreprocessing


+ (TFPGCodeProgram *)programByPreprocessingProgram:(TFPGCodeProgram *)program usingParameters:(TFPPrintParameters *)params {
	if(params.useBasicPreparation) {
		program = [[[TFPBasicPreparationPreprocessor alloc] initWithProgram:program] processUsingParameters:params];
	}
	
	if(params.useWaveBonding) {
		program = [[[TFPWaveBondingPreprocessor alloc] initWithProgram:program] processUsingParameters:params];
	}
	
	program = [[[TFPThermalBondingPreprocessor alloc] initWithProgram:program] processUsingParameters:params];
	program = [[[TFPBedCompensationPreprocessor alloc] initWithProgram:program] processUsingParameters:params];
	
	if(params.useBacklashCompensation) {
		program = [[[TFPBacklashPreprocessor alloc] initWithProgram:program] processUsingParameters:params];
	}
	
	program = [[[TFPFeedRateConversionPreprocessor alloc] initWithProgram:program] processUsingParameters:params];
	return program;
}


@end
