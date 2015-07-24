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
	__block double minX = 10000, maxX = 0;
	__block double minY = 10000, maxY = 0;
	__block double minZ = 10000, maxZ = 0;
	
	[self enumerateMovesWithBlock:^(TFPAbsolutePosition from, TFPAbsolutePosition to, double feedRate, TFPGCode *code, NSUInteger index) {
		if(to.e > from.e) {
			minX = MIN(MIN(minX, from.x), to.x);
			maxX = MAX(MAX(maxX, from.x), to.x);
			
			minY = MIN(MIN(minY, from.y), to.y);
			maxY = MAX(MAX(maxY, from.y), to.y);
			
			minZ = MIN(MIN(minZ, from.z), to.z);
			maxZ = MAX(MAX(maxZ, from.z), to.z);
			
		}
	}];
	
	return [TFP3DVector vectorWithX:@(maxX-minX) Y:@(maxY-minY) Z:@(maxZ-minZ)];
}


- (void)enumerateMovesWithBlock:(void(^)(TFPAbsolutePosition from, TFPAbsolutePosition to, double feedRate, TFPGCode *code, NSUInteger index))block {
	__block BOOL relativeMode = NO;
	__block TFPAbsolutePosition position = {0,0,0,0};
	__block double feedRate = 0;
	
	[self.lines enumerateObjectsUsingBlock:^(TFPGCode *code, NSUInteger index, BOOL *stop) {
		if(![code hasField:'G']) {
			return;
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
				
				block(previous, position, feedRate, code, index);
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
	}];
	
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


- (NSString*)curaProfileComment {
	for(TFPGCode *code in self.lines) {
		if([code.comment hasPrefix:@"CURA_PROFILE_STRING:"]) {
			return [code.comment substringFromIndex:20];
		}
	}
	return nil;
}


- (NSDictionary*)curaProfileValues {
	NSString *base64 = [self curaProfileComment];
	if(!base64) {
		return nil;
	}
	
	NSData *deflatedData = [[NSData alloc] initWithBase64EncodedString:base64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
	NSData *rawData = [deflatedData tf_dataByDecodingDeflate];
	
	if(!rawData) {
		return nil;
	}
	
	NSString *string = [[NSString alloc] initWithData:rawData encoding:NSUTF8StringEncoding];
	NSArray *pairs = [string componentsSeparatedByString:@"\x08"];
	NSMutableDictionary *profile = [NSMutableDictionary new];
	
	for(NSString *pairString in pairs) {
		NSUInteger separator = [pairString rangeOfString:@"="].location;
		if(separator == NSNotFound) {
			continue;
		}
		
		NSString *key = [pairString substringWithRange:NSMakeRange(0, separator)];
		NSString *value = [pairString substringWithRange:NSMakeRange(separator+1, pairString.length - separator - 1)];
		profile[key] = value;
	}
	
	return profile;
}



- (NSDictionary*)determinePhaseRanges {
	__block TFPPrintPhase phase = TFPPrintPhasePreamble;
	__block NSUInteger startLine = 0;
	NSMutableDictionary *phaseRanges = [NSMutableDictionary new];
	
	[self.lines enumerateObjectsUsingBlock:^(TFPGCode *code, NSUInteger index, BOOL *stop) {
		if(!code.comment) {
			return;
		}
		NSRange range = NSMakeRange(startLine, index-startLine);
		
		if([code.comment hasPrefix:@"LAYER:"]) {
			NSInteger layerIndex = [[code.comment substringFromIndex:6] integerValue];
			
			if(phase == TFPPrintPhasePreamble) {
				phaseRanges[@(TFPPrintPhasePreamble)] = [NSValue valueWithRange:range];
				
				if(layerIndex < 0) {
					phase = TFPPrintPhaseAdhesion;
				}else{
					phase = TFPPrintPhaseModel;
				}
				startLine = index;
			}else if(phase == TFPPrintPhaseAdhesion && layerIndex >= 0) {
				phaseRanges[@(TFPPrintPhaseAdhesion)] = [NSValue valueWithRange:range];
				phase = TFPPrintPhaseModel;
				startLine = index;
			}
		}else if([code.comment isEqual:@"POSTAMBLE"]) {
			phaseRanges[@(TFPPrintPhaseModel)] = [NSValue valueWithRange:range];
			phase = TFPPrintPhasePostamble;
			startLine = index;
		}else if([code.comment isEqual:@"END"]) {
			phaseRanges[@(TFPPrintPhasePostamble)] = [NSValue valueWithRange:range];
		}
	}];
	
	return phaseRanges;
}


@end