//
//  TFPPrintJob.h
//  MicroPrint
//
//  Created by Tomas Franzén on Thu 2015-06-25.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TFPGCodeProgram.h"
#import "TFPPrintParameters.h"
#import "TFPOperation.h"


@interface TFPPrintJob : TFPOperation
- (instancetype)initWithProgram:(TFPGCodeProgram*)program printer:(TFPPrinter*)printer printParameters:(TFPPrintParameters*)params;

@property (readonly) TFPGCodeProgram *program;

@property (readonly) NSUInteger completedRequests; //Observable
@property (readonly) NSTimeInterval elapsedTime;

@property (copy) void(^progressBlock)(void);
@property (copy) void(^completionBlock)(void);
@property (copy) void(^abortionBlock)(void);
@property (copy) void(^heatingProgressBlock)(double targetTemperature, double currentTemperature);

- (void)start;
- (void)abort;
@end