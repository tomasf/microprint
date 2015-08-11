//
//  TFPStopwatch.h
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-08-10.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TFPStopwatch : NSObject
- (void)start;
- (void)stop;
- (void)reset;

@property (readonly) NSTimeInterval elapsedTime;
@end
