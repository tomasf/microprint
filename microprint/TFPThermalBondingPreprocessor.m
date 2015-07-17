//
//  TFPThermalBondingPreprocessor.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPThermalBondingPreprocessor.h"
#import "TFPGCode.h"
#import "Extras.h"



@implementation TFPThermalBondingPreprocessor


- (TFPGCodeProgram*)processUsingParameters:(TFPPrintParameters*)parameters {
	NSMutableArray *output = [NSMutableArray new];
	
	TFPGCode *lastCode = nil;
	TFPGCode *gCode2 = nil;
	
	BOOL flag = NO;
	int num = 0;
	int num2 = 0;
	BOOL inRelativeMode = YES;

	const double idealTemperature = parameters.idealTemperature;
	TFPFilamentType filamentType = parameters.filament.type;
	
	for(__strong TFPGCode *code in self.program.lines) {
		if ([(code.comment ?: @"") rangeOfString:@"LAYER:"].location != NSNotFound) {
			double newTemperature;
			if (num == 0) {
				if (filamentType == TFPFilamentTypePLA) {
					newTemperature = [self boundedTemperature:idealTemperature + 10];
				} else {
					newTemperature = [self boundedTemperature:idealTemperature + 15];
				}
				
				[output addObject:[[TFPGCode codeWithString:@"M109"] codeBySettingField:'S' toValue:newTemperature]];
				flag = true;
			} else if (num == 1) {
				if (filamentType == TFPFilamentTypePLA) {
					newTemperature = [self boundedTemperature:idealTemperature + 5];
				} else {
					newTemperature = [self boundedTemperature:idealTemperature + 10];
				}
				[output addObject:[[TFPGCode codeWithString:@"M109"] codeBySettingField:'S' toValue:newTemperature]];
			}
			num++;
		}
		if ([(code.comment ?: @"") rangeOfString:@"LAYER:0"].location != NSNotFound) {
			[output addObject:[[TFPGCode codeWithString:@"M109"] codeBySettingField:'S' toValue:parameters.idealTemperature]];
			flag = NO;
		}
		
		NSInteger G = [code valueForField:'G' fallback:-1];
		
		if (G >= 0 && !parameters.useWaveBonding) {
			if (G == 0 || G == 1) {
				if (lastCode != nil && flag && (filamentType == TFPFilamentTypeABS || filamentType == TFPFilamentTypeHIPS || filamentType == TFPFilamentTypePLA)) {
					if (num2 <= 1 && num <= 1) {
						if ([self isSharpCornerFromLine:code toLine:lastCode]) {
							if (gCode2 == nil) {
								TFPGCode *tackPoint = [self makeTackPointForCurrentLine:code lastTackPoint:lastCode];
								if(tackPoint) {
									[output addObject:tackPoint];
								}
							}
							gCode2 = code;
							num2++;
						}
						
					} else if (num2 >= 1 && num <= 1 && [self isSharpCornerFromLine:code toLine:gCode2]) {
						TFPGCode *tackPoint = [self makeTackPointForCurrentLine:code lastTackPoint:gCode2];
						if(tackPoint) {
							[output addObject:tackPoint];
						}
						gCode2 = code;
					}
				}
			} else if (G == 91) {
				inRelativeMode = true;
			} else if (G == 90) {
				inRelativeMode = false;
			}
		}
		
		lastCode = code;
		
		if (!parameters.useWaveBonding && filamentType == TFPFilamentTypeABS && G >= 0 && [code hasField:'Z'] && !inRelativeMode) {
			code = [code codeByAdjustingField:'Z' offset:-0.1];
		}
		
		[output addObject:code];
	}

	return [[TFPGCodeProgram alloc] initWithLines:output];
}


@end