//
//  TFDataBuilder.h
//  MicroPrint
//
//  Created by Tomas Franzén on Mon 2015-06-22.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSUInteger, TFDataBuilderByteOrder) {
	TFDataBuilderByteOrderBigEndian,
	TFDataBuilderByteOrderLittleEndian,
};


@interface TFDataBuilder : NSObject
- (instancetype)initWithData:(NSData*)existingData;

@property TFDataBuilderByteOrder byteOrder;

- (void)appendData:(NSData*)data;
- (void)appendBytes:(const void *)bytes length:(NSUInteger)length;
- (void)appendString:(NSString*)string; // UTF-8
- (void)appendString:(NSString*)string encoding:(NSStringEncoding)encoding;

- (void)appendByte:(uint8_t)byte;
- (void)appendInt16:(uint16_t)int16;
- (void)appendInt32:(uint32_t)int32;
- (void)appendInt64:(uint64_t)int64;

- (void)appendFloat:(float)value;
- (void)appendDouble:(double)value;

@property (readonly) NSMutableData *data;
@end
