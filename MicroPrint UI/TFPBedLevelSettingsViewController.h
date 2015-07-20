//
//  TFPBedLevelSettingsViewController.h
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-16.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

@import AppKit;
#import "TFPPrinter.h"

@interface TFPBedLevelSettingsViewController : NSViewController
@property TFPPrinter *printer;
- (void)reload;
@end
