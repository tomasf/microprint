//
//  TFPBedCompensationPreprocessor.m
//  MicroPrint
//
//  Created by Tomas Franzén on Mon 2015-06-22.
//

#import "TFPBedCompensationPreprocessor.h"
#import "TFPGCode.h"


const double CHANGE_IN_HEIGHT_THAT_DOUBLES_EXTRUSION = 0.15;
const double LEVELLING_MOVE_X = 104.9;
const double LEVELLING_MOVE_Y = 103;
const double PROBE_Z_DISTANCE = 55;
const double segmentLength = 2;


static double GetHeightAdjustmentRequired(double x, double y, TFPBedLevelOffsets offsets) {
	double left = (offsets.backLeft - offsets.frontLeft) / LEVELLING_MOVE_Y;
	double right = (offsets.backRight - offsets.frontRight) / LEVELLING_MOVE_Y;
	double num3 = left * y + offsets.frontLeft;
	double num5 = (right * y + offsets.frontRight - num3) / LEVELLING_MOVE_X;
	return num5 * x + num3;
}


@interface TFPBedCompensationPreprocessor ()
@property BOOL firstLayerOnly; // Present in C# code; seemingly never set. Leave set to NO..?
@property BOOL changeExtrusionToCompensate;  // Present in C# code; seemingly never set. Leave set to NO..?

@property BOOL moveZToCompensate;
@end



@implementation TFPBedCompensationPreprocessor


- (instancetype)initWithProgram:(TFPGCodeProgram *)program {
	if(!(self = [super initWithProgram:program])) return nil;
	
	self.moveZToCompensate = YES;
	
	return self;
}


