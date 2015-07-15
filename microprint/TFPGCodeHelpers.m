//
//  TFPGCodeHelpers.m
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-07-13.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPGCodeHelpers.h"


@implementation TFPGCode (TFPHelpers)


const double maxMMPerSecond = 60.001;

+ (double)convertFeedRate:(double)feedRate {
	feedRate /= 60;
	feedRate = MIN(feedRate, maxMMPerSecond);
	
	double factor = feedRate / maxMMPerSecond;
	feedRate = 30 + (1 - factor) * 800;
	return feedRate;
}


- (instancetype)codeBySettingLineNumber:(uint16_t)lineNumber {
	return [self codeBySettingField:'N' toValue:lineNumber];
}


+ (instancetype)codeForSettingLineNumber:(uint16_t)lineNumber {
	return [[self codeWithField:'M' value:110] codeBySettingLineNumber:lineNumber];
}


+ (instancetype)moveHomeCode {
	return [self codeWithString:@"G28"];
}


+ (instancetype)turnOffMotorsCode {
	return [self codeWithString:@"M18"];
}


+ (instancetype)turnOnMotorsCode {
	return [self codeWithString:@"M17"];
}


+ (instancetype)waitCodeWithDuration:(NSUInteger)seconds {
	return [[TFPGCode codeWithField:'G' value:4] codeBySettingField:'S' toValue:seconds];
}


+ (instancetype)moveWithPosition:(TFP3DVector*)position withRawFeedRate:(double)F {
	TFPGCode *code = [TFPGCode codeWithString:@"G0"];
	
	if(position.x) {
		code = [code codeBySettingField:'X' toValue:position.x.doubleValue];
	}
	if(position.y) {
		code = [code codeBySettingField:'Y' toValue:position.y.doubleValue];
	}
	if(position.z) {
		code = [code codeBySettingField:'Z' toValue:position.z.doubleValue];
	}
	if(F >= 0) {
		code = [code codeBySettingField:'F' toValue:F];
	}
	
	return code;
}


+ (instancetype)moveWithPosition:(TFP3DVector*)position withFeedRate:(double)F {
	F = (F > 0) ? [self convertFeedRate:F] : 0;
	return [self moveWithPosition:position withRawFeedRate:F];
}


+ (instancetype)absoluteModeCode{
	return [self codeWithString:@"G90"];
}


+ (instancetype)relativeModeCode {
	return [self codeWithString:@"G91"];
}



+ (instancetype)codeForHeaterTemperature:(double)temperature waitUntilDone:(BOOL)wait {
	return [[TFPGCode codeWithField:'M' value:(wait ? 109 : 104)] codeBySettingField:'S' toValue:temperature];
}


+ (instancetype)codeForTurningOffHeater {
	return [self codeForHeaterTemperature:0 waitUntilDone:NO];
}


+ (instancetype)codeForExtrusion:(double)E withRawFeedRate:(double)feedRate {
	TFPGCode *code = [[TFPGCode codeWithField:'G' value:0] codeBySettingField:'E' toValue:E];
	if(feedRate > 0) {
		code = [code codeBySettingField:'F' toValue:feedRate];
	}
	return code;
}


+ (instancetype)codeForExtrusion:(double)E withFeedRate:(double)feedRate {
	feedRate = (feedRate > 0) ? [self convertFeedRate:feedRate] : 0;
	return [self codeForExtrusion:E withRawFeedRate:feedRate];
}


+ (instancetype)codeForSettingFanSpeed:(double)speed {
	return [[TFPGCode codeWithField:'M' value:106] codeBySettingField:'S' toValue:speed];
}


+ (instancetype)turnOffFanCode {
	return [TFPGCode codeWithField:'M' value:107];
}


+ (instancetype)stopCode {
	return [TFPGCode codeWithField:'M' value:0];
}


+ (instancetype)codeForSettingPosition:(TFP3DVector*)position E:(NSNumber*)E {
	TFPGCode *code = [TFPGCode codeWithString:@"G92"];
	
	if(position.x) {
		code = [code codeBySettingField:'X' toValue:position.x.doubleValue];
	}
	if(position.y) {
		code = [code codeBySettingField:'Y' toValue:position.y.doubleValue];
	}
	if(position.z) {
		code = [code codeBySettingField:'Z' toValue:position.z.doubleValue];
	}
	if(E) {
		code = [code codeBySettingField:'E' toValue:E.doubleValue];
	}
	
	return code;
}


