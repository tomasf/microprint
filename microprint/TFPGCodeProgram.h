//
//  TFGCodeProgram.h
//  MicroPrint
//

@import Foundation;
@class TFP3DVector, TFPGCode;


@interface TFPGCodeProgram : NSObject
+ (instancetype)programWithLines:(NSArray<TFPGCode *> *)lines;
- (instancetype)initWithLines:(NSArray<TFPGCode *> *)lines;
- (instancetype)initWithString:(NSString*)string error:(NSError**)outError;
- (instancetype)initWithFileURL:(NSURL*)URL error:(NSError**)outError;

@property (copy, readonly) NSArray<TFPGCode *> *lines;

- (BOOL)writeToFileURL:(NSURL*)URL error:(NSError**)outError;
- (NSString *)ASCIIRepresentation;
@end