//
//  TFPRaiseHeadOperation.h
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

@import Foundation;
#import "TFPOperation.h"

@interface TFPRaiseHeadOperation : TFPOperation
@property double targetHeight;

@property (copy) void(^didStartBlock)();
@property (copy) void(^didStopBlock)(BOOL didRaise);

- (void)start;
- (void)stop;
@end