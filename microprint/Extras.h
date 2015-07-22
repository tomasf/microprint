//
//  Extras.h
//  MicroPrint
//
//

@import Foundation;
@import CoreGraphics;
#import "ORSSerialPort.h"


@interface NSArray (TFExtras)
- (NSArray*)tf_mapWithBlock:(id(^)(id object))function;
- (NSArray*)tf_selectWithBlock:(BOOL(^)(id object))function;
- (NSArray*)tf_rejectWithBlock:(BOOL(^)(id object))function;
- (NSSet*)tf_set;
@end


@interface NSDecimalNumber (TFExtras)
@property (readonly) NSDecimalNumber *tf_squareRoot;
@property (readonly) BOOL tf_nonZero;
@end


@interface NSData (TFExtras)
@property (readonly) NSData *tf_fletcher16Checksum;
- (NSUInteger)tf_indexOfData:(NSData*)subdata;
@end


@interface ORSSerialPort (TFExtras)
- (BOOL)getUSBVendorID:(uint16_t*)vendorID productID:(uint16_t*)productID;
@end


@interface NSIndexSet (TFExtras)
+ (NSIndexSet*)tf_indexSetWithIndexes:(NSInteger)firstIndex, ...; // Terminate with negative
@end


extern NSString *const TFPErrorDomain;
extern NSString *const TFPErrorGCodeStringKey;
extern NSString *const TFPErrorGCodeKey;
extern NSString *const TFPErrorGCodeLineKey;


enum TFPErrorCodes {
	TFPErrorCodeParseError = 1,
	TFPErrorCodeIncompatibleCode,
};


extern void TFLog(NSString *format, ...);
extern uint64_t TFNanosecondTime(void);

extern CGFloat TFPVectorDot(CGVector a, CGVector b);

extern void TFPListenForInputLine(void(^block)(NSString *line));
extern NSString *TFPGetInputLine();
extern void TFPEraseLastLine();