//
//  TFPVisualPrintProgressView.h
//  microprint
//
//  Created by Tomas Franzén on Sat 2015-08-08.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class TFPPrintStatusController, TFPPrintParameters;


@interface TFPVisualPrintProgressView : NSView
@property CGSize fullViewSize;

- (void)configureWithPrintStatusController:(TFPPrintStatusController*)statusController parameters:(TFPPrintParameters*)printParameters;
@end