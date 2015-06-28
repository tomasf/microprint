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

	for(__strong TFPGCode *code in self.program.lines) {
		if ([(code.comment ?: @"") rangeOfString:@"LAYER:"].location != NSNotFound) {
			if (num == 0) {
				double num3 = parameters.idealTemperature;
				if (parameters.filamentType == TFPFilamentTypePLA) {
					num3 = [self boundedTemperature:num3 + 10];
				} else {
					num3 = [self boundedTemperature:num3 + 15];
				}
				
				[output addObject:[[TFPGCode codeWithString:@"M109"] codeBySettingField:'S' toValue:num3]];
				flag = true;
			} else if (num == 1) {
				double num3 = parameters.idealTemperature;
				if (parameters.filamentType == TFPFilamentTypePLA) {
					num3 = [self boundedTemperature:num3 + 5];
				} else {
					num3 = [self boundedTemperature:num3 + 10];
				}
				[output addObject:[[TFPGCode codeWithString:@"M109"] codeBySettingField:'S' toValue:num3]];
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
				if (lastCode != nil && flag && (parameters.filamentType == TFPFilamentTypeABS || parameters.filamentType == TFPFilamentTypeHIPS || parameters.filamentType == TFPFilamentTypePLA)) {
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
		
		if (!parameters.useWaveBonding && parameters.filamentType == TFPFilamentTypeABS && G >= 0 && [code hasField:'Z'] && !inRelativeMode) {
			code = [code codeByAdjustingField:'Z' offset:-0.1];
		}
		
		[output addObject:code];
	}

	return [[TFPGCodeProgram alloc] initWithLines:output];
}


@end