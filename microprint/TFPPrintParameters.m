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


@end


NSString *TFPBedLevelOffsetsDescription(TFPBedLevelOffsets offsets) {
	return [NSString stringWithFormat:@"{ Z: %.02f, BL: %.02f, BR: %.02f, FL: %.02f, FR: %.02f }",
			offsets.common,
			offsets.backLeft,
			offsets.backRight,
			offsets.frontLeft,
			offsets.frontRight
			];
}


NSString *TFPBacklashValuesDescription(TFPBacklashValues values) {
	return [NSString stringWithFormat:@"{ X: %.02f, Y: %.02f }",
			values.x,
			values.y
			];
}