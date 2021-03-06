//
//  TFPPrinterHelpers.h
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-08-02.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrinter.h"

@interface TFPPrinter (CommandHelpers)
- (void)setBacklashValues:(TFPBacklashValues)values completionHandler:(void(^)(BOOL success))completionHandler;
- (void)fetchPositionWithCompletionHandler:(void(^)(BOOL success, TFP3DVector *position, NSNumber *E))completionHandler;
@end



@interface TFPPrinterContext (CommandHelpers)
- (void)setRelativeMode:(BOOL)relative completionHandler:(void(^)(BOOL success))completionHandler;
- (void)moveToPosition:(TFP3DVector*)position usingFeedRate:(double)F completionHandler:(void(^)(BOOL success))completionHandler;
- (void)waitForExecutionCompletionWithHandler:(void(^)())completionHandler;

- (void(^)())setHeaterTemperatureAsynchronously:(double)targetTemperature progressBlock:(void(^)(double currentTemperature))progressBlock completionBlock:(void(^)())completionBlock;

- (void(^)())moveAsynchronouslyToPosition:(TFP3DVector*)targetPosition feedRate:(double)feedRate progressBlock:(void(^)(double fraction, TFP3DVector *position))progressBlock completionBlock:(void(^)())completionBlock;
@end