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

#import "TFPExtras.h"


@interface TFPApplicationDelegate ()
@property NSWindow *mainWindow;

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



// Debugging


- (IBAction)addDryRunPrinter:(id)sender {
	[[TFPPrinterManager sharedManager] startDryRunMode];
}


- (IBAction)blockMainThreadTest:(id)sender {
	sleep(10);
}


- (IBAction)turnOnHeaterAsync:(id)sender {
	__weak __typeof__(self) weakSelf = self;
	
	TFPPrinter *printer = [TFPPrinterManager sharedManager].printers.firstObject;
	self.debugCancelBlock = [printer setHeaterTemperatureAsynchronously:200 progressBlock:^(double currentTemperature) {
		TFLog(@"Temp: %.02f", currentTemperature);
	} completionBlock:^{
		TFLog(@"Heated!");
		weakSelf.debugCancelBlock = nil;
	}];
}


- (IBAction)cancelHeater:(id)sender {
	if(self.debugCancelBlock) {
		self.debugCancelBlock();
		TFLog(@"Cancelled heating");
		self.debugCancelBlock = nil;
	}
}


- (IBAction)turnOffHeater:(id)sender {
	TFPPrinter *printer = [TFPPrinterManager sharedManager].printers.firstObject;
	[printer sendGCode:[TFPGCode codeForTurningOffHeater] responseHandler:nil];
}


- (void)testMoveToPosition:(TFP3DVector*)target {
	TFPPrinter *printer = [TFPPrinterManager sharedManager].printers.firstObject;

	self.debugCancelBlock = [printer moveAsynchronouslyToPosition:target feedRate:3000 progressBlock:^(double fraction, TFP3DVector *position) {
		NSLog(@"Progress: %d, %@", (int)(fraction*100), position);
	} completionBlock:^{
		NSLog(@"Done!");
	}];
}


- (IBAction)testPosition1:(id)sender {
	TFP3DVector *target = [TFP3DVector vectorWithX:@10 Y:@10 Z:@30];
	[self testMoveToPosition:target];
}


- (IBAction)testPosition2:(id)sender {
	TFP3DVector *target = [TFP3DVector vectorWithX:@85 Y:@85 Z:@10];
	[self testMoveToPosition:target];
}



- (IBAction)cancelMove:(id)sender {
	if(self.debugCancelBlock) {
		self.debugCancelBlock();
		TFLog(@"Cancelled move");
		self.debugCancelBlock = nil;
	}
}


@end