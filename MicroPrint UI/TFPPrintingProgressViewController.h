//
//  TFPPrintingProgressViewController.h
//  microprint
//
//  Created by Tomas Franzén on Tue 2015-07-14.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class TFPGCodeProgram, TFPPrinter, TFPPrintParameters;

@interface TFPPrintingProgressViewController : NSViewController
@property TFPGCodeProgram *program;
@property TFPPrinter *printer;
@property TFPPrintParameters *printParameters;

@property (weak) NSWindow *parentWindow;

- (void)start;
@end