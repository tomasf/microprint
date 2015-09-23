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
#import "TFPGCodeDocument.h"
#import "TFPPrintingProgressViewController.h"
#import "TFPGCodeHelpers.h"
#import "TFPExtras.h"
#import "TFPScriptManager.h"
@import QuartzCore;


static NSString *const showAdvancedSettingsKey = @"ShowAdvancedPrintSettings";



@interface TFPPrintSettingsViewController () <NSMenuDelegate>
@property IBOutlet NSPopUpButton *printerMenuButton;
@property IBOutlet NSPopUpButton *scriptMenuButton;

@property IBOutlet NSTextField *temperatureTextField;
@property IBOutlet NSTextField *dimensionsLabel;

@property IBOutlet NSButton *printButton;

@property IBOutlet NSView *advancedSettingsView;
@property (nonatomic) BOOL showAdvancedSettings;
@property IBOutlet NSLayoutConstraint *advancedSettingsConstraint;
@property NSLayoutConstraint *basicSettingsConstraint;
@property IBOutlet NSButton *advancedDisclosureButton;

@property TFPPrinterManager *printerManager;

@property TFPPrintingProgressViewController *printingProgressViewController;
@end



@implementation TFPPrintSettingsViewController


- (instancetype)initWithCoder:(NSCoder *)coder {
	if(!(self = [super initWithCoder:coder])) return nil;
	
	self.printerManager = [TFPPrinterManager sharedManager];
	
	return self;
}


- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.basicSettingsConstraint = [NSLayoutConstraint constraintWithItem:self.printButton attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.printerMenuButton attribute:NSLayoutAttributeBottom multiplier:1 constant:20];
	
	[self setShowAdvancedSettings:[[NSUserDefaults standardUserDefaults] boolForKey:showAdvancedSettingsKey] animated:NO];
}


- (void)viewDidAppear {
	[super viewDidAppear];
	__weak __typeof__(self) weakSelf = self;
	
	self.printerMenuButton.menu.delegate = self;
	[self updatePrinterMenuImages];
	
	[self addObserver:self keyPath:@[@"document.temperature", @"document.filamentType"] options:NSKeyValueObservingOptionInitial block:^(MAKVONotification *notification) {
		[weakSelf updateTemperaturePlaceholder];
	}];
	
	[self updateScriptMenu];
}


- (NSString*)printDimensionsString {
	if(self.document.boundingBox.xSize > 0) {
		NSNumberFormatter *formatter = [NSNumberFormatter new];
		formatter.positiveSuffix = @" mm";
		formatter.minimumFractionDigits = 2;
		formatter.maximumFractionDigits = 2;
		formatter.minimumIntegerDigits = 1;
		
		return [NSString stringWithFormat:@"X:  %@\nY:  %@\nZ:  %@",
				[formatter stringFromNumber:@(self.document.boundingBox.xSize)],
				[formatter stringFromNumber:@(self.document.boundingBox.ySize)],
				[formatter stringFromNumber:@(self.document.boundingBox.zSize)]];
		
	}else{
		return @"Measuring…\n\n";;
	}
}


+ (NSSet *)keyPathsForValuesAffectingPrintDimensionsString {
	return @[@"document.hasBoundingBox"].tf_set;
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
	parameters.boundingBox = self.document.boundingBox;
	
	parameters.filament = [TFPFilament filamentForType:self.document.filamentType];
	if(self.document.temperature) {
		parameters.temperature = self.document.temperature.doubleValue;
	}
	
	parameters.useThermalBonding = self.document.useThermalBonding;
	
	return parameters;
}


- (IBAction)print:(id)sender {
	__weak __typeof__(self) weakSelf = self;
	
	[self.document saveSettings];
	
	TFPPrintingProgressViewController *viewController = [self.storyboard instantiateControllerWithIdentifier:@"PrintingProgressViewController"];
	viewController.printer = self.document.selectedPrinter;
	viewController.printParameters = [self printParameters];
	viewController.program = self.document.program;
	
	self.printingProgressViewController = viewController;
	[self presentViewControllerAsSheet:viewController];
	[viewController start];
	
	viewController.endHandler = ^(BOOL didFinish){
		if(didFinish && weakSelf.document.completionScriptURL) {
			NSDictionary *error;
			BOOL success = [[TFPScriptManager sharedManager] runScriptFile:weakSelf.document.completionScriptURL printName:self.document.displayName duration:weakSelf.printingProgressViewController.elapsedTimeString errorInfo:&error];
			if(!success) {
				NSMutableDictionary *userInfo = [NSMutableDictionary new];
				userInfo[NSLocalizedDescriptionKey] = error[NSAppleScriptErrorMessage] ?: @"Script execution failed.";
				if (error[NSAppleScriptErrorNumber]) {
					userInfo[NSLocalizedRecoverySuggestionErrorKey] = [NSString stringWithFormat:@"AppleScript error %@", error[NSAppleScriptErrorNumber]];
				}
				NSError *error = [NSError errorWithDomain:TFPErrorDomain code:TFPScriptExecutionError userInfo:userInfo];
				[weakSelf presentError:error];
			}
		}
		
		if(didFinish) {
			NSAlert *alert = [NSAlert new];
			alert.messageText = [NSString stringWithFormat:@"Printing finished in %@.", weakSelf.printingProgressViewController.elapsedTimeString];
			[alert addButtonWithTitle:@"OK"];
			[alert beginSheetModalForWindow:weakSelf.view.window completionHandler:nil];
		}
		
		weakSelf.printingProgressViewController = nil;
	};
}


