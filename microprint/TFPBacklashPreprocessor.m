//
//  TFPBacklashPreprocessor.m
//  MicroPrint
//
//  Created by Tomas Franzén on Wed 2015-06-24.
//

#import "TFPBacklashPreprocessor.h"
#import "TFPGCode.h"


typedef NS_ENUM(NSUInteger, Direction) {
	DirectionPositive,
	DirectionNegative,
	DirectionNeither,
};


@implementation TFPBacklashPreprocessor


- (TFPGCodeProgram*)processUsingParameters:(TFPPrintParameters*)parameters {
	NSMutableArray *output = [NSMutableArray new];
	
	double backlashX = parameters.backlashValues.x;
	double backlashY = parameters.backlashValues.y;

	BOOL relativeMode = true;
	BOOL didAddAdjustmentCode = false;
	
	double X = 0;
	double Y = 0;
	double Z = 0;
	double E = 0;
	double F = 0;

	double xAdjustment = 0;
	double yAdjustment = 0;
	
	Direction lastXDirection = DirectionNeither;
	Direction lastYDirection = DirectionNeither;
	
	
	for(__strong TFPGCode *code in self.program.lines) {
		NSInteger G = [code valueForField:'G' fallback:-1];
		
		if ((G == 0 || G == 1) && !relativeMode) {
			double deltaX = [code hasField:'X'] ? [code valueForField:'X'] - X : 0;
			double deltaY = [code hasField:'Y'] ? [code valueForField:'Y'] - Y : 0;
			double deltaZ = [code hasField:'Z'] ? [code valueForField:'Z'] - Z : 0;
			double deltaE = [code hasField:'E'] ? [code valueForField:'E'] - E : 0;

			Direction xDirection;
			if (deltaX > DBL_EPSILON) {
				xDirection = DirectionPositive;
			} else if (deltaX < -DBL_EPSILON) {
				xDirection = DirectionNegative;
			} else {
				xDirection = lastXDirection;
			}
			
			Direction yDirection;
			if (deltaY > DBL_EPSILON) {
				yDirection = DirectionPositive;
			} else if (deltaY < -DBL_EPSILON) {
				yDirection = DirectionNegative;
			} else {
				yDirection = lastYDirection;
			}
			
			
			if ((xDirection != lastXDirection && lastXDirection != DirectionNeither) ||
				(yDirection != lastYDirection && lastYDirection != DirectionNeither))
			{
				TFPGCode *adjustmentCode = [TFPGCode codeWithField:'G' value:G];

				if (xDirection != lastXDirection && lastXDirection != DirectionNeither)
				{
					xAdjustment += (xDirection == DirectionPositive) ? backlashX : -backlashX;
					adjustmentCode = [adjustmentCode codeBySettingField:'X' toValue:X + xAdjustment];
				}
				if (yDirection != lastYDirection && lastYDirection != DirectionNeither)
				{
					yAdjustment += (yDirection == DirectionPositive) ? backlashY : -backlashY;
					adjustmentCode = [adjustmentCode codeBySettingField:'Y' toValue:Y + yAdjustment];
				}
				adjustmentCode = [adjustmentCode codeBySettingField:'F' toValue:parameters.backlashCompensationSpeed];
				didAddAdjustmentCode = true;
				[output addObject:adjustmentCode];
			}
			
			if ([code hasField:'X']) {
				code = [code codeByAdjustingField:'X' offset:xAdjustment];
			}
			if ([code hasField:'Y']) {
				code = [code codeByAdjustingField:'Y' offset:yAdjustment];
			}
			
			X += deltaX;
			Y += deltaY;
			Z += deltaZ;
			E += deltaE;
			
			if ([code hasField:'F']) {
				F = [code valueForField:'F'];
			}
			
			lastXDirection = xDirection;
			lastYDirection = yDirection;
			
		} else if (G == 92) {
			
			if(![code hasField:'X'] &&![code hasField:'Y'] &&![code hasField:'Z'] &&![code hasField:'E']) {
				code = [code codeBySettingField:'E' toValue:0];
				code = [code codeBySettingField:'Z' toValue:0];
				code = [code codeBySettingField:'Y' toValue:0];
				code = [code codeBySettingField:'X' toValue:0];
				
			} else {
				X = [code valueForField:'X' fallback:X];
				Y = [code valueForField:'Y' fallback:Y];
				Z = [code valueForField:'Z' fallback:Z];
				E = [code valueForField:'E' fallback:E];
			}
			
		} else if (G == 90) {
			relativeMode = false;
			
		} else if (G == 91) {
			relativeMode = true;
		}
		
		if(didAddAdjustmentCode) {
			if(![code hasField:'F']) {
				code = [code codeBySettingField:'F' toValue:F];
			}
			didAddAdjustmentCode = false;
		}
		
		[output addObject:code];
	}
	
	return [[TFPGCodeProgram alloc] initWithLines:output];
}



@end
