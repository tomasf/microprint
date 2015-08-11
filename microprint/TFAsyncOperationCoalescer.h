//
//  TFAsyncOperationCoalescer.h
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-08-09.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TFAsyncOperationCoalescer : NSObject
@property (copy) void(^completionBlock)();
@property (copy) void(^progressUpdateBlock)(double progress);

- (void(^)(double progress))addOperation;
@end
