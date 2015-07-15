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

@interface TFPPrinterListViewController ()
@property IBOutlet NSCollectionView *collectionView;
@property TFPPrinterManager *printerManager;
@end



@implementation TFPPrinterListViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.collectionView.itemPrototype = [self.storyboard instantiateControllerWithIdentifier:@"printerItemPrototype"];
	self.collectionView.maxItemSize = CGSizeMake(0, 100);
	
	self.printerManager = [TFPPrinterManager sharedManager];
	
	[self.printerManager setValue:@[[TFPDryRunPrinter new]] forKey:@"printers"];
}

@end
