//
//  TFPTestBorderProgressViewController.m
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-07-20.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPTestBorderProgressViewController.h"
#import "TFPPrintJob.h"
#import "TFPTestBorderPrinting.h"
#import "TFPPreprocessing.h"

@interface TFPTestBorderProgressViewController ()
@property TFPPrintJob *printJob;
@property IBOutlet NSTextField *statusLabel;
@end


@implementation TFPTestBorderProgressViewController


- (void)viewDidAppear {
	[super viewDidAppear];
	__weak __typeof__(self) weakSelf = self;
	
	TFPPrintParameters *params = [TFPPrintParameters new];
	[self.printer fillInOffsetAndBacklashValuesInPrintParameters:params completionHandler:^(BOOL success) {
		TFPGCodeProgram *program = [TFPPreprocessing programByPreprocessingProgram:[TFPTestBorderPrinting testBorderProgram] usingParameters:params];
		
		self.printJob = [[TFPPrintJob alloc] initWithProgram:program printer:self.printer printParameters:params];
		
		self.printJob.abortionBlock = ^{
			[weakSelf dismissController:nil];
		};
		
		self.printJob.completionBlock = ^{
			[weakSelf dismissController:nil];
		};
		
		[self.printJob start];
	}];
}


- (IBAction)cancel:(id)sender {
	[self.printJob abort];
	self.statusLabel.stringValue = @"Stopping…";
}


@end