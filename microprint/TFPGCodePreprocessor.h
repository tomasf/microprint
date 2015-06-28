//
//  TFPGCodePreprocessor.h
//  MicroPrint
//
//  Created by Tomas Franzén on Mon 2015-06-22.
//

#import <Foundation/Foundation.h>
#import "TFPGCodeProgram.h"
#import "TFPPrintParameters.h"

@class TFPGCode;


@interface TFPGCodePreprocessor : NSObject
- (instancetype)initWithProgram:(TFPGCodeProgram*)program;
- (TFPGCodeProgram*)processUsingParameters:(TFPPrintParameters*)parameters;

@property (readonly) TFPGCodeProgram *program;

- (double)boundedTemperature:(double)temperature;
- (CGVector)CGVectorFromGCode:(TFPGCode *)code;
- (BOOL)isSharpCornerFromLine:(TFPGCode *)currLine toLine:(TFPGCode *)prevLine;
- (TFPGCode *)makeTackPointForCurrentLine:(TFPGCode *)currLine lastTackPoint:(TFPGCode *)lastTackPoint;
@end
