//
//  TFPPrinterHelpers.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-08-02.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrinterHelpers.h"
#import "TFPPrinter+VirtualEEPROM.h"


@implementation TFPPrinter (CommandHelpers)


- (void)fetchBedOffsetsWithCompletionHandler:(void(^)(BOOL success, TFPBedLevelOffsets offsets))completionHandler {
	NSArray *indexes = @[@(VirtualEEPROMIndexBedOffsetBackLeft),
						 @(VirtualEEPROMIndexBedOffsetBackRight),
						 @(VirtualEEPROMIndexBedOffsetFrontRight),
						 @(VirtualEEPROMIndexBedOffsetFrontLeft),
						 @(VirtualEEPROMIndexBedOffsetCommon)];
	
	[self readVirtualEEPROMFloatValuesAtIndexes:indexes completionHandler:^(BOOL success, NSArray *values) {
		TFPBedLevelOffsets offsets;
		
		if(!success) {
			completionHandler(NO, offsets);
		}
		
		offsets.backLeft = [values[0] floatValue];
		offsets.backRight = [values[1] floatValue];
		offsets.frontRight = [values[2] floatValue];
		offsets.frontLeft = [values[3] floatValue];
		offsets.common = [values[4] floatValue];
		
		completionHandler(YES, offsets);
	}];
}


- (void)setBedOffsets:(TFPBedLevelOffsets)offsets completionHandler:(void(^)(BOOL success))completionHandler {
	NSDictionary *EEPROMValues = @{
								   @(VirtualEEPROMIndexBedOffsetBackLeft): @(offsets.backLeft),
								   @(VirtualEEPROMIndexBedOffsetBackRight): @(offsets.backRight),
								   @(VirtualEEPROMIndexBedOffsetFrontRight): @(offsets.frontRight),
								   @(VirtualEEPROMIndexBedOffsetFrontLeft): @(offsets.frontLeft),
								   @(VirtualEEPROMIndexBedOffsetCommon): @(offsets.common),
								   };
	
	
	[self writeVirtualEEPROMFloatValues:EEPROMValues completionHandler:^(BOOL success) {
		if(completionHandler) {
			completionHandler(success);
		}
	}];
}


- (void)fetchBacklashValuesWithCompletionHandler:(void(^)(BOOL success, TFPBacklashValues values))completionHandler {
	NSArray *indexes = @[@(VirtualEEPROMIndexBacklashCompensationX),
						 @(VirtualEEPROMIndexBacklashCompensationY),
						 @(VirtualEEPROMIndexBacklashCompensationSpeed)
						 ];
	
	[self readVirtualEEPROMFloatValuesAtIndexes:indexes completionHandler:^(BOOL success, NSArray *values) {
		TFPBacklashValues backlash;
		if(success) {
			backlash.x = [values[0] floatValue];
			backlash.y = [values[1] floatValue];
			backlash.speed = [values[2] floatValue];
			
			completionHandler(YES, backlash);
		}else{
			completionHandler(NO, backlash);
		}
	}];
}


- (void)setBacklashValues:(TFPBacklashValues)values completionHandler:(void(^)(BOOL success))completionHandler {
	NSDictionary *EEPROMValues = @{
								   @(VirtualEEPROMIndexBacklashCompensationX): @(values.x),
								   @(VirtualEEPROMIndexBacklashCompensationY): @(values.y),
								   @(VirtualEEPROMIndexBacklashCompensationSpeed): @(values.speed),
								   };
	
	[self writeVirtualEEPROMFloatValues:EEPROMValues completionHandler:^(BOOL success) {
		if(completionHandler) {
			completionHandler(success);
		}
	}];
}



- (void)fetchPositionWithCompletionHandler:(void(^)(BOOL success, TFP3DVector *position, NSNumber *E))completionHandler {
	[self sendGCode:[TFPGCode codeForGettingPosition] responseHandler:^(BOOL success, NSDictionary *params) {
		if(success) {
			NSNumber *x = params[@"X"] ? @([params[@"X"] doubleValue]) : nil;
			NSNumber *y = params[@"Y"] ? @([params[@"Y"] doubleValue]) : nil;
			NSNumber *z = params[@"Z"] ? @([params[@"Z"] doubleValue]) : nil;
			NSNumber *e = params[@"E"] ? @([params[@"E"] doubleValue]) : nil;
			
			TFP3DVector *position = [TFP3DVector vectorWithX:x Y:y Z:z];
			completionHandler(YES, position, e);
			
		}else{
			completionHandler(NO, nil, 0);
		}
	}];
}


- (void)fillInOffsetAndBacklashValuesInPrintParameters:(TFPPrintParameters*)params completionHandler:(void(^)(BOOL success))completionHandler {
	[self fetchBedOffsetsWithCompletionHandler:^(BOOL success, TFPBedLevelOffsets offsets) {
		if(!success) {
			completionHandler(NO);
			return;
		}
		
		params.bedLevelOffsets = offsets;
		[self fetchBacklashValuesWithCompletionHandler:^(BOOL success, TFPBacklashValues values) {
			if(!success) {
				completionHandler(NO);
				return;
			}
			params.backlashValues = values;
			completionHandler(YES);
		}];
	}];
}


- (void)setRelativeMode:(BOOL)relative completionHandler:(void(^)(BOOL success))completionHandler {
	if(relative) {
		[self sendGCode:[TFPGCode relativeModeCode] responseHandler:^(BOOL success, NSDictionary *value) {
			completionHandler(success);
		}];
	}else{
		[self sendGCode:[TFPGCode absoluteModeCode] responseHandler:^(BOOL success, NSDictionary *value) {
			completionHandler(success);
		}];
	}
}


- (void)moveToPosition:(TFP3DVector*)position usingFeedRate:(double)F completionHandler:(void(^)(BOOL success))completionHandler {
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
	
	[self sendGCode:code responseHandler:^(BOOL success, NSDictionary *value) {
		if(completionHandler) {
			completionHandler(success);
		}
	}];
}


- (void)waitForMoveCompletionWithHandler:(void(^)())completionHandler {
	[self sendGCode:[TFPGCode waitForMoveCompletionCode] responseHandler:^(BOOL success, NSDictionary *value) {
		if(completionHandler) {
			completionHandler();
		}
	}];
}


@end