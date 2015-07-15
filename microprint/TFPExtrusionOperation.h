//
//  TFPExtrusionOperation.h
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TFPOperation.h"


@interface TFPExtrusionOperation : TFPOperation
- (instancetype)initWithPrinter:(TFPPrinter*)printer retraction:(BOOL)retract;

@property double temperature;

@property (copy) void(^movingStartedBlock)();
@property (copy) void(^heatingStartedBlock)();
@property (copy) void(^heatingProgressBlock)(double temperature);
@property (copy) void(^extrusionStartedBlock)();
@property (copy) void(^extrusionStoppedBlock)();

- (void)start;
- (void)stop;
@end