- (BOOL)canPrint {
	return self.document.selectedPrinter != nil && self.document.boundingBox.xSize > 0 && !self.document.selectedPrinter.currentOperation;
}


+ (NSSet *)keyPathsForValuesAffectingCanPrint {
	return @[@"document.selectedPrinter", @"document.selectedPrinter.currentOperation", @"document.hasBoundingBox"].tf_set;
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



#pragma mark - Slicer Profile



+ (NSArray*)profileKeysToDisplay {
	return @[@"Layer Height", @"Wall Thickness", @"Fill Density", @"Bed Adhesion", @"Support", @"Print Speed"];
}


+ (NSSet *)keyPathsForValuesAffectingProfileKeysString {
	return @[@"document.slicerProfile"].tf_set;
}


+ (NSSet *)keyPathsForValuesAffectingProfileValuesString {
	return [[self profileKeysToDisplay] tf_mapWithBlock:^NSString*(NSString *key) {
        return [@"document.slicerProfile." stringByAppendingString:key];
    }].tf_set;
}


- (NSString*)profileKeysString {
	if(!self.document.slicerProfile) {
		return @"No Profile";
	}

    return [[[self.class profileKeysToDisplay] tf_mapWithBlock:^NSString*(NSString *key) {
		return [key stringByAppendingString:@":"];
	}] componentsJoinedByString:@"\n"];
}


- (NSString*)profileValuesString {
	if(!self.document.slicerProfile) {
		return @"";
	}
	
	return [[[self.class profileKeysToDisplay] tf_mapWithBlock:^NSString*(NSString *key) {
		return [self.document.slicerProfile formattedValueForKey:key];
	}] componentsJoinedByString:@"\n"];
}


#pragma mark - Scripts


- (NSMenuItem*)fileMenuItemForURL:(NSURL*)URL {
	NSDictionary *resourceValues = [URL resourceValuesForKeys:@[NSURLEffectiveIconKey, NSURLLocalizedNameKey] error:nil];
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:resourceValues[NSURLLocalizedNameKey] action:@selector(selectScriptFile:) keyEquivalent:@""];
	item.target = self;
	item.representedObject = URL;
	
	NSImage *image = [resourceValues[NSURLEffectiveIconKey] copy];
	image.size = CGSizeMake(16, 16);
	item.image = image;
	
	return item;
}


- (void)selectScriptFile:(NSMenuItem*)item {
	self.document.completionScriptURL = item.representedObject;
	[self updateScriptMenu];
}


- (void)chooseScript:(NSMenuItem*)item {
	NSOpenPanel *panel = [[TFPScriptManager sharedManager] openPanelForSelectingScript];
	[panel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
		if(result == NSFileHandlingPanelOKButton) {
			self.document.completionScriptURL = panel.URL;
			[[TFPScriptManager sharedManager] addRecentScript:panel.URL];
		}
		[self updateScriptMenu];
	}];
}


- (void)updateScriptMenu {
	NSMenu *menu = [NSMenu new];
	
	NSMenuItem *selectedItem = [[NSMenuItem alloc] initWithTitle:@"None" action:@selector(selectScriptFile:) keyEquivalent:@""];
	selectedItem.target = self;
	[menu addItem:selectedItem];
	
	if(self.document.completionScriptURL) {
		[menu addItem:[NSMenuItem separatorItem]];

		NSMenuItem *item = [self fileMenuItemForURL:self.document.completionScriptURL];
		[menu addItem:item];
		selectedItem = item;
	}
	
	NSArray *recents = [[TFPScriptManager sharedManager].recentScripts tf_rejectWithBlock:^BOOL(NSURL *recentURL) {
		return [recentURL isEqual:self.document.completionScriptURL];
	}];
	
	if(recents.count) {
		[menu addItem:[NSMenuItem separatorItem]];
		NSMenuItem *recentsHeader = [[NSMenuItem alloc] initWithTitle:@"Recent Scripts" action:NSSelectorFromString(@"something") keyEquivalent:@""];
		recentsHeader.enabled = NO;
		[menu addItem:recentsHeader];
	}
	
	for(NSURL *recentURL in recents) {
		[menu addItem:[self fileMenuItemForURL:recentURL]];
	}
	
	
	[menu addItem:[NSMenuItem separatorItem]];
	NSMenuItem *chooseItem = [[NSMenuItem alloc] initWithTitle:@"Choose…" action:@selector(chooseScript:) keyEquivalent:@""];
	chooseItem.target = self;
	[menu addItem:chooseItem];
	
	self.scriptMenuButton.menu = menu;
	[self.scriptMenuButton selectItem:selectedItem];
}


- (void)setShowAdvancedSettings:(BOOL)showAdvancedSettings animated:(BOOL)animate {
	self.showAdvancedSettings = showAdvancedSettings;
	self.advancedDisclosureButton.state = showAdvancedSettings ? NSOnState : NSOffState;
	[[NSUserDefaults standardUserDefaults] setBool:showAdvancedSettings forKey:showAdvancedSettingsKey];
	
	[self.view.window makeFirstResponder:nil];
	
	CGFloat advancedViewHeight = self.advancedSettingsView.frame.size.height;
	CGFloat extraHeight = showAdvancedSettings ? 0 : -advancedViewHeight;
	CGFloat margin = 20;
	
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = animate ? 0.25 : 0;
		context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
		
		self.advancedSettingsConstraint.animator.constant = margin + extraHeight;
		self.advancedSettingsView.animator.hidden = !showAdvancedSettings;
	} completionHandler:nil];
	
}


- (IBAction)toggleShowAdvanced:(id)sender {
	[self setShowAdvancedSettings:!self.showAdvancedSettings animated:YES];
}


@end