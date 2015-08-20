//
//  TFPOperation.m
//  microprint
//
//  Created by Tomas Franzén on Sat 2015-07-11.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPOperation.h"

@interface TFPOperation ()
@property (readwrite, weak) TFPPrinter *printer;
@property (readwrite) TFPPrinterContext *context;
@end


@implementation TFPOperation


- (instancetype)initWithPrinter:(TFPPrinter*)printer {
	if(!(self = [super init])) return nil;
	
	self.printer = printer;
	
	return self;
}


- (NSString *)activityDescription {
	return @"Doing stuff";
}


- (BOOL)start {
	self.context = [self.printer acquireContextWithOptions:[self printerContextOptions] queue:[self printerContextQueue]];
	
	if(self.context) {
		self.printer.currentOperation = self;
		return YES;
	} else {
		return NO;
	}
}


- (void)ended {
	self.printer.currentOperation = nil;
	[self.context invalidate];
}


- (void)stop {
	
}


- (TFPOperationKind)kind {
	return TFPOperationKindIdle;
}


- (TFPOperationStage)stage {
	return TFPOperationStageRunning;
}


- (TFPPrinterContextOptions)printerContextOptions {
	return 0;
}


- (dispatch_queue_t)printerContextQueue {
	return nil;
}


@end