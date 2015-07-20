//
//  TFPBedLevelSettingsViewController.m
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-16.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPBedLevelSettingsViewController.h"
#import "TFPBedLevelCalibrationViewController.h"
#import "MAKVONotificationCenter.h"
#import "TFPTestBorderProgressViewController.h"


@interface TFPBedLevelSettingsViewController ()
@property double backLeftOffset;
@property double backRightOffset;
@property double frontRightOffset;
@property double frontLeftOffset;
@property double commonOffset;

@property BOOL hasChanges;

@property NSWindowController *calibrationWindowController;
@end


@implementation TFPBedLevelSettingsViewController


- (void)reload {
	[self.printer fetchBedOffsetsWithCompletionHandler:^(BOOL success, TFPBedLevelOffsets offsets) {
		self.backLeftOffset = offsets.backLeft;
		self.backRightOffset = offsets.backRight;
		self.frontRightOffset = offsets.frontRight;
		self.frontLeftOffset = offsets.frontLeft;
		self.commonOffset = offsets.common;
		self.hasChanges = NO;
	}];
}


- (void)viewDidAppear {
    [super viewDidAppear];
	__weak __typeof__(self) weakSelf = self;
	
	[self reload];
	
	[self addObserver:self keyPath:@[@"backLeftOffset", @"backRightOffset", @"frontRightOffset", @"frontLeftOffset", @"commonOffset"] options:0 block:^(MAKVONotification *notification) {
		weakSelf.hasChanges = YES;
	}];
}


- (IBAction)apply:(id)sender {
	TFPBedLevelOffsets offsets;
	offsets.backLeft = self.backLeftOffset;
	offsets.backRight = self.backRightOffset;
	offsets.frontRight = self.frontRightOffset;
	offsets.frontLeft = self.frontLeftOffset;
	offsets.common = self.commonOffset;
	
	[self.printer setBedOffsets:offsets completionHandler:nil];
	self.hasChanges = NO;
}


- (IBAction)printTestBorder:(id)sender {
	NSWindowController *windowController = [self.storyboard instantiateControllerWithIdentifier:@"TestBorderProgressWindowController"];
	TFPTestBorderProgressViewController *viewController = (TFPTestBorderProgressViewController*)windowController.contentViewController;
	viewController.printer = self.printer;
	
	[self presentViewControllerAsSheet:viewController];
}


- (IBAction)interactiveCalibration:(id)sender {
	NSWindowController *windowController = [self.storyboard instantiateControllerWithIdentifier:@"BedLevelCalibrationWindowController"];
	TFPBedLevelCalibrationViewController *viewController = (TFPBedLevelCalibrationViewController*)windowController.contentViewController;
	viewController.printer = self.printer;
	viewController.bedLevelSettingsViewController = self;
	
	[self presentViewControllerAsSheet:viewController];
}


@end