//
//  TFPOperation.h
//  microprint
//
//  Created by Tomas Franzén on Sat 2015-07-11.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

@import Foundation;
#import "TFPPrinter.h"


// Make sure these ones are in sync with MicroPrint.sdef

typedef NS_ENUM(NSUInteger, TFPOperationKind) {
	TFPOperationKindIdle = 'idle',
	TFPOperationKindPrintJob = 'prjb',
	TFPOperationKindCalibration = 'clbr',
	TFPOperationKindUtility = 'util',
};

typedef NS_ENUM(NSUInteger, TFPOperationStage) {
	TFPOperationStageIdle = 'idle',
	TFPOperationStagePreparation = 'prep',
	TFPOperationStageRunning = 'rung',
	TFPOperationStageEnding = 'endg',
};


@interface TFPOperation : NSObject
- (instancetype)initWithPrinter:(TFPPrinter*)printer;

@property (readonly, weak) TFPPrinter *printer;
@property (readonly) NSString *activityDescription;

@property (readonly) TFPOperationKind kind;
@property (readonly) TFPOperationStage stage;

@property (readonly) TFPPrinterContext *context;
// Override these to customize context:
@property (readonly) TFPPrinterContextOptions printerContextOptions;
@property (readonly) dispatch_queue_t printerContextQueue;

- (BOOL)start;
- (void)stop;
- (void)ended;
@end
