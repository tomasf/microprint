//
//  TFPPrinterCollectionViewItem.m
//  microprint
//
//  Created by Tomas Franzén on Tue 2015-07-14.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrinterCollectionViewItem.h"
#import "TFPPrinterOperationsViewController.h"

@interface TFPPrinterCollectionViewItem ()
@property NSPopover *filamentPopover;
@end


@implementation TFPPrinterCollectionViewItem


- (IBAction)showFilamentOptions:(NSButton*)button {
	if(!self.filamentPopover) {
		TFPPrinterOperationsViewController *viewController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"extrusionViewController"];
		viewController.printer = self.representedObject;
	
		self.filamentPopover = [NSPopover new];
		self.filamentPopover.contentViewController = viewController;
		self.filamentPopover.behavior = NSPopoverBehaviorTransient;
	}
	[self.filamentPopover showRelativeToRect:button.bounds ofView:button preferredEdge:CGRectMaxYEdge];
}


@end
