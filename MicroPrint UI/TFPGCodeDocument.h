//
//  TFPGCodeDocument.h
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-07-13.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TFPFilament.h"
@class TFP3DVector, TFPPrinter;

@interface TFPGCodeDocument : NSDocument
@property (readonly) TFP3DVector *printSize;
@property (readonly) NSDictionary *curaProfile;

@property TFPPrinter *selectedPrinter;
@property TFPFilamentType filamentType;
@property NSNumber *temperature;
@property BOOL useWaveBonding;
@end