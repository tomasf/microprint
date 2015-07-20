//
//  TFPManualBedLevelCalibration.h
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-07-12.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPOperation.h"

typedef NS_ENUM(NSUInteger, TFPBedLevelCalibrationCorner) {
	TFPBedLevelCalibrationCornerBackLeft,
	TFPBedLevelCalibrationCornerBackRight,
	TFPBedLevelCalibrationCornerBackFrontRight,
	TFPBedLevelCalibrationCornerBackFrontLeft,
};


@interface TFPBedLevelCalibration : TFPOperation
- (void)startAtLevel:(double)startZ heightTarget:(double)heightTarget;

- (void)adjustUp;
- (void)adjustDown;
@property (readonly) double currentLevel;

- (void)continue;

- (void)stop;

@property (copy) void(^didStartMovingHandler)();
@property (copy) void(^didStopAtCornerHandler)(TFPBedLevelCalibrationCorner corner);
@property (copy) void(^didFinishHandler)();
@end