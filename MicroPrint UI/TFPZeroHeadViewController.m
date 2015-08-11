//
//  TFPZeroHeadViewController.m
//  microprint
//
//  Created by William Waggoner on 8/1/15.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPZeroHeadViewController.h"
#import "TFPZeroBedOperation.h"
#import "TFPExtras.h"

@interface TFPZeroHeadViewController ()
@property IBOutlet NSTextField* txtHelp;
@property IBOutlet NSButton* startButton;
@property IBOutlet NSProgressIndicator *progressIndicator;
@property IBOutlet NSTextField *statusLabel;
@property TFPZeroBedOperation* operation;
@end

@implementation TFPZeroHeadViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    self.operation = nil;
}


- (void)start {
    __weak __typeof__(self) weakSelf = self;
    TFPZeroBedOperation *operation = [[TFPZeroBedOperation alloc] initWithPrinter:self.printer];
    self.operation = operation;

    operation.progressFeedback = ^(NSString *msg){
        weakSelf.statusLabel.stringValue = msg;
    };

    operation.didStopBlock = ^(BOOL completed){
        [weakSelf operationDidStop];
		
		if(completed) {
			NSAlert *alert = [NSAlert new];
			alert.messageText = @"Bed location calibration finished";
			alert.informativeText = @"You should now run the Bed Level Calibration to make sure corner levels are correct.";
			[alert addButtonWithTitle:@"OK"];
			
			[alert beginSheetModalForWindow:weakSelf.view.window completionHandler:^(NSModalResponse returnCode) {
				[weakSelf dismissController:nil];
			}];
		}
    };

    [operation start];
}

- (IBAction)buttonPressed:(id)sender {

    if(sender == self.startButton) {
        if(self.operation) {
            [self.operation stop];
        }else{
            self.statusLabel.hidden = NO;
            self.progressIndicator.hidden = NO;
            self.statusLabel.stringValue = @"Starting…";
            [self.progressIndicator setIndeterminate:YES];
            [self.progressIndicator startAnimation:nil];
            self.startButton.title = @"Stop";
            self.startButton.keyEquivalent = @"\r";
            [self start];
        }
    }
}

- (void)operationDidStop {
    self.operation = nil;
    self.statusLabel.stringValue = @"";
    [self.progressIndicator stopAnimation:nil];
    self.statusLabel.hidden = YES;
    self.progressIndicator.hidden = YES;
    self.startButton.title = @"Start";
    self.startButton.keyEquivalent = @"";
}

@end
