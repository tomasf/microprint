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
		self.xValue = values.x;
		self.yValue = values.y;
		self.speed = values.speed;
		self.hasChanges = NO;
	}];
	
	[self addObserver:self keyPath:@[@"xValue", @"yValue", @"speed"] options:0 block:^(MAKVONotification *notification) {
		weakSelf.hasChanges = YES;
	}];
}


- (IBAction)apply:(id)sender {
	TFPBacklashValues values = {.x = self.xValue, .y = self.yValue, .speed = self.speed};
	[self.printer setBacklashValues:values completionHandler:nil];
	
	self.hasChanges = NO;
}


@end