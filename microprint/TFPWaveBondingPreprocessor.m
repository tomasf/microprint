//
//  TFPWaveBondingPreprocessor.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPWaveBondingPreprocessor.h"
#import "TFPGCode.h"
#import "Extras.h"

/*
 static const double WAVE_PERIOD_LENGTH = 5;
 static const double WAVE_PERIOD_LENGTH_QUARTER = 1.25;
 static const double WAVE_SIZE = 0.15;
 static const double ENTIRE_Z_HEIGHT_OFFSET = -0.1;
 */

@interface TFPWaveBondingPreprocessor ()
@property double currentAdjustmentZ;
@end



@implementation TFPWaveBondingPreprocessor


- (TFPGCode *)processForTackPointsWithCurrentLine:(TFPGCode *)currLine previousLine:(TFPGCode *)prevLine lastTackPoint:(TFPGCode **)outLastTackPoint cornerCount:(int*)cornercount {
	TFPGCode *result;
	if (*cornercount <= 1) {
		if ([self isSharpCornerFromLine:currLine toLine:prevLine]) {
			if (!*outLastTackPoint) {
				result = [self makeTackPointForCurrentLine:currLine lastTackPoint:prevLine];
			}
			*outLastTackPoint = currLine;
			*cornercount = *cornercount + 1;
		}
		
	} else if (*cornercount >= 1 && [self isSharpCornerFromLine:currLine toLine:*outLastTackPoint]) {
		result = [self makeTackPointForCurrentLine:currLine lastTackPoint:*outLastTackPoint];
		*outLastTackPoint = currLine;
	}
	return result;
}


