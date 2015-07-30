//
//  TFPConsoleViewController.m
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-30.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPConsoleViewController.h"

@interface TFPConsoleViewController ()
@property IBOutlet NSTextView *textView;
@property IBOutlet NSTextField *inputField;
@end



@implementation TFPConsoleViewController


- (void)viewDidLoad {
    [super viewDidLoad];
	
}


- (void)appendLine:(NSString*)line outgoing:(BOOL)outgoing {
	NSFontDescriptor *descriptor = [NSFontDescriptor fontDescriptorWithFontAttributes:@{NSFontFamilyAttribute: @"Menlo"}];
	if(outgoing) {
		descriptor = [descriptor fontDescriptorWithSymbolicTraits:NSFontBoldTrait];
	}
	
	line = [line stringByAppendingString:@"\n"];
	NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:line attributes:@{NSFontAttributeName: [NSFont fontWithDescriptor:descriptor size:13]}];
	[self.textView.textStorage appendAttributedString:attributedString];

	[self.textView scrollRangeToVisible: NSMakeRange(self.textView.string.length, 0)];
}


- (void)viewDidAppear {
	[super viewDidAppear];
	__weak __typeof__(self) weakSelf = self;
	
	self.printer.incomingCodeBlock = ^(NSString *line) {
		[weakSelf appendLine:line outgoing:NO];
	};
	self.printer.outgoingCodeBlock = ^(NSString *line) {
		[weakSelf appendLine:line outgoing:YES];
	};
	
	self.textView.string = @"";
	[self.view.window makeFirstResponder:self.inputField];
}


- (void)viewDidDisappear {
	[super viewDidDisappear];
	self.printer.incomingCodeBlock = nil;
	self.printer.outgoingCodeBlock = nil;
}


- (IBAction)fieldAction:(id)sender {
	TFPGCode *code = [TFPGCode codeWithString:self.inputField.stringValue];
	if(code) {
		[self.printer sendGCode:code responseHandler:nil];
		self.inputField.stringValue = @"";
	} else {
		NSBeep();
	}
}


- (IBAction)clearLog:(id)sender {
	[self.textView setString:@""];
}


@end
