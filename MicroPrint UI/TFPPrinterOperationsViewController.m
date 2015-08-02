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


@interface TFPPrinterOperationsViewController ()
@property IBOutletCollection (NSButton) NSArray *actionButtons;
@property NSArray *actionButtonTitles;

@property IBOutlet NSButton *retractButton;
@property IBOutlet NSButton *extrudeButton;
@property IBOutlet NSButton *raiseButton;
@property IBOutlet NSButton *closeButton;
@property IBOutlet NSButton *zeroHeadButton;
@property IBOutlet NSButton *zeroHeadHelpButton;

@property IBOutlet NSProgressIndicator *progressIndicator;
@property IBOutlet NSTextField *statusLabel;

@property TFPOperation *operation;
@end


@implementation TFPPrinterOperationsViewController


- (void)startRetract:(BOOL)retract {
	__weak __typeof__(self) weakSelf = self;
	
	TFPExtrusionOperation *operation = [[TFPExtrusionOperation alloc] initWithPrinter:self.printer retraction:retract];
	__weak TFPExtrusionOperation *weakOperation = operation;
	self.operation = operation;
	
	operation.movingStartedBlock = ^{
		weakSelf.statusLabel.stringValue = @"Raising head…";
		[weakSelf.progressIndicator setIndeterminate:YES];
		[weakSelf.progressIndicator startAnimation:nil];
	};
	
	operation.heatingStartedBlock = ^{
		weakSelf.statusLabel.stringValue = @"Heating up…";
	};
	
	operation.heatingProgressBlock = ^(double temperature){
		[weakSelf.progressIndicator setIndeterminate:NO];
		weakSelf.progressIndicator.doubleValue = temperature / weakOperation.temperature;
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

- (void)zeroHead {
    __weak __typeof__(self) weakSelf = self;
    TFPZeroBedOperation *operation = [[TFPZeroBedOperation alloc] initWithPrinter:self.printer];
    self.operation = operation;

    operation.prepStartedBlock = ^{
        weakSelf.statusLabel.stringValue = @"Preparing — warming print head";
        [weakSelf.progressIndicator setIndeterminate:YES];
        [weakSelf.progressIndicator startAnimation:nil];
    };
    
    operation.zeroStartedBlock = ^{
        weakSelf.statusLabel.stringValue = @"Zeroing — This may take two or three minutes.";
    };

    operation.parkStartedBlock = ^{
        weakSelf.statusLabel.stringValue = @"Parking…";
    };

    operation.didStopBlock = ^{
        [weakSelf operationDidStop];
    };

    self.statusLabel.stringValue = @"Starting…";
    [operation start];
}

- (void)showZeroHelp {

    NSAlert *helpWindow;

    NSArray *helpMessageLines = @[
                @"The Find Bed Zero operation ensures that the print head zero Z position is right on the print bed.",
                @"",
                @"The printer must be on a stable surface and remain undisturbed throughout the entire operation.",
                @"",
                @"This will not change your Bed Height Offset settings.",
                ];

    NSString *helpMessage = [helpMessageLines componentsJoinedByString:@"\n"];

    helpWindow = [[NSAlert alloc] init];
    helpWindow.alertStyle = NSInformationalAlertStyle;
    helpWindow.messageText = @"Find Bed Zero";
    helpWindow.informativeText = helpMessage;
    [helpWindow runModal];
}


- (void)viewDidLoad {
	[super viewDidLoad];
	self.actionButtons = @[self.retractButton,
                           self.extrudeButton,
                           self.raiseButton,
                           self.zeroHeadButton];
	self.actionButtonTitles = [self.actionButtons valueForKey:@"title"];
}


- (IBAction)buttonAction:(id)sender {
    if (sender == self.zeroHeadHelpButton) {    // Help window is modal so no need to disable the buttons
        [self showZeroHelp];
    }else{
        if(self.operation) {
            [self.operation stop];
            self.statusLabel.stringValue = @"Stopping…";
        }else{
			if(self.printer.currentOperation) {
				return;
			}
			
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

            }else if(sender == self.zeroHeadButton) {
                [self zeroHead];
                
            }
        }
    }
}


@end