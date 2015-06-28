//
//  TFPExtrusionOperation.h
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TFPPrinter.h"


@interface TFPExtrusionOperation : NSObject
- (instancetype)initWithPrinter:(TFPPrinter*)printer retraction:(BOOL)retract;

@property double temperature;

- (void)start;
@end
