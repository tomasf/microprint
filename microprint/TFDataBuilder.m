//
//  TFDataBuilder.m
//  MicroPrint
//
//  Created by Tomas Franzén on Mon 2015-06-22.
//

#import "TFDataBuilder.h"

@interface TFDataBuilder ()
@property (readwrite) NSMutableData *data;
@end


@implementation TFDataBuilder


- (instancetype)initWithData:(NSData*)existingData {
	if(!(self = [super init])) return nil;
	
	self.data = [existingData mutableCopy] ?: [NSMutableData new];
	
	return self;
}


- (instancetype)init {
	return [self initWithData:[NSData data]];
}


- (void)appendData:(NSData*)data {
	[self.data appendData:data];
}


- (void)appendString:(NSString*)string {
	[self appendString:string encoding:NSUTF8StringEncoding];
}


- (void)appendBytes:(const void *)bytes length:(NSUInteger)length {
	[self.data appendBytes:bytes length:length];
}


- (void)appendString:(NSString*)string encoding:(NSStringEncoding)encoding {
	[self appendData:[string dataUsingEncoding:encoding]];
}


- (void)appendByte:(uint8_t)byte {
	[self.data appendBytes:&byte length:sizeof(byte)];
}


- (void)appendInt16:(uint16_t)integer {
	if(self.byteOrder == TFDataBuilderByteOrderLittleEndian) {
		integer = NSSwapHostShortToLittle(integer);
	}else{
		integer = NSSwapHostShortToBig(integer);
	}
	[self.data appendBytes:&integer length:sizeof(integer)];
}


- (void)appendInt32:(uint32_t)integer {
	if(self.byteOrder == TFDataBuilderByteOrderLittleEndian) {
		integer = NSSwapHostIntToLittle(integer);
	}else{
		integer = NSSwapHostIntToBig(integer);
	}
	[self.data appendBytes:&integer length:sizeof(integer)];
}


- (void)appendInt64:(uint64_t)integer {
	if(self.byteOrder == TFDataBuilderByteOrderLittleEndian) {
		integer = NSSwapHostLongLongToLittle(integer);
	}else{
		integer = NSSwapHostLongLongToBig(integer);
	}
	[self.data appendBytes:&integer length:sizeof(integer)];
}


- (void)appendFloat:(float)value {
	NSSwappedFloat swapped;
	if(self.byteOrder == TFDataBuilderByteOrderLittleEndian) {
		swapped = NSSwapHostFloatToLittle(value);
	}else{
		swapped = NSSwapHostFloatToBig(value);
	}
	[self.data appendBytes:&swapped length:sizeof(swapped)];
}


- (void)appendDouble:(double)value {
	NSSwappedDouble swapped;
	if(self.byteOrder == TFDataBuilderByteOrderLittleEndian) {
		swapped = NSSwapHostDoubleToLittle(value);
	}else{
		swapped = NSSwapHostDoubleToBig(value);
	}
	[self.data appendBytes:&swapped length:sizeof(swapped)];
}


@end