//
//  TFPConsoleViewController.m
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-30.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPConsoleViewController.h"
#import "TFPExtras.h"

#define consoleMax 100000
#define consoleTrim consoleMax / 10

@interface TFPConsoleViewController ()
@property IBOutlet NSTextView *textView;
@property IBOutlet NSTextField *inputField;
@property unsigned long consoleLength;
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

    self.consoleLength += attributedString.length;

    if (self.consoleLength > consoleMax) {
        [self.textView.textStorage deleteCharactersInRange: NSMakeRange(0, consoleTrim)];
        self.consoleLength = self.textView.textStorage.length;
    }
}


- (void)viewDidAppear {
	[super viewDidAppear];
	__weak __typeof__(self) weakSelf = self;

    self.consoleLength = 0;
	
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
	__block BOOL valid = YES;
	
	NSArray *codes = [[self.inputField.stringValue componentsSeparatedByString:@"\n"] tf_mapWithBlock:^TFPGCode*(NSString *line) {
		TFPGCode *code = [TFPGCode codeWithString:line];
		if(!code) {
			valid = NO;
		}
		return code;
	}];
	
	if(codes) {
		[self.printer runGCodeProgram:[TFPGCodeProgram programWithLines:codes] completionHandler:nil];
		self.inputField.stringValue = @"";
	} else {
		NSBeep();
	}
}


- (IBAction)clearLog:(id)sender {
	[self.textView setString:@""];
}


@end
