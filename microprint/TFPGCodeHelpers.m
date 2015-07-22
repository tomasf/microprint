//
//  TFPGCodeHelpers.m
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-07-13.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPGCodeHelpers.h"
#import "Extras.h"


@implementation TFPGCode (TFPHelpers)


const double maxMMPerSecond = 60.001;

+ (double)convertFeedRate:(double)feedRate {
	feedRate /= 60;
	feedRate = MIN(feedRate, maxMMPerSecond);
	
	double factor = feedRate / maxMMPerSecond;
	feedRate = 30 + (1 - factor) * 800;
	return feedRate;
}


+ (NSDictionary*)dictionaryFromResponseValueString:(NSString*)string {
	NSMutableDictionary *dictionary = [NSMutableDictionary new];
	NSArray *parts = [string componentsSeparatedByString:@" "];
	
	for(NSString *part in parts) {
		NSUInteger colonIndex = [part rangeOfString:@":"].location;
		if(colonIndex != NSNotFound) {
			NSString *key = [part substringToIndex:colonIndex];
			NSString *value = [part substringFromIndex:colonIndex+1];
			dictionary[key] = value;
		}
	}
	return dictionary;
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
	return [self moveWithPosition:position extrusion:nil withRawFeedRate:F];
}


+ (instancetype)moveWithPosition:(TFP3DVector*)position extrusion:(NSNumber*)E withRawFeedRate:(double)F {
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
	if(E) {
		code = [code codeBySettingField:'E' toValue:E.doubleValue];
	}
	if(F >= 0) {
		code = [code codeBySettingField:'F' toValue:F];
	}
	
	return code;
}


+ (instancetype)moveWithPosition:(TFP3DVector*)position withFeedRate:(double)F {
	F = (F > 0) ? [self convertFeedRate:F] : F;
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


+ (instancetype)turnOnFanCode {
	return [TFPGCode codeWithField:'M' value:106];
}


+ (instancetype)turnOffFanCode {
	return [TFPGCode codeWithField:'M' value:107];
}


+ (instancetype)stopCode {
	return [TFPGCode codeWithField:'M' value:0];
}


+ (instancetype)codeForResettingPosition:(TFP3DVector*)position extrusion:(NSNumber*)E {
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
	return [self codeForResettingPosition:nil extrusion:@0];
}


+ (instancetype)codeForSettingFeedRate:(double)feedRate raw:(BOOL)raw {
	if(!raw) {
		feedRate = [self convertFeedRate:feedRate];
	}
	return [[TFPGCode codeWithField:'G' value:0] codeBySettingField:'F' toValue:feedRate];
}


+ (instancetype)codeForReadingVirtualEEPROMAtIndex:(NSUInteger)valueIndex {
	return [[TFPGCode codeWithField:'M' value:619] codeBySettingField:'S' toValue:valueIndex];
}


+ (instancetype)codeForWritingVirtualEEPROMAtIndex:(NSUInteger)valueIndex value:(int32_t)value {
	return [[[TFPGCode codeWithField:'M' value:618] codeBySettingField:'S' toValue:valueIndex] codeBySettingField:'P' toValue:value];
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


// These values only need to contain codes relevant for printing


+ (NSIndexSet*)validM3DGValues {
	return [NSIndexSet tf_indexSetWithIndexes:0, 1, 4, 28, 90, 91, 92,  30, 32, 33, -1];
}


+ (NSIndexSet*)validM3DMValues {
	return [NSIndexSet tf_indexSetWithIndexes:0, 1, 17, 18, 104, 105, 106, 107, 108, 109, 110, 114, 115, 117, -1];
}


- (BOOL)validateForM3D:(NSError**)outError {
	NSIndexSet *Gset = [self.class validM3DGValues];
	NSIndexSet *Mset = [self.class validM3DMValues];
	__block BOOL valid = YES;
	__block NSError *error;
	
	[self.lines enumerateObjectsUsingBlock:^(TFPGCode *code, NSUInteger index, BOOL *stop) {
		if(code.hasFields) {
			NSInteger G = [code valueForField:'G' fallback:-1];
			NSInteger M = [code valueForField:'M' fallback:-1];
			
			if((G > -1 && ![Gset containsIndex:G]) || (M > -1 && ![Mset containsIndex:M])) {
				NSString *errorString = [NSString stringWithFormat:@"File contains G-code that is incompatible with the M3D Micro at line %d:\n%@", (int)index+1, code];
					
				error = [NSError errorWithDomain:TFPErrorDomain code:TFPErrorCodeIncompatibleCode userInfo:@{NSLocalizedRecoverySuggestionErrorKey: errorString, TFPErrorGCodeKey: code, TFPErrorGCodeLineKey: @(index+1)}];
				
				valid = NO;
			}
		}
	}];
	
	if(!valid && outError) {
		*outError = error;
	}
	
	return valid;
}


@end