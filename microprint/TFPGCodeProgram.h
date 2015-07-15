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

@property (copy, readonly) NSArray *lines;

- (BOOL)writeToFileURL:(NSURL*)URL error:(NSError**)outError;
- (NSString *)ASCIIRepresentation;
@end