- (TFPGCodeProgram*)processUsingParameters:(TFPPrintParameters*)parameters {
	NSMutableArray *output = [NSMutableArray new];
	
	int baseLayer = 0;
	bool isRelative = true;
	bool firstLayer = true;
	bool flag3 = false;
	double num3 = 0;
	
	double relativeX = 0;
	double relativeY = 0;
	double relativeZ = 0;
	double relativeE = 0;
	
	double absoluteX = 0;
	double absoluteY = 0;
	double absoluteZ = 0;
	double absoluteE = 0;
	
	double F = 0;
	
	double num4 = num3;
	double num5 = 0;
	TFPGCode *previousCode = nil;
	TFPGCode *lastTackPoint = nil;
	int num6 = 0;
	
	/*
	 if (parameters.filamentType == TFPFilamentTypePLA) {
		double boundedTemp = [self boundedTemperature:parameters.idealTemperature + 10];
		double boundedTemp2 = [self boundedTemperature:parameters.idealTemperature + 5];
	 } else {
		double boundedTemp = [self boundedTemperature:parameters.idealTemperature + 15];
		double boundedTemp2 = [self boundedTemperature:parameters.idealTemperature + 10];
	 }
	 */
	
	for(__strong TFPGCode *code in self.program.lines) {
		if ([(code.comment ?: @"") rangeOfString:@"LAYER:"].location != NSNotFound) {
			int layerNumber = [code.comment substringFromIndex:6].intValue;
			if (layerNumber < baseLayer) {
				baseLayer = layerNumber;
			}
			firstLayer = (layerNumber == baseLayer);
		}
		
		NSInteger G = [code valueForField:'G' fallback:-1];
		if((G == 0 || G == 1) && !isRelative) {
			if([code hasField:'X'] || [code hasField:'Y']) {
				flag3 = YES;
			}
			
			if([code hasField:'Z'] && firstLayer) {
				code = [code codeByAdjustingField:'Z' offset:-0.1];
			}
			
			double deltaX = [code hasField:'X'] ? [code valueForField:'X'] - relativeX : 0; //num8
			double deltaY = [code hasField:'Y'] ? [code valueForField:'Y'] - relativeY : 0;
			double deltaZ = [code hasField:'Z'] ? [code valueForField:'Z'] - relativeZ : 0;
			double deltaE = [code hasField:'E'] ? [code valueForField:'E'] - relativeE : 0;
			
			absoluteX += deltaX;
			absoluteY += deltaY;
			absoluteZ += deltaZ;
			absoluteE += deltaE;
			
			relativeX += deltaX;
			relativeY += deltaY;
			relativeZ += deltaZ;
			relativeE += deltaE;
			
			if([code hasField:'F']) {
				F = [code valueForField:'F'];
			}
			
			double distance = sqrt(deltaX*deltaX + deltaY*deltaY); //num12
			int num13 = 1;
			if(distance < 1.25) {
				num13 = distance / 1.25;
			}
			
			//double num14 = absoluteX - deltaX;
			//double num15 = absoluteY - deltaY;
			double num16 = relativeX - deltaX;
			double num17 = relativeY - deltaY;
			double num18 = relativeZ - deltaZ;
			double num19 = relativeE - deltaE;
			double num20 = deltaX / distance;
			double num21 = deltaY / distance;
			double num22 = deltaZ / distance;
			double num23 = deltaE / distance;
			
			if(firstLayer && deltaE > 0) {
				if(previousCode) {
					TFPGCode *newCode = [self processForTackPointsWithCurrentLine:code previousLine:previousCode lastTackPoint:&lastTackPoint cornerCount:&num6];
					if(newCode) {
						[output addObject:newCode];
					}
				}
				
				for (int i = 1; i < num13 + 1; i++)
				{
					double num26;
					double num27;
					double num28;
					double num29;
					if (i == num13)
					{
						//double num24 = absoluteX;
						//double num25 = absoluteY;
						num26 = relativeX;
						num27 = relativeY;
						num28 = relativeZ;
						num29 = relativeE;
					}
					else
					{
						//double num24 = num14 + (double)i * 1.25 * num20;
						//double num25 = num15 + (double)i * 1.25 * num21;
						num26 = num16 + (double)i * 1.25 * num20;
						num27 = num17 + (double)i * 1.25 * num21;
						num28 = num18 + (double)i * 1.25 * num22;
						num29 = num19 + (double)i * 1.25 * num23;
					}
					//double num30 = num29 - num5;
					if (i != num13) {
						TFPGCode *newCode = [TFPGCode codeWithField:'G' value:G];
						
						if ([code hasField:'X']) {
							newCode = [newCode codeBySettingField:'X' toValue:relativeX - deltaX + (num26 - num16)];
						}
						
						if ([code hasField:'Y']) {
							newCode = [newCode codeBySettingField:'Y' toValue:relativeY - deltaY + (num27 - num17)];
						}
						
						if (flag3) {
							newCode = [newCode codeBySettingField:'Z' toValue:relativeZ - deltaZ + (num28 - num18 + self.currentAdjustmentZ)];
							
						} else if ([code hasField:'Z'] && (deltaZ > DBL_EPSILON || deltaZ < DBL_EPSILON)) {
							newCode = [newCode codeBySettingField:'Z' toValue:relativeZ - deltaZ + (num28 - num18)];
						}
						
						newCode = [newCode codeBySettingField:'E' toValue:relativeE - deltaE + (num29 - num19) + num4];
						[output addObject:newCode];
						
					} else {
						if (flag3) {
							if ([code hasField:'Z']) {
								code = [code codeByAdjustingField:'Z' offset:self.currentAdjustmentZ];
							} else {
								code = [code codeBySettingField:'Z' toValue:num18 + deltaZ + self.currentAdjustmentZ];
							}
						}
						code = [code codeByAdjustingField:'Z' offset:num4];
					}
					num5 = num29;
				}
			}
			previousCode = code;
			
		} else if (G == 92) {
			if(![code hasField:'X'] &&![code hasField:'Y'] &&![code hasField:'Z'] &&![code hasField:'E']) {
				code = [code codeBySettingField:'E' toValue:0];
				code = [code codeBySettingField:'Z' toValue:0];
				code = [code codeBySettingField:'Y' toValue:0];
				code = [code codeBySettingField:'X' toValue:0];
				
			} else {
				relativeX = [code valueForField:'X' fallback:relativeX];
				relativeY = [code valueForField:'Y' fallback:relativeY];
				relativeZ = [code valueForField:'Z' fallback:relativeZ];
				relativeE = [code valueForField:'E' fallback:relativeE];
			}
			
		} else if (G == 90) {
			isRelative = NO;
			
		} else if (G == 91) {
			isRelative = YES;
		}
		
		[output addObject:code];
	}
	
	return [[TFPGCodeProgram alloc] initWithLines:output];
}


@end