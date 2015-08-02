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


- (void)appendLine:(NSString*)line attributes:(NSDictionary*)attrs {
	line = [line stringByAppendingString:@"\n"];
	NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:line attributes:attrs];
	[self.textView.textStorage appendAttributedString:attributedString];

	[self.textView scrollRangeToVisible: NSMakeRange(self.textView.string.length, 0)];
}


- (void)viewDidAppear {
	[super viewDidAppear];
	__weak __typeof__(self) weakSelf = self;
	
	NSDictionary *incomingAttributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:13]};
	NSDictionary *outgoingAttributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo-Bold" size:13]};
	NSDictionary *noticeAttributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo-Italic" size:13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.625 green:0.000 blue:0.026 alpha:1.000]};
	
	self.printer.incomingCodeBlock = ^(NSString *line) {
		[weakSelf appendLine:line attributes:incomingAttributes];
	};
	self.printer.outgoingCodeBlock = ^(NSString *line) {
		[weakSelf appendLine:line attributes:outgoingAttributes];
	};
	self.printer.noticeBlock = ^(NSString *line) {
		[weakSelf appendLine:line attributes:noticeAttributes];
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
