//
//  TFGCodeProgram.h
//  MicroPrint
//

@import Foundation;
@class TFP3DVector;


typedef struct {
	double x;
	double y;
	double z;
	double e;
} TFPAbsolutePosition;



@interface TFPGCodeProgram : NSObject
+ (instancetype)programWithLines:(NSArray*)lines;
- (instancetype)initWithLines:(NSArray*)lines;
- (instancetype)initWithString:(NSString*)string;
- (instancetype)initWithFileURL:(NSURL*)URL;

- (BOOL)writeToFileURL:(NSURL*)URL error:(NSError**)outError;
- (NSString *)ASCIIRepresentation;

- (TFPGCodeProgram*)programByStrippingNonFieldCodes;
- (TFP3DVector*)measureSize;

- (void)enumerateMovesWithBlock:(void(^)(TFPAbsolutePosition from, TFPAbsolutePosition to, double feedRate))block;

@property (copy, readonly) NSArray *lines;
@end