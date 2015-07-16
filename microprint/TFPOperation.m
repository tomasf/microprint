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


- (void)start {
	self.printer.currentOperation = self;
}


- (void)ended {
	self.printer.currentOperation = nil;
}


- (void)stop {
	
}

@end