//
//  TFGCodeProgram.h
//  MicroPrint
//

@import Foundation;
@class TFP3DVector;

@interface TFPGCodeProgram : NSObject
- (instancetype)initWithLines:(NSArray*)lines;
- (instancetype)initWithString:(NSString*)string;
- (instancetype)initWithFileURL:(NSURL*)URL;

- (BOOL)writeToFileURL:(NSURL*)URL error:(NSError**)outError;
- (NSString *)ASCIIRepresentation;

- (TFPGCodeProgram*)programByStrippingNonFieldCodes;
- (TFP3DVector*)measureSize;

@property (copy, readonly) NSArray *lines;
@end