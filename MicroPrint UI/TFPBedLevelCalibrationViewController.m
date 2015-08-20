//
//  TFPBedLevelCalibrationViewController.m
//  microprint
//
//  Created by Tomas Franzén on Sat 2015-07-18.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPBedLevelCalibrationViewController.h"
#import "TFPBedLevelCalibration.h"
#import "TFPExtras.h"
#import "TFPBedLevelSettingsViewController.h"


@interface TFPBedLevelCalibrationViewController ()
@property TFPBedLevelCalibration *operation;
@property IBOutlet NSTabView *tabView;
@property IBOutlet NSStepper *levelStepper;
@property TFPBedLevelCalibrationCorner currentCorner;
@end


@implementation TFPBedLevelCalibrationViewController


- (void)switchToMovingMode {
	[self.tabView selectTabViewItemWithIdentifier:@"moving"];
}


- (void)switchToAdjustmentMode {
	[self.tabView selectTabViewItemWithIdentifier:@"adjustment"];
}


- (NSString*)cornerString {
	return @[@"Back-left corner", @"Back-right corner", @"Front-right corner", @"Front-left corner", @"Center"][self.currentCorner];
}


+ (NSSet *)keyPathsForValuesAffectingCornerString {
	return @[@"currentCorner"].tf_set;
}


- (NSString*)continueString {
	if(self.currentCorner == TFPBedLevelCalibrationCornerBackFrontLeft) {
		return @"Finish Calibration";
	}else{
		return @"Next Corner";
	}
}


+ (NSSet *)keyPathsForValuesAffectingContinueString {
	return @[@"currentCorner"].tf_set;
}


- (IBAction)stepperAction:(NSStepper*)stepper {
	if(stepper.doubleValue < 0) {
		[self.operation adjustDown];
	}else{
		[self.operation adjustUp];
	}
	stepper.doubleValue = 0;
}


- (void)viewDidAppear {
	[super viewDidAppear];
	__weak __typeof__(self) weakSelf = self;
	
	self.operation = [[TFPBedLevelCalibration alloc] initWithPrinter:self.printer];
	[self.operation startAtLevel:2 heightTarget:0.3];
	
	self.operation.didStartMovingHandler = ^{
		[weakSelf switchToMovingMode];
	};
	
	self.operation.didStopAtCornerHandler = ^(TFPBedLevelCalibrationCorner corner){
		weakSelf.currentCorner = corner;
		[weakSelf switchToAdjustmentMode];
	};
	
	self.operation.didFinishHandler = ^{
		[weakSelf dismissController:nil];
	};
	
	[self.view.window makeFirstResponder:self.levelStepper];
}


- (BOOL)performKeyEquivalent:(NSEvent *)theEvent {
	NSString *string = theEvent.characters;
	unichar c = string.length ? [string characterAtIndex:0] : 0;
	
	if(c == NSUpArrowFunctionKey || c == NSDownArrowFunctionKey) {
		[self.levelStepper keyUp:theEvent];
		return YES;
	} else {
		return NO;
	}
}


- (IBAction)next:(id)sender {
	[self.operation continue];
}


- (IBAction)cancel:(id)sender {
	[self.operation stop];
	[self dismissController:nil];
}


@end