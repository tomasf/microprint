//
//  TFPPrintSettingsViewController.m
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-07-13.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrintSettingsViewController.h"
#import "TFPPrinterManager.h"
#import "TFPPrinter.h"
#import "MAKVONotificationCenter.h"
#import "TFPPrintJob.h"
#import "TFPPreprocessing.h"
#import "TFPGCodeDocument.h"
#import "TFPPrintingProgressViewController.h"
#import "TFPGCodeHelpers.h"


@interface TFPPrintSettingsViewController () <NSMenuDelegate>
@property IBOutlet NSPopUpButton *printerMenuButton;
@property IBOutlet NSTextField *temperatureTextField;
@property IBOutlet NSTextField *dimensionsLabel;

@property TFPPrinterManager *printerManager;

@property TFPPrinter *selectedPrinter;
@property TFPFilamentType filamentType;
@property NSNumber *temperature;
@property BOOL useWaveBonding;
@end



@implementation TFPPrintSettingsViewController


- (instancetype)initWithCoder:(NSCoder *)coder {
	if(!(self = [super initWithCoder:coder])) return nil;
	
	self.printerManager = [TFPPrinterManager sharedManager];
	self.selectedPrinter = self.printerManager.printers.firstObject;
	
	self.filamentType = TFPFilamentTypePLA;
	self.useWaveBonding = YES;
	
	return self;
}


- (void)viewDidAppear {
	[super viewDidAppear];
	__weak __typeof__(self) weakSelf = self;
	
	self.printerMenuButton.menu.delegate = self;
	[self updatePrinterMenuImages];
	
	[self addObserver:self keyPath:@[@"temperature", @"filamentType"] options:NSKeyValueObservingOptionInitial block:^(MAKVONotification *notification) {
		[weakSelf updateTemperaturePlaceholder];
	}];
	
	weakSelf.dimensionsLabel.stringValue = @"Measuring…\n\n";
	
	TFPGCodeProgram *program = self.program;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		TFP3DVector *size = [program measureSize];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			NSNumberFormatter *formatter = [NSNumberFormatter new];
			formatter.positiveSuffix = @" mm";
			formatter.minimumFractionDigits = 2;
			formatter.maximumFractionDigits = 2;
			formatter.minimumIntegerDigits = 1;
			
			weakSelf.dimensionsLabel.stringValue = [NSString stringWithFormat:@"X:  %@\nY:  %@\nZ:  %@",
													[formatter stringFromNumber:size.x],
													[formatter stringFromNumber:size.y],
													[formatter stringFromNumber:size.z]];
		});
	});
}


- (void)updatePrinterMenuImages {
	NSImage *microImage = [[NSImage imageNamed:@"Micro"] copy];
	[microImage setSize:CGSizeMake(microImage.size.width / 3, microImage.size.height / 3)];
	
	for(NSMenuItem *item in self.printerMenuButton.menu.itemArray) {
		item.image = microImage;
	}
}


- (void)updateTemperaturePlaceholder {
	dispatch_async(dispatch_get_main_queue(), ^{
		int temperature = [TFPFilament filamentForType:self.filamentType].defaultTemperature;
		NSString *string = [NSString stringWithFormat:@"%d", temperature];
		self.temperatureTextField.placeholderString = string;
	});
}


- (void)menuNeedsUpdate:(NSMenu *)menu {
	[self updatePrinterMenuImages];
}


- (TFPGCodeDocument*)document {
	return [[NSDocumentController sharedDocumentController] documentForWindow:self.view.window];
}


- (TFPPrintParameters*)printParameters {
	TFPPrintParameters *parameters = [TFPPrintParameters new];
	parameters.filament = [TFPFilament filamentForType:self.filamentType];
	if(self.temperature) {
		parameters.idealTemperature = self.temperature.doubleValue;
	}
	
	parameters.useWaveBonding = self.useWaveBonding;
	return parameters;
}


- (IBAction)print:(id)sender {
	TFPPrintParameters *params = [self printParameters];
	[self.selectedPrinter fillInOffsetAndBacklashValuesInPrintParameters:params completionHandler:^(BOOL success) {
		NSWindowController *printingProgressWindowController = [self.storyboard instantiateControllerWithIdentifier:@"printingProgressWindowController"];
		
		TFPPrintingProgressViewController *viewController = (TFPPrintingProgressViewController*)printingProgressWindowController.window.contentViewController;
		viewController.printer = self.selectedPrinter;
		viewController.program = self.program;
		viewController.printParameters = params;
		
		viewController.parentWindow = self.view.window;
		
		[self.view.window beginSheet:printingProgressWindowController.window completionHandler:nil];
		[viewController start];
	}];
}


@end
