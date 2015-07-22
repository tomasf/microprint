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
#import "Extras.h"


@interface TFPPrintSettingsViewController () <NSMenuDelegate>
@property IBOutlet NSPopUpButton *printerMenuButton;
@property IBOutlet NSTextField *temperatureTextField;
@property IBOutlet NSTextField *dimensionsLabel;

@property TFPPrinterManager *printerManager;

@property TFPPrintingProgressViewController *printingProgressViewController;
@end



@implementation TFPPrintSettingsViewController


- (instancetype)initWithCoder:(NSCoder *)coder {
	if(!(self = [super initWithCoder:coder])) return nil;
	
	self.printerManager = [TFPPrinterManager sharedManager];
	
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
}


- (NSString*)printDimensionsString {
	if(self.document.printSize) {
		NSNumberFormatter *formatter = [NSNumberFormatter new];
		formatter.positiveSuffix = @" mm";
		formatter.minimumFractionDigits = 2;
		formatter.maximumFractionDigits = 2;
		formatter.minimumIntegerDigits = 1;
		
		return [NSString stringWithFormat:@"X:  %@\nY:  %@\nZ:  %@",
				[formatter stringFromNumber:self.document.printSize.x],
				[formatter stringFromNumber:self.document.printSize.y],
				[formatter stringFromNumber:self.document.printSize.z]];
		
	}else{
		return @"Measuring…\n\n";;
	}
}


+ (NSSet *)keyPathsForValuesAffectingPrintDimensionsString {
	return @[@"document.printSize"].tf_set;
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
		int temperature = [TFPFilament filamentForType:self.document.filamentType].defaultTemperature;
		NSString *string = [NSString stringWithFormat:@"%d", temperature];
		self.temperatureTextField.placeholderString = string;
	});
}


- (void)menuNeedsUpdate:(NSMenu *)menu {
	[self updatePrinterMenuImages];
}


- (TFPPrintParameters*)printParameters {
	TFPPrintParameters *parameters = [TFPPrintParameters new];
	parameters.maxZ = self.document.printSize.z.doubleValue;
	
	parameters.filament = [TFPFilament filamentForType:self.document.filamentType];
	if(self.document.temperature) {
		parameters.idealTemperature = self.document.temperature.doubleValue;
	}
	
	parameters.useWaveBonding = self.document.useWaveBonding;
	return parameters;
}


- (IBAction)print:(id)sender {
	__weak __typeof__(self) weakSelf = self;
	
	TFPPrintingProgressViewController *viewController = [self.storyboard instantiateControllerWithIdentifier:@"PrintingProgressViewController"];
	viewController.printer = self.document.selectedPrinter;
	viewController.printParameters = [self printParameters];
	viewController.GCodeFileURL = self.document.fileURL;
	
	self.printingProgressViewController = viewController;
	[self presentViewControllerAsSheet:viewController];
	[viewController start];
	
	viewController.endHandler = ^{
		weakSelf.printingProgressViewController = nil;
	};
}


- (BOOL)canPrint {
	return self.document.selectedPrinter != nil && self.document.printSize != nil;
}


+ (NSSet *)keyPathsForValuesAffectingCanPrint {
	return @[@"document.selectedPrinter", @"document.printSize"].tf_set;
}


- (id)valueForUndefinedKey:(NSString *)key {
	if([key hasPrefix:@"progress."]) {
		return [self.printingProgressViewController valueForKey:[key substringFromIndex:9]];
	}else{
		return [super valueForUndefinedKey:key];
	}
}


- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
	if([key hasPrefix:@"progress."]) {
		return [self.printingProgressViewController setValue:value forKey:[key substringFromIndex:9]];
	}else{
		return [super setValue:value forUndefinedKey:key];
	}
}


@end
