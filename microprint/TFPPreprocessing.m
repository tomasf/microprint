//
//  TFPPreprocessing.m
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-09.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPreprocessing.h"
#import "TFPBasicPreparationPreprocessor.h"
#import "TFPThermalBondingPreprocessor.h"
#import "TFPWaveBondingPreprocessor.h"

@implementation TFPPreprocessing


+ (TFPGCodeProgram *)programByPreprocessingProgram:(TFPGCodeProgram *)program usingParameters:(TFPPrintParameters *)params {
	program = [[[TFPBasicPreparationPreprocessor alloc] initWithProgram:program] processUsingParameters:params];
	
	if(params.useWaveBonding) {
		program = [[[TFPWaveBondingPreprocessor alloc] initWithProgram:program] processUsingParameters:params];
	}
	
	program = [[[TFPThermalBondingPreprocessor alloc] initWithProgram:program] processUsingParameters:params];	
	return program;
}


@end
