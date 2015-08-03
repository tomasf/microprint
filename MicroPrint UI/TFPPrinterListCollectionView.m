//
//  TFPPrinterListCollectionView.m
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-30.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrinterListCollectionView.h"

@implementation TFPPrinterListCollectionView

- (NSCollectionViewItem *)newItemForRepresentedObject:(id)object {
	NSCollectionViewItem *item = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"printerItemPrototype"];
	item.representedObject = object;
	return item;
}

@end
