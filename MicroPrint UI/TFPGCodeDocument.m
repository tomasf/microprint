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
#import "TFPExtras.h"
#import "TFPGCodeHelpers.h"
#import "TFPPrinterManager.h"

#import "MAKVONotificationCenter.h"


static NSString *const savedSettingsKey = @"SavedDocumentSettings";


@interface TFPGCodeDocument ()
@property (readwrite) TFPCuboid boundingBox;
@property (readwrite) BOOL hasBoundingBox;
@property (readwrite) NSDictionary *curaProfile;

@property NSWindowController *loadingWindowController;
@end


@implementation TFPGCodeDocument


- (instancetype)init {
	if(!(self = [super init])) return nil;
	
	self.selectedPrinter = [TFPPrinterManager sharedManager].printers.firstObject;
	self.filamentType = TFPFilamentTypePLA;
	self.useWaveBonding = YES;
	
	NSData *savedSettings = [[NSUserDefaults standardUserDefaults] dataForKey:savedSettingsKey];
	[self useEncodedSettings:savedSettings];
	
	/*
	[self addObserver:self keyPath:@[@"filamentType", @"useWaveBonding", @"temperature", @"completionScriptURL"] options:0 block:^(MAKVONotification *notification) {
		[weakSelf saveSettings];
	}];
	*/
	
	return self;
}


- (void)saveSettings {
	NSData *settings = [self encodedSettings];
	[[NSUserDefaults standardUserDefaults] setObject:settings forKey:savedSettingsKey];
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
		TFPCuboid boundingBox = [program measureBoundingBox];
		dispatch_async(dispatch_get_main_queue(), ^{
			self.boundingBox = boundingBox;
			self.hasBoundingBox = YES;
		});
		
		NSDictionary *profile = [program curaProfileValues];
		dispatch_async(dispatch_get_main_queue(), ^{
			self.curaProfile = profile;
		});
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


- (NSData*)completionScriptBookmark {
	return [self.completionScriptURL bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
}


- (void)setCompletionScriptBookmark:(NSData*)bookmark {
	self.completionScriptURL = [NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithoutUI relativeToURL:nil bookmarkDataIsStale:nil error:nil];
}


- (NSData*)encodedSettings {
	NSMutableDictionary *values = [[self dictionaryWithValuesForKeys:@[@"filamentType", @"temperature", @"useWaveBonding", @"completionScriptBookmark"]] mutableCopy];
	values[@"formatVersion"] = @1;
	return [NSKeyedArchiver archivedDataWithRootObject:values];
}


- (void)useEncodedSettings:(NSData*)data {
	NSDictionary *values = data ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil;
	values = [values dictionaryWithValuesForKeys:@[@"filamentType", @"temperature", @"useWaveBonding", @"completionScriptBookmark"]];
	
	for(NSString *key in values) {
		id value = values[key];
		if(value == [NSNull null]) {
			value = nil;
		}
		[self setValue:value forKey:key];
	}
}


- (void)close {
	self.printSettingsViewController.document = nil;
	[super close];
}


@end
