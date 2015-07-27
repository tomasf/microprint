//
//  ViewController.m
//  MicroPrint UI
//
//  Created by Tomas Franzén on Mon 2015-07-13.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrinterListViewController.h"
#import "TFPPrinterManager.h"
#import "TFPDryRunPrinter.h"
#import "TFPApplicationDelegate.h"
#import "Extras.h"


@interface TFPPrinterListViewController () <NSMenuDelegate>
@property IBOutlet NSCollectionView *collectionView;
@property TFPPrinterManager *printerManager;

@property IBOutlet NSPopUpButton *recentsButton;
@end



@implementation TFPPrinterListViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.collectionView.itemPrototype = [self.storyboard instantiateControllerWithIdentifier:@"printerItemPrototype"];
	self.collectionView.maxItemSize = CGSizeMake(0, 100);
	
	self.printerManager = [TFPPrinterManager sharedManager];
}


- (void)openRecentDocument:(NSMenuItem*)menuItem {
	NSURL *URL = menuItem.representedObject;
	[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:URL display:YES completionHandler:nil];
}


- (void)menuNeedsUpdate:(NSMenu *)menu {
	[menu removeAllItems];
	
	NSMenuItem *titleItem = [[NSMenuItem alloc] initWithTitle:@"Recent Files" action:nil keyEquivalent:@""];
	[menu addItem:titleItem];

	NSArray *newItems = [[[NSDocumentController sharedDocumentController] recentDocumentURLs] tf_mapWithBlock:^NSMenuItem*(NSURL *URL) {
		NSDictionary *resourceValues = [URL resourceValuesForKeys:@[NSURLEffectiveIconKey, NSURLLocalizedNameKey] error:nil];
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:resourceValues[NSURLLocalizedNameKey] action:@selector(openRecentDocument:) keyEquivalent:@""];
		item.target = self;
		item.representedObject = URL;
		
		NSImage *image = [resourceValues[NSURLEffectiveIconKey] copy];
		image.size = CGSizeMake(16, 16);
		item.image = image;
		
		return item;
	}];
 
	for(NSMenuItem *newItem in newItems){
		[menu addItem:newItem];
	}
}


@end
