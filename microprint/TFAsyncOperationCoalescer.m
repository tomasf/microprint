//
//  TFAsyncOperationCoalescer.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-08-09.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFAsyncOperationCoalescer.h"

@interface TFAsyncOperationCoalescer ()
@property NSMutableDictionary *operationProgress;
@property NSUInteger operationCount;
@end


@implementation TFAsyncOperationCoalescer


- (instancetype)init {
	if(!(self = [super init])) return nil;
	
	self.operationProgress = [NSMutableDictionary new];
	
	return self;
}


- (void)updateProgress {
	double sum = 0;
	BOOL anyIncomplete = NO;
	for(NSNumber *ID in self.operationProgress) {
		double value = [self.operationProgress[ID] doubleValue];
		if(value < 1) {
			anyIncomplete = YES;
		}
		sum += value;
	}
	
	if(!anyIncomplete) {
		self.completionBlock();
	}else{
		if(self.progressUpdateBlock) {
			self.progressUpdateBlock(sum / self.operationProgress.count);
		}
	}
}


- (void(^)(double progress))addOperation {
	NSUInteger ID = self.operationCount++;
	self.operationProgress[@(ID)] = @0;
	
	return ^(double progress){
		if(progress >= 1) {
			self.operationProgress[@(ID)] = @1;
		}else{
			self.operationProgress[@(ID)] = @(progress);
		}
		[self updateProgress];
	};
}


@end
