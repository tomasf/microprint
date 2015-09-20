//
//  TFPGCodeDocument.h
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-07-13.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TFPFilament.h"
#import "TFPGCodeHelpers.h"
#import "TFPSlicerProfile.h"

@class TFP3DVector, TFPPrinter;


@interface TFPGCodeDocument : NSDocument
@property TFPGCodeProgram *program;

@property (readonly) BOOL hasBoundingBox;
@property (readonly) TFPCuboid boundingBox;
@property (readonly) TFPSlicerProfile *slicerProfile;

@property TFPFilamentType filamentType;
@property NSNumber *temperature;
@property BOOL useThermalBonding;

@property TFPPrinter *selectedPrinter;
@property NSURL *completionScriptURL;

- (void)saveSettings;
@end