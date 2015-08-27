//
//  TFPZeroBedOperation.h
//  microprint
//
//  Created by William Waggoner on 7/29/15.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPOperation.h"

@interface TFPZeroBedOperation : TFPOperation
@property (copy) void(^progressFeedback)(NSString *msg);
@property (copy) void(^didStopBlock)(BOOL completed);
@end