- (TFPGCodeProgram*)processUsingParameters:(TFPPrintParameters*)parameters {
	NSMutableArray *output = [NSMutableArray new];
	
	BOOL isRelative = YES;
	BOOL hasXorY = NO;
	BOOL isFirstLayer = NO;
	BOOL hasExtruded = NO;
	BOOL flag4 = NO;
	
	NSInteger layerNumber = 0;
	double num5 = 0;
	double num7 = 0;
	double num6 = num5;


	double relativeX = 0;
	double relativeY = 0;
	double relativeZ = 0;
	double relativeE = 0;
	
	double absoluteX = 0;
	double absoluteY = 0;
	double absoluteZ = 0;
	double absoluteE = 0;
	
	double F = 0;
	
	for(__strong TFPGCode *line in self.program.lines) {
		if([line hasField:'G']) {
			switch((int)[line valueForField:'G']) {
				case 0:
				case 1:
					if(isRelative) {
						break;
					}
					
					if([line hasField:'X'] || [line hasField:'Y']) {
						hasXorY = YES;
					}
					if([line hasField:'Z']) {
						double newZ = [line valueForField:'Z'] + parameters.bedLevelOffsets.common;
						line = [line codeBySettingField:'Z' toValue:newZ];
					}
					
					double deltaX = [line hasField:'X'] ? [line valueForField:'X'] - relativeX : 0;
					double deltaY = [line hasField:'Y'] ? [line valueForField:'Y'] - relativeY : 0;
					double deltaZ = [line hasField:'Z'] ? [line valueForField:'Z'] - relativeZ : 0;
					double deltaE = [line hasField:'E'] ? [line valueForField:'E'] - relativeE : 0;
					
					absoluteX += deltaX;
					absoluteY += deltaY;
					absoluteZ += deltaZ;
					absoluteE += deltaE;
					
					relativeX += deltaX;
					relativeY += deltaY;
					relativeZ += deltaZ;
					relativeE += deltaE;
					
					if([line hasField:'F']) {
						F = [line valueForField:'F'];
					}
					
					if(deltaZ > DBL_EPSILON || deltaZ < -DBL_EPSILON) {
						if(!hasExtruded) {
							layerNumber = 1;
						}else{
							layerNumber++;
						}
						isFirstLayer = (layerNumber == 0) || (layerNumber == 1);
					}
					
					double length = sqrt(pow(deltaX, 2) + pow(deltaY, 2));
					
					NSUInteger segmentCount = 1;
					if(length > segmentLength) {
						segmentCount = length / segmentLength;
					}
					
					double num14 = absoluteX - deltaX;
					double num15 = absoluteY - deltaY;
					double num16 = relativeX - deltaX;
					double num17 = relativeY - deltaY;
					double num18 = relativeZ - deltaZ;
					double num19 = relativeE - deltaE;
					double num20 = deltaX / length;
					double num21 = deltaY / length;
					double num22 = deltaZ / length;
					double num23 = deltaE / length;
					
					if (deltaE > 0) {
						flag4 = !hasExtruded;
						hasExtruded = true;
					}
					if (flag4) {
						//[output addObject:[[TFPGCode codeWithString:@"G0"] codeBySettingField:'E' toValue:num5]];
					}
					
					
					if ((isFirstLayer || !self.firstLayerOnly) && deltaE > 0) {
						for (int i = 1; i < segmentCount + 1; i++) {
							float x;
							float y;
							float num24;
							float num25;
							float num26;
							float num27;
							if (i == segmentCount) {
								x = absoluteX;
								y = absoluteY;
								num24 = relativeX;
								num25 = relativeY;
								num26 = relativeZ;
								num27 = relativeE;
								
							} else {
								x = num14 + (float)i * segmentLength * num20;
								y = num15 + (float)i * segmentLength * num21;
								num24 = num16 + (float)i * segmentLength * num20;
								num25 = num17 + (float)i * segmentLength * num21;
								num26 = num18 + (float)i * segmentLength * num22;
								num27 = num19 + (float)i * segmentLength * num23;
							}
							float num28 = num27 - num7;
							float heightAdjustmentRequired = GetHeightAdjustmentRequired(x, y, parameters.bedLevelOffsets);
							float num29 = -heightAdjustmentRequired / CHANGE_IN_HEIGHT_THAT_DOUBLES_EXTRUSION * num28;
							if (self.changeExtrusionToCompensate) {
								num6 += num29;
							}
							float num30 = heightAdjustmentRequired;
							if (i != segmentCount) {
								
								TFPGCode *code = [TFPGCode codeWithField:'G' value:[line valueForField:'G']];
								
								if ([line hasField:'X']) {
									code = [code codeBySettingField:'X' toValue:relativeX - deltaX + (num24-num16)];
								}
								
								if ([line hasField:'Y']) {
									code = [code codeBySettingField:'Y' toValue:relativeY - deltaY + (num25 - num17)];
								}
								
								if ([line hasField:'F'] && i == 1) {
									code = [code codeBySettingField:'F' toValue:[line valueForField:'F']];
								}

								if (self.moveZToCompensate && hasXorY) {
									code = [code codeBySettingField:'Z' toValue:relativeZ - deltaZ + (num26 - num18) + num30];

								} else if([line hasField:'Z'] && (deltaZ > DBL_EPSILON || deltaZ < -DBL_EPSILON)) {
									code = [code codeBySettingField:'Z' toValue:relativeZ - deltaZ + (num26 - num18)];
								}
								
								code = [code codeBySettingField:'E' toValue:relativeE - deltaE + (num27 - num19) + num6];
								[output addObject:code];
								
							} else {
								if (self.moveZToCompensate && hasXorY) {
									if ([line hasField:'Z']) {
										line = [line codeByAdjustingField:'Z' offset:num30];
									} else {
										line = [line codeBySettingField:'Z' toValue:num18 + deltaZ + num30];
									}
								}
								line = [line codeByAdjustingField:'E' offset:num6];
							}
							num7 = num27;
						}
						
					} else {
						if (self.moveZToCompensate && hasXorY && (isFirstLayer || !self.firstLayerOnly)) {
							TFPBedLevelOffsets offsets = parameters.bedLevelOffsets;
							double num31 = (offsets.backLeft - offsets.frontLeft) / LEVELLING_MOVE_Y;
							double num32 = (offsets.backRight - offsets.frontRight) / LEVELLING_MOVE_Y;
							double num33 = num31 * absoluteY + offsets.frontLeft;
							double num34 = num32 * absoluteY + offsets.frontRight;
							double num35 = (num34 - num33) / LEVELLING_MOVE_X;
							double num36 = num35 * absoluteX + num33;
							double num30 = num36;
							
							if ([line hasField:'Z']) {
								line = [line codeByAdjustingField:'Z' offset:num30];
							} else {
								line = [line codeBySettingField:'Z' toValue:relativeZ + num30];
							}
						}
						if ([line hasField:'E'])
						{
							line = [line codeByAdjustingField:'E' offset:num6];
						}
						num7 = relativeE;
					}
					
					break;
					
				case 92:
					if(![line hasField:'X'] &&![line hasField:'Y'] &&![line hasField:'Z'] &&![line hasField:'E']) {
						line = [line codeBySettingField:'E' toValue:0];
						line = [line codeBySettingField:'Z' toValue:0];
						line = [line codeBySettingField:'Y' toValue:0];
						line = [line codeBySettingField:'X' toValue:0];
						
					} else {
						relativeX = [line valueForField:'X' fallback:relativeX];
						relativeY = [line valueForField:'Y' fallback:relativeY];
						relativeZ = [line valueForField:'Z' fallback:relativeZ];
						relativeE = [line valueForField:'E' fallback:relativeE];
					}
					break;
					
				case 90:
					isRelative = NO;
					break;
					
				case 91:
					isRelative = YES;
					break;
			}
			
		}
		
		[output addObject:line];
	}
	
	return [[TFPGCodeProgram alloc] initWithLines:output];
}


@end