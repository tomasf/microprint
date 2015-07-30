//
//  TFPPrinterListCollectionView.m
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-30.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrinterListCollectionView.h"

@implementation TFPPrinterListCollectionView

- (NSCollectionViewItem *)newCollectionViewItem {
	return [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"printerItemPrototype"];
}

@end
