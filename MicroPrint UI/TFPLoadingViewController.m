//
//  TFPLoadingViewController.m
//  microprint
//
//  Created by Tomas Franzén on Wed 2015-07-15.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPLoadingViewController.h"
#import "TFPGCodeDocument.h"
#import "TFPGCodeProgram.h"
#import "TFPPrintSettingsViewController.h"


@interface TFPLoadingViewController ()
@property IBOutlet NSProgressIndicator *progressIndicator;
@end


@implementation TFPLoadingViewController


- (void)viewDidAppear {
	[super viewDidAppear];
	[self.progressIndicator startAnimation:nil];
	
	TFPGCodeDocument *document = [[NSDocumentController sharedDocumentController] documentForWindow:self.view.window];
	NSData *data = document.data;
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		TFPGCodeProgram *program = [[TFPGCodeProgram alloc] initWithString:string];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			TFPPrintSettingsViewController *viewController = [self.storyboard instantiateControllerWithIdentifier:@"printSettingsViewController"];
			viewController.program = program;
			[self.view.window setContentViewController:viewController];
		});
	});
}


@end
