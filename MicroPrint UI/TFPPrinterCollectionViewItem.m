//
//  TFPPrinterCollectionViewItem.m
//  microprint
//
//  Created by Tomas Franzén on Tue 2015-07-14.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrinterCollectionViewItem.h"
#import "TFPPrinterOperationsViewController.h"
#import "TFPBedLevelSettingsViewController.h"
#import "TFPBacklashSettingsViewController.h"


@interface TFPPrinterCollectionViewItem ()
@property NSWindowController *calibrationWindowController;
@end


@implementation TFPPrinterCollectionViewItem


- (IBAction)showFilamentOptions:(NSButton*)button {
	if([NSApp currentEvent].modifierFlags & NSAlternateKeyMask) {
		TFPPrinter *printer = self.representedObject;
		printer.verboseMode = !printer.verboseMode;
		NSLog(@"Verbose mode %@", printer.verboseMode ? @"on" : @"off");
		return;
	}
	
	TFPPrinterOperationsViewController *viewController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"extrusionViewController"];
	viewController.printer = self.representedObject;

	[self.view.window.contentViewController presentViewControllerAsSheet:viewController];
}


- (IBAction)openCalibration:(id)sender {
	self.calibrationWindowController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"CalibrationWindowController"];
	
	NSTabViewController *tabController = (NSTabViewController*)self.calibrationWindowController.contentViewController;
	TFPBedLevelSettingsViewController *viewController = tabController.childViewControllers.firstObject;
	viewController.printer = self.representedObject;

	TFPBacklashSettingsViewController *viewController2 = tabController.childViewControllers.lastObject;
	viewController2.printer = self.representedObject;

	[self.calibrationWindowController.window makeKeyAndOrderFront:nil];
}


@end
