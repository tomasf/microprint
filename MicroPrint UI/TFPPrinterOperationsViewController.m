//
//  TFPFilamentOperationsViewController.m
//  microprint
//
//  Created by Tomas Franzén on Tue 2015-07-14.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrinterOperationsViewController.h"
#import "TFPExtrusionOperation.h"
#import "TFPRaiseHeadOperation.h"
#import "TFPZeroBedOperation.h"
#import "TFPExtras.h"


@interface TFPPrinterOperationsViewController ()
@property IBOutletCollection (NSButton) NSArray *actionButtons;
@property NSArray *actionButtonTitles;

@property IBOutlet NSButton *retractButton;
@property IBOutlet NSButton *extrudeButton;
@property IBOutlet NSButton *raiseButton;
@property IBOutlet NSButton *closeButton;

@property IBOutlet NSProgressIndicator *progressIndicator;
@property IBOutlet NSTextField *statusLabel;

@property TFPOperation *operation;
@end


@implementation TFPPrinterOperationsViewController


- (void)startRetract:(BOOL)retract {
	__weak __typeof__(self) weakSelf = self;
	
	TFPExtrusionOperation *operation = [[TFPExtrusionOperation alloc] initWithPrinter:self.printer retraction:retract];
	self.operation = operation;
	self.progressIndicator.hidden = NO;
	[weakSelf.progressIndicator setIndeterminate:NO];
	[weakSelf.progressIndicator startAnimation:nil];
	weakSelf.statusLabel.stringValue = @"Preparing…";

	operation.preparationProgressBlock = ^(double fraction){
		weakSelf.progressIndicator.doubleValue = fraction;
	};
	
	operation.extrusionStartedBlock = ^() {
		[weakSelf.progressIndicator setIndeterminate:YES];
		weakSelf.statusLabel.stringValue = retract ? @"Retracting" : @"Extruding";
	};
	
	operation.extrusionStoppedBlock = ^() {
		[weakSelf operationDidStop];
	};
	
	[operation start];
}


- (void)operationDidStop {
	self.operation = nil;
	self.statusLabel.stringValue = @"";
	[self.progressIndicator stopAnimation:nil];
	self.progressIndicator.hidden = YES;

	[self.actionButtons enumerateObjectsUsingBlock:^(NSButton *button, NSUInteger index, BOOL *stop) {
		button.enabled = YES;
		button.title = self.actionButtonTitles[index];
		button.keyEquivalent = @"";
	}];
	self.closeButton.enabled = YES;
}


- (void)raise {
	__weak __typeof__(self) weakSelf = self;
	TFPRaiseHeadOperation *operation = [[TFPRaiseHeadOperation alloc] initWithPrinter:self.printer];
	operation.targetHeight = 70;
	self.progressIndicator.hidden = NO;

	self.operation = operation;
	
	operation.didStartBlock = ^{
		weakSelf.statusLabel.stringValue = @"Raising…";
		[weakSelf.progressIndicator setIndeterminate:YES];
		[weakSelf.progressIndicator startAnimation:nil];
	};
	
	operation.didStopBlock = ^(BOOL didMove){
		[weakSelf operationDidStop];
	};
	
	weakSelf.statusLabel.stringValue = @"Starting…";
	[operation start];
}


- (void)viewDidLoad {
	[super viewDidLoad];
	self.actionButtons = @[self.retractButton,
                           self.extrudeButton,
                           self.raiseButton,
                           ];
	self.actionButtonTitles = [self.actionButtons valueForKey:@"title"];
}


- (void)viewDidAppear {
	[super viewDidAppear];
	self.view.window.styleMask &= ~NSResizableWindowMask;
}


- (IBAction)buttonAction:(id)sender {
    if(self.operation) {
        [self.operation stop];
        self.statusLabel.stringValue = @"Stopping…";
    }else{
        for(NSButton *button in self.actionButtons) {
            if(button != sender) {
                button.enabled = NO;
            }else{
                button.title = @"Stop";
                button.keyEquivalent = @"\r";
            }
        }
        self.closeButton.enabled = NO;

        if(sender == self.retractButton) {
            [self startRetract:YES];

        }else if(sender == self.extrudeButton) {
            [self startRetract:NO];

        }else if(sender == self.raiseButton) {
            [self raise];
        }
    }
}


@end