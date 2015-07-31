//
//  TFPScriptManager.m
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-23.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPScriptManager.h"
#import "TFPExtras.h"
@import AppKit;

static const NSUInteger maxRecentURLCount = 10;


@interface TFPScriptManager ()
@property (readwrite) NSArray *recentScripts;
@end


@implementation TFPScriptManager


+ (instancetype)sharedManager {
	static TFPScriptManager *singleton;
	return singleton ?: (singleton = [self new]);
}


- (void)readSavedRecentData {
	NSArray *bookmarks = [[NSUserDefaults standardUserDefaults] objectForKey:@"RecentScripts"] ?: @[];
	
	self.recentScripts = [bookmarks tf_mapWithBlock:^NSURL*(NSData *bookmark) {
		return [NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting relativeToURL:nil bookmarkDataIsStale:nil error:nil];
	}];
}


- (void)writeRecentData {
	NSArray *bookmarks = [self.recentScripts tf_mapWithBlock:^NSData*(NSURL *URL) {
		return [URL bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
	}];
	
	[[NSUserDefaults standardUserDefaults] setObject:bookmarks forKey:@"RecentScripts"];
}


- (instancetype)init {
	if(!(self = [super init])) return nil;
	
	[self readSavedRecentData];
	
	return self;
}


- (void)addRecentScript:(NSURL*)URL {
	NSMutableArray *URLs = [self mutableArrayValueForKey:@"recentScripts"];
	[URLs removeObject:URL];
	[URLs insertObject:URL atIndex:0];
	
	if(URLs.count > maxRecentURLCount) {
		[URLs removeObjectsInRange:NSMakeRange(maxRecentURLCount, URLs.count-maxRecentURLCount)];
	}
	
	[self writeRecentData];
}


- (NSOpenPanel*)openPanelForSelectingScript {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	openPanel.allowedFileTypes = @[@"com.apple.applescript.​script", @"scpt"];
	return openPanel;
}


- (BOOL)runScriptFile:(NSURL*)URL printName:(NSString*)printName duration:(NSString*)durationString errorInfo:(NSDictionary**)error {
	NSAppleScript *script = [[NSAppleScript alloc] initWithContentsOfURL:URL error:error];
	if(!script) {
		return NO;
	}
	
	const FourCharCode kASAppleScriptSuite = 'ascr';
	const FourCharCode kASSubroutineEvent = 'psbr';
	const FourCharCode keyASSubroutineName = 'snam';
	
	NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite eventID:kASSubroutineEvent targetDescriptor:nil returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
	
	[event setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:@"printFinished"] forKeyword:keyASSubroutineName];
	
	NSAppleEventDescriptor *arguments = [NSAppleEventDescriptor listDescriptor];
	[arguments insertDescriptor:[NSAppleEventDescriptor descriptorWithString:printName] atIndex:1];
	[arguments insertDescriptor:[NSAppleEventDescriptor descriptorWithString:durationString] atIndex:2];
	[event setParamDescriptor:arguments forKeyword:keyDirectObject];
	
	return [script executeAppleEvent:event error:error] != nil;
}


@end
