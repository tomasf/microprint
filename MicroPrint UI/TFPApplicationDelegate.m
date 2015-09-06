//
//  AppDelegate.m
//  MicroPrint UI
//
//  Created by Tomas Franzén on Mon 2015-07-13.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPApplicationDelegate.h"
#import "TFPPrinterManager.h"
#import "TFPPrinter.h"
#import "TFPDryRunPrinter.h"
#import "TFPBedLevelCompensator.h"

#import "TFPExtras.h"


@interface TFPApplicationDelegate ()
@property NSWindow *mainWindow;
@property TFPPrinterContext *debugContext;
@property (copy) void(^debugCancelBlock)();
@end


@implementation TFPApplicationDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	self.mainWindow = [NSApp windows].firstObject;
}


- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
	[self.mainWindow makeKeyAndOrderFront:nil];
	return NO;
}


- (IBAction)openMainWindow:(id)sender {
	[self.mainWindow makeKeyAndOrderFront:nil];
}


@end