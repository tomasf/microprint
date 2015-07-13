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




+ (instancetype)moveToOriginCode {
	return [self codeWithString:@"G28"];
}


+ (instancetype)turnOffMotorsCode {
	return [self codeWithString:@"M18"];
}



+ (instancetype)moveWithPosition:(TFP3DVector*)position withFeedRate:(double)F {
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
		code = [code codeBySettingField:'F' toValue:[self convertFeedRate:F]];
	}
	
	return code;
}


+ (instancetype)absoluteModeCode{
	return [self codeWithString:@"G90"];
}


+ (instancetype)relativeModeCode {
	return [self codeWithString:@"G91"];
}

@end
