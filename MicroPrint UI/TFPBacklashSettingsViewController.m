//
//  TFPBacklashSettings.m
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-16.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPBacklashSettingsViewController.h"

#import "MAKVONotificationCenter.h"


@interface TFPBacklashSettingsViewController ()
@property double xValue;
@property double yValue;
@property double speed;

@property BOOL hasChanges;
@end


@implementation TFPBacklashSettingsViewController

- (void)viewDidAppear {
	[super viewDidAppear];
	__weak __typeof__(self) weakSelf = self;
	
	[self.printer fetchBacklashValuesWithCompletionHandler:^(BOOL success, TFPBacklashValues values) {
		[self.printer fetchBacklashCompensationSpeedWithCompletionHandler:^(BOOL success, float speed) {
			self.xValue = values.x;
			self.yValue = values.y;
			self.speed = speed;
			self.hasChanges = NO;
		}];
	}];
	
	[self addObserver:self keyPath:@[@"xValue", @"yValue", @"speed"] options:0 block:^(MAKVONotification *notification) {
		weakSelf.hasChanges = YES;
	}];
}


- (IBAction)apply:(id)sender {
	__weak __typeof__(self) weakSelf = self;
	TFPBacklashValues values;
	values.x = self.xValue;
	values.y = self.yValue;
	
	[self.printer setBacklashValues:values completionHandler:^(BOOL success) {
		[weakSelf.printer setBacklashCompensationSpeed:weakSelf.speed completionHandler:^(BOOL success) {
			
		}];
	}];
	self.hasChanges = NO;
}


@end