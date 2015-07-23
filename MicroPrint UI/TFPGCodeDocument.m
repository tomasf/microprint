//
//  TFPGCodeDocument.m
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-07-13.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPGCodeDocument.h"
#import "TFPGCodeProgram.h"
#import "TFPPrintSettingsViewController.h"
#import "Extras.h"
#import "TFPGCodeHelpers.h"
#import "TFPPrinterManager.h"


@interface TFPGCodeDocument ()
@property (readwrite) TFP3DVector *printSize;
@property (readwrite) NSDictionary *curaProfile;

@property NSWindowController *loadingWindowController;
@end


@implementation TFPGCodeDocument


- (instancetype)init {
	if(!(self = [super init])) return nil;
	
	self.selectedPrinter = [TFPPrinterManager sharedManager].printers.firstObject;
	self.filamentType = TFPFilamentTypePLA;
	self.useWaveBonding = YES;
	
	return self;
}


- (void)makeWindowControllers {
	NSWindowController *windowController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"PrintWindowController"];
	
	((TFPPrintSettingsViewController*)windowController.contentViewController).document = self;
	
	[self addWindowController:windowController];
}


+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName {
	return YES;
}


- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
	dispatch_async(dispatch_get_main_queue(), ^{
		self.loadingWindowController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"LoadingWindowController"];
		[self.loadingWindowController showWindow:nil];
	});
	
	void(^stopLoading)() = ^{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.loadingWindowController close];
		});
	};
	
	TFPGCodeProgram *program = [[TFPGCodeProgram alloc] initWithFileURL:absoluteURL error:outError];
	if(!program) {		
		stopLoading();
		return NO;
	}
	
	if(![program validateForM3D:outError]) {
		stopLoading();
		return NO;
	}
	
	stopLoading();
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		TFP3DVector *size = [program measureSize];
		dispatch_async(dispatch_get_main_queue(), ^{
			self.printSize = size;
		});
		
		self.curaProfile = [program curaProfileValues];
		NSLog(@"%@", self.curaProfile);
	});
	
	return YES;
}


- (id)valueForUndefinedKey:(NSString *)key {
	return [[self printSettingsViewController] valueForKey:key];
}


- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
	return [[self printSettingsViewController] setValue:value forKey:key];
}


- (TFPPrintSettingsViewController*)printSettingsViewController {
	return (TFPPrintSettingsViewController*)[self.windowControllers.firstObject contentViewController];
}


- (void)close {
	self.printSettingsViewController.document = nil;
	[super close];
}


@end
