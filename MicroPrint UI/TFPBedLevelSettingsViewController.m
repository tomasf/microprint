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


- (void)viewDidAppear {
    [super viewDidAppear];
	__weak __typeof__(self) weakSelf = self;
		
	[self addObserver:self keyPath:@"printer.bedLevelOffsets" options:NSKeyValueObservingOptionInitial block:^(MAKVONotification *notification) {
		if(!weakSelf.hasChanges) {
			weakSelf.backLeftOffset = weakSelf.printer.bedLevelOffsets.backLeft;
			weakSelf.backRightOffset = weakSelf.printer.bedLevelOffsets.backRight;
			weakSelf.frontRightOffset = weakSelf.printer.bedLevelOffsets.frontRight;
			weakSelf.frontLeftOffset = weakSelf.printer.bedLevelOffsets.frontLeft;
			weakSelf.commonOffset = weakSelf.printer.bedLevelOffsets.common;
			weakSelf.hasChanges = NO;
		}
	}];
	
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
	
	self.printer.bedLevelOffsets = offsets;
	self.hasChanges = NO;
}


- (IBAction)interactiveCalibration:(id)sender {
	NSWindowController *windowController = [self.storyboard instantiateControllerWithIdentifier:@"BedLevelCalibrationWindowController"];
	TFPBedLevelCalibrationViewController *viewController = (TFPBedLevelCalibrationViewController*)windowController.contentViewController;
	viewController.printer = self.printer;
	viewController.bedLevelSettingsViewController = self;
	
	[self presentViewControllerAsSheet:viewController];
}


- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender {
	[(TFPCalibrationViewController*)segue.destinationController setPrinter:self.printer];
}


@end