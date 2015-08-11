//
//  TFGCodeProgram.h
//  MicroPrint
//

@import Foundation;
@class TFP3DVector;


@interface TFPGCodeProgram : NSObject
+ (instancetype)programWithLines:(NSArray*)lines;
- (instancetype)initWithLines:(NSArray*)lines;
- (instancetype)initWithString:(NSString*)string error:(NSError**)outError;
- (instancetype)initWithFileURL:(NSURL*)URL error:(NSError**)outError;

@property (copy, readonly) NSArray *lines;

- (BOOL)writeToFileURL:(NSURL*)URL error:(NSError**)outError;
- (NSString *)ASCIIRepresentation;
@end