//
//  TFPRaiseHeadOperation.h
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

@import Foundation;
#import "TFPPrinter.h"

@interface TFPRaiseHeadOperation : NSObject
- (instancetype)initWithPrinter:(TFPPrinter*)printer;

@property double targetHeight;

- (void)start;
@end