+ (instancetype)resetExtrusionCode {
	return [self codeForSettingPosition:nil E:@0];
}


+ (instancetype)codeForSettingFeedRate:(double)feedRate raw:(BOOL)raw {
	if(!raw) {
		feedRate = [self convertFeedRate:feedRate];
	}
	return [[TFPGCode codeWithField:'G' value:0] codeBySettingField:'F' toValue:feedRate];
}


@end



@implementation TFPGCodeProgram (TFPHelpers)


- (TFP3DVector*)measureSize {
	double minX = 10000, maxX = 0;
	double minY = 10000, maxY = 0;
	double minZ = 10000, maxZ = 0;
	
	BOOL relativeMode = NO;
	double X=0, Y=0, Z=0, E=0;
	
	for(TFPGCode *code in self.lines) {
		if(![code hasField:'G']) {
			continue;
		}
		
		switch ((int)[code valueForField:'G']) {
			case 0:
			case 1: {
				BOOL extruding = [code hasField:'E'] && !isnan([code valueForField:'E']);
				BOOL positiveExtrusion = NO;
				if(extruding) {
					double thisE = [code valueForField:'E'];
					if(relativeMode) {
						positiveExtrusion = (thisE > 0);
						E += thisE;
					}else{
						positiveExtrusion = (thisE > E);
						E = thisE;
					}
				}
				
				if(positiveExtrusion) {
					minX = MIN(minX, X);
					maxX = MAX(maxX, X);
					minY = MIN(minY, Y);
					maxY = MAX(maxY, Y);
					minZ = MIN(minZ, Z);
					maxZ = MAX(maxZ, Z);
				}
				
				if([code hasField:'X']) {
					double thisX = [code valueForField:'X'];
					if(relativeMode) {
						X += thisX;
					}else{
						X = thisX;
					}
				}
				
				if([code hasField:'Y']) {
					double thisY = [code valueForField:'Y'];
					if(relativeMode) {
						Y += thisY;
					}else{
						Y = thisY;
					}
				}
				
				if([code hasField:'Z']) {
					double thisZ = [code valueForField:'Z'];
					if(relativeMode) {
						Z += thisZ;
					}else{
						Z = thisZ;
					}
				}
				
				if(positiveExtrusion) {
					minX = MIN(minX, X);
					maxX = MAX(maxX, X);
					minY = MIN(minY, Y);
					maxY = MAX(maxY, Y);
					minZ = MIN(minZ, Z);
					maxZ = MAX(maxZ, Z);
				}
				
				break;
			}
    
			case 90:
				relativeMode = NO;
				break;
				
			case 91:
				relativeMode = YES;
				break;
				
			case 92:
				break;
		}
	}
	
	return [TFP3DVector vectorWithX:@(maxX-minX) Y:@(maxY-minY) Z:@(maxZ-minZ)];
}


- (void)enumerateMovesWithBlock:(void(^)(TFPAbsolutePosition from, TFPAbsolutePosition to, double feedRate))block {
	BOOL relativeMode = NO;
	TFPAbsolutePosition position = {0,0,0,0};
	double feedRate = 0;
	
	for(TFPGCode *code in self.lines) {
		if(![code hasField:'G']) {
			continue;
		}
		
		switch ((int)[code valueForField:'G']) {
			case 0:
			case 1: {
				BOOL extruding = [code hasField:'E'] && !isnan([code valueForField:'E']);
				TFPAbsolutePosition previous = position;
				
				if([code hasField:'F']) {
					feedRate = [code valueForField:'F'];
				}
				
				if(extruding) {
					double thisE = [code valueForField:'E'];
					if(relativeMode) {
						position.e += thisE;
					}else{
						position.e = thisE;
					}
				}
				
				if([code hasField:'X']) {
					double thisX = [code valueForField:'X'];
					if(relativeMode) {
						position.x += thisX;
					}else{
						position.x = thisX;
					}
				}
				
				if([code hasField:'Y']) {
					double thisY = [code valueForField:'Y'];
					if(relativeMode) {
						position.y += thisY;
					}else{
						position.y = thisY;
					}
				}
				
				if([code hasField:'Z']) {
					double thisZ = [code valueForField:'Z'];
					if(relativeMode) {
						position.z += thisZ;
					}else{
						position.z = thisZ;
					}
				}
				
				block(previous, position, feedRate);
				break;
			}
    
			case 90:
				relativeMode = NO;
				break;
				
			case 91:
				relativeMode = YES;
				break;
				
			case 92:
				break;
		}
	}
	
}


@end