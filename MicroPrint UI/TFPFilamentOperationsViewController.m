//
//  TFPFilamentOperationsViewController.m
//  microprint
//
//  Created by Tomas Franzén on Tue 2015-07-14.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPFilamentOperationsViewController.h"
#import "TFPExtrusionOperation.h"


@interface TFPFilamentOperationsViewController ()
@property IBOutlet NSButton *retractButton;
@property IBOutlet NSButton *extrudeButton;

@property IBOutlet NSProgressIndicator *progressIndicator;
@property IBOutlet NSTextField *statusLabel;

@property TFPExtrusionOperation *operation;
@end


@implementation TFPFilamentOperationsViewController


- (void)startRetract:(BOOL)retract {
	__weak __typeof__(self) weakSelf = self;
	
	NSButton *actionButton = retract ? self.retractButton : self.extrudeButton;
	NSButton *otherButton = retract ? self.extrudeButton : self.retractButton;
	
	NSString *initialTitle = actionButton.title;
	actionButton.title = @"Stop";
	actionButton.keyEquivalent = @"\r";
	otherButton.enabled = NO;
	
	self.operation = [[TFPExtrusionOperation alloc] initWithPrinter:self.printer retraction:retract];
	
	self.operation.movingStartedBlock = ^{
		weakSelf.statusLabel.stringValue = @"Raising head…";
		[weakSelf.progressIndicator setIndeterminate:YES];
		[weakSelf.progressIndicator startAnimation:nil];
	};
	
	self.operation.heatingStartedBlock = ^{
		weakSelf.statusLabel.stringValue = @"Heating up…";
	};
	
	self.operation.heatingProgressBlock = ^(double temperature){
		[weakSelf.progressIndicator setIndeterminate:NO];
		weakSelf.progressIndicator.doubleValue = temperature / weakSelf.operation.temperature;
	};
	
	self.operation.extrusionStartedBlock = ^() {
		[weakSelf.progressIndicator setIndeterminate:YES];
		weakSelf.statusLabel.stringValue = retract ? @"Retracting" : @"Extruding";
	};
	
	self.operation.extrusionStoppedBlock = ^() {
		[weakSelf.progressIndicator stopAnimation:nil];
		weakSelf.statusLabel.stringValue = @"";
		weakSelf.operation = nil;
		
		actionButton.title = initialTitle;
		actionButton.keyEquivalent = @"";
		otherButton.enabled = YES;
	};
	
	[self.operation start];
}



- (IBAction)retract:(id)sender {
	if(self.operation) {
		[self.operation stop];
		self.statusLabel.stringValue = @"Stopping…";
	}else{
		[self startRetract:YES];
	}
}


- (IBAction)extrude:(id)sender {
	if(self.operation) {
		[self.operation stop];
		self.statusLabel.stringValue = @"Stopping…";
	}else{
		[self startRetract:NO];
	}
}


@end
