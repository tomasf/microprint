//
//  TFPRepeatingCommandSender.h
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

@import Foundation;
#import "TFPOperation.h"


@interface TFPRepeatingCommandSender : TFPOperation
- (void)start;

@property (copy) TFPGCode*(^nextCodeBlock)();
@property (copy) void(^stoppingBlock)();
@property (copy) void(^endedBlock)();
@end
