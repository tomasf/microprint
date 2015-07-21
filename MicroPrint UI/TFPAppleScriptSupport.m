//
//  TFPAppleScriptSupport.m
//  microprint
//
//  Created by Tomas Franzén on Tue 2015-07-21.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPAppleScriptSupport.h"
#import "TFPFilament.h"
#import "TFPPrintingProgressViewController.h"
#import "TFPPrintJob.h"
#import "TFPPrintStatusController.h"
#import "TFPPrinterManager.h"
#import "TFPPrinter.h"


@interface TFPPrintingProgressViewController (Private)
@property TFPPrintJob *printJob;
@property TFPPrintStatusController *printStatusController;
@end


@interface TFPPrintSettingsViewController (Private)
@property TFPPrintingProgressViewController *printingProgressViewController;
@end



@implementation TFPPrintingProgressViewController (AppleScriptSupport)

- (double)printingProgress {
	return (double)self.printJob.completedRequests / self.printJob.program.lines.count;
}

@end



@implementation TFPPrintSettingsViewController (AppleScriptSupport)

- (BOOL)printing {
	return self.printingProgressViewController != nil;
}

@end



@implementation NSApplication (AppleScriptSupport)


- (NSArray*)scripting_printers {
	return [TFPPrinterManager sharedManager].printers;
}

@end


@implementation TFPPrinter (AppleScriptSupport)

- (NSScriptObjectSpecifier *)objectSpecifier {
	NSScriptObjectSpecifier *containerRef = [[NSApplication sharedApplication] objectSpecifier];
	NSArray *printers = [TFPPrinterManager sharedManager].printers;
	NSUInteger printerIndex = [printers indexOfObject:self];
	
	return [[NSIndexSpecifier alloc] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"printers" index:printerIndex];
}

@end