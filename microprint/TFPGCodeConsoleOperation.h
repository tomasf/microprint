//
//  TFPGCodeConsoleOperation.h
//  microprint
//
//  Created by Tomas Franzén on Wed 2015-07-08.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

@import Foundation;
#import "TFPPrinter.h"


@interface TFPGCodeConsoleOperation : NSObject
- (instancetype)initWithPrinter:(TFPPrinter*)printer;
- (void)start;

@property BOOL convertFeedRates;
@end
