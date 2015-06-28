//
//  TFPPrintParameters.m
//  MicroPrint
//
//  Created by Tomas Franzén on Mon 2015-06-22.
//

#import "TFPPrintParameters.h"

static const NSUInteger defaultBufferSize = 6;


@implementation TFPPrintParameters


- (instancetype)init {
	if(!(self = [super init])) return nil;
	
	self.bufferSize = defaultBufferSize;
	self.useWaveBonding = NO;
	
	return self;
}


- (NSString *)bedLevelOffsetsAsString {
	return [NSString stringWithFormat:@"{ Z: %.02f, BL: %.02f, BR: %.02f, FL: %.02f, FR: %.02f }",
			self.bedLevelOffsets.common,
			self.bedLevelOffsets.backLeft,
			self.bedLevelOffsets.backRight,
			self.bedLevelOffsets.frontLeft,
			self.bedLevelOffsets.frontRight
			];
}


- (NSString *)backlashValuesAsString {
	return [NSString stringWithFormat:@"{ X: %.02f, Y: %.02f }",
			self.backlashValues.x,
			self.backlashValues.y
			];
}


@end
