//
//  TFPWaveBondingPreprocessor.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPWaveBondingPreprocessor.h"
#import "TFPGCode.h"
#import "TFPExtras.h"

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
			return result;
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
	bool movesInXorY = false;
	double num3 = 0;
	
	double relativeX = 0;
	double relativeY = 0;
	double relativeZ = 0;
	double relativeE = 0;
	
	double num4 = num3;
	TFPGCode *previousCode = nil;
	TFPGCode *lastTackPoint = nil;
	int num6 = 0;
	
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
				movesInXorY = YES;
			}
			
			if([code hasField:'Z'] && firstLayer) {
				code = [code codeByAdjustingField:'Z' offset:-0.1];
			}
			
			double deltaX = [code hasField:'X'] ? [code valueForField:'X'] - relativeX : 0; //num8
			double deltaY = [code hasField:'Y'] ? [code valueForField:'Y'] - relativeY : 0;
			double deltaZ = [code hasField:'Z'] ? [code valueForField:'Z'] - relativeZ : 0;
			double deltaE = [code hasField:'E'] ? [code valueForField:'E'] - relativeE : 0;
			
			relativeX += deltaX;
			relativeY += deltaY;
			relativeZ += deltaZ;
			relativeE += deltaE;
			
			const double segmentLength = 1.25;
			double moveDistance = sqrt(deltaX*deltaX + deltaY*deltaY); //num12
			int segmentCount = MAX(1, moveDistance / segmentLength);
			
			double previousX = relativeX - deltaX;
			double previousY = relativeY - deltaY;
			double previousZ = relativeZ - deltaZ;
			double previousE = relativeE - deltaE;
			double stepX = deltaX / moveDistance;
			double stepY = deltaY / moveDistance;
			double stepZ = deltaZ / moveDistance;
			double stepE = deltaE / moveDistance;
			
			if(firstLayer && deltaE > 0) {
				if(previousCode) {
					TFPGCode *newCode = [self processForTackPointsWithCurrentLine:code previousLine:previousCode lastTackPoint:&lastTackPoint cornerCount:&num6];
					if(newCode) {
						[output addObject:newCode];
					}
				}
				
				for (int segment = 1; segment < segmentCount+1; segment++) {
					double num26;
					double num27;
					double num28;
					double num29;
					
					if (segment == segmentCount) {
						num26 = relativeX;
						num27 = relativeY;
						num28 = relativeZ;
						num29 = relativeE;
					} else {
						num26 = previousX + (double)segment * segmentLength * stepX;
						num27 = previousY + (double)segment * segmentLength * stepY;
						num28 = previousZ + (double)segment * segmentLength * stepZ;
						num29 = previousE + (double)segment * segmentLength * stepE;
					}

					if (segment != segmentCount) {
						TFPGCode *newCode = [TFPGCode codeWithField:'G' value:G];
						
						if ([code hasField:'X']) {
							newCode = [newCode codeBySettingField:'X' toValue:relativeX - deltaX + (num26 - previousX)];
						}
						
						if ([code hasField:'Y']) {
							newCode = [newCode codeBySettingField:'Y' toValue:relativeY - deltaY + (num27 - previousY)];
						}
						
						if ([code hasField:'F'] && segment == 1) {
							newCode = [newCode codeBySettingField:'F' toValue:[code valueForField:'F']];
						}
						
						if (movesInXorY) {
							newCode = [newCode codeBySettingField:'Z' toValue:relativeZ - deltaZ + (num28 - previousZ + self.currentAdjustmentZ)];
							
						} else if ([code hasField:'Z'] && (deltaZ > DBL_EPSILON || deltaZ < DBL_EPSILON)) {
							newCode = [newCode codeBySettingField:'Z' toValue:relativeZ - deltaZ + (num28 - previousZ)];
						}
						
						newCode = [newCode codeBySettingField:'E' toValue:relativeE - deltaE + (num29 - previousE) + num4];
						[output addObject:newCode];
						
					} else {
						if (movesInXorY) {
							if ([code hasField:'Z']) {
								code = [code codeByAdjustingField:'Z' offset:self.currentAdjustmentZ];
							} else {
								code = [code codeBySettingField:'Z' toValue:previousZ + deltaZ + self.currentAdjustmentZ];
							}
						}
						code = [code codeByAdjustingField:'Z' offset:num4];
					}
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