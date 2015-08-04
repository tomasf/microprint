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
#import "TFPConsoleViewController.h"
#import "TFPExtras.h"
#import "TFPPrinter.h"

#import "MAKVONotificationCenter.h"


@interface TFPPrinterCollectionViewItem ()
@property NSWindowController *calibrationWindowController;
@property NSWindowController *consoleWindowController;

@property IBOutlet NSStackView *warningsStackView;
@end


@implementation TFPPrinterCollectionViewItem


- (void)viewDidLoad {
	[super viewDidLoad];
	__weak __typeof__(self) weakSelf = self;
	
	[self addObserver:self keyPath:@[@"representedObject.hasValidZLevel", @"representedObject.firmwareVersionComparedToTestedRange", @"representedObject.hasAllZeroBedLevelOffsets"] options:0 block:^(MAKVONotification *notification) {
		[weakSelf reloadWarnings];
	}];
}


- (NSButton*)makeWarningButtonWithTitle:(NSString*)title action:(SEL)action {
	NSButton *button = [NSButton new];
	button.translatesAutoresizingMaskIntoConstraints = NO;

	button.bezelStyle = NSRecessedBezelStyle;
	button.buttonType = NSMomentaryPushInButton;
	button.showsBorderOnlyWhileMouseInside = YES;

	button.font = [NSFont boldSystemFontOfSize:11];
	button.action = action;
	button.target = self;
	button.title = title;
	
	return button;
}


- (NSImageView*)warningIconImageView {
	NSImage *caution = [[NSImage imageNamed:@"NSCaution"] copy];
	[caution setSize:CGSizeMake(16, 16)];
	NSImageView *cautionImageView = [[NSImageView alloc] initWithFrame:(CGRect){CGPointZero, caution.size}];
	cautionImageView.image = caution;
	cautionImageView.translatesAutoresizingMaskIntoConstraints = NO;
	return cautionImageView;
}


- (void)reloadWarnings {
	TFPPrinter *printer = self.representedObject;
	
	BOOL invalidZ = printer && !printer.hasValidZLevel;
	BOOL untestedFirmware = printer && printer.firmwareVersionComparedToTestedRange != NSOrderedSame;
	BOOL allZeroBedLevelOffsets = printer && printer.hasAllZeroBedLevelOffsets;
	
	NSMutableArray *warningViews = [NSMutableArray new];
	if(invalidZ) {
		[warningViews addObject:[self makeWarningButtonWithTitle:@"Z Level Lost!" action:@selector(showZLostInfo:)]];
	}
	if(untestedFirmware) {
		[warningViews addObject:[self makeWarningButtonWithTitle:@"Untested Firmware" action:@selector(showFirmwareInfo:)]];
	}
	if(allZeroBedLevelOffsets) {
		[warningViews addObject:[self makeWarningButtonWithTitle:@"Bed Offsets Not Set" action:@selector(showZeroBedLevelInfo:)]];
	}
	
	if(warningViews.count) {
		[warningViews insertObject:[self warningIconImageView] atIndex:0];
	}
	
	[self.warningsStackView setViews:warningViews inGravity:NSStackViewGravityLeading];
}


- (void)showFirmwareInfo:(id)sender {
	TFPPrinter *printer = self.representedObject;
	NSAlert *alert = [NSAlert new];

	NSString *testedVersionsString;
	if([[TFPPrinter minimumTestedFirmwareVersion] isEqual:[TFPPrinter maximumTestedFirmwareVersion]]) {
		testedVersionsString = [TFPPrinter minimumTestedFirmwareVersion];
	}else{
		testedVersionsString = [NSString stringWithFormat:@"%@ through %@", [TFPPrinter minimumTestedFirmwareVersion], [TFPPrinter maximumTestedFirmwareVersion]];
	}
	
	if(printer.firmwareVersionComparedToTestedRange == NSOrderedDescending) {
		alert.messageText = [NSString stringWithFormat:@"The firmware on your printer (%@) is newer than the firmware version(s) MicroPrint has been tested with (%@).", printer.firmwareVersion, testedVersionsString];
		alert.informativeText = @"MicroPrint may work fine anyway, but keep an eye out for a new version.";

	}else{
		alert.messageText = [NSString stringWithFormat:@"The firmware on your printer (%@) is older than the firmware version(s) MicroPrint has been tested with (%@).", printer.firmwareVersion, testedVersionsString];
		alert.informativeText = @"MicroPrint may work fine anyway, but you should run the latest M3D software once and let it upgrade your firmware.";
	}
	
	alert.alertStyle = NSCriticalAlertStyle;
	[alert addButtonWithTitle:@"OK"];
	[alert beginSheetModalForWindow:self.view.window completionHandler:nil];
}


- (void)showZLostInfo:(id)sender {
	NSAlert *alert = [NSAlert new];
	alert.messageText = @"The Z level has been lost. This can happen if the printer loses power unexpectedly.";
	alert.informativeText = @"You need to use the \"Find Bed Zero\" function in the Tools window before you can print properly.";
	
	alert.alertStyle = NSCriticalAlertStyle;
	[alert addButtonWithTitle:@"OK"];
	[alert beginSheetModalForWindow:self.view.window completionHandler:nil];
}


- (void)showZeroBedLevelInfo:(id)sender {
	NSAlert *alert = [NSAlert new];
	alert.messageText = @"Your bed level offsets are all zero. This probably means you haven't calibrated your bed level, or the settings have been lost somehow.";
	alert.informativeText = @"Use \"Interactive Calibration\" in the Calibration window to fix this.";
	
	alert.alertStyle = NSCriticalAlertStyle;
	[alert addButtonWithTitle:@"OK"];
	[alert beginSheetModalForWindow:self.view.window completionHandler:nil];
}


- (IBAction)showFilamentOptions:(NSButton*)button {
	if([NSApp currentEvent].modifierFlags & NSAlternateKeyMask) {
		TFPPrinter *printer = self.representedObject;
		printer.incomingCodeBlock = ^(NSString *line){
			TFLog(@"< %@", line);
		};
		printer.outgoingCodeBlock = ^(NSString *line){
			TFLog(@"> %@", line);
		};
		
		TFLog(@"Enabled printer communication logging");
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


- (IBAction)openConsole:(id)sender {
	NSWindowController *windowController = [self.view.window.contentViewController.storyboard instantiateControllerWithIdentifier:@"consoleWindowController"];
	[(TFPConsoleViewController*)windowController.contentViewController setPrinter:self.representedObject];
	[windowController showWindow:nil];
	self.consoleWindowController = windowController;
}


@end
