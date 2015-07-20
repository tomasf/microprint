//
//  TFPBedLevelCalibrationViewController.h
//  microprint
//
//  Created by Tomas Franzén on Sat 2015-07-18.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class TFPPrinter;
@class TFPBedLevelSettingsViewController;

@interface TFPBedLevelCalibrationViewController : NSViewController
@property TFPPrinter *printer;
@property (weak) TFPBedLevelSettingsViewController *bedLevelSettingsViewController;
@end
