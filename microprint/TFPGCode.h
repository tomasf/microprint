//
//  TFGCodeLine.h
//  MicroPrint
//
//

#import <Foundation/Foundation.h>
#import "TFP3DVector.h"

@interface TFPGCode : NSObject
+ (instancetype)codeWithString:(NSString*)string;
- (instancetype)initWithString:(NSString*)string;

+ (instancetype)codeWithField:(char)field value:(double)value;

- (TFPGCode*)codeBySettingField:(char)field toValue:(double)value;
- (TFPGCode*)codeByAdjustingField:(char)field offset:(double)offset;

@property (readonly, copy) NSString *comment;

- (BOOL)hasField:(char)field;
- (double)valueForField:(char)field;
- (double)valueForField:(char)field fallback:(double)fallbackValue;

@property (readonly) TFP3DVector *movementVector;

@property (readonly) BOOL hasFields;

@property (readonly) BOOL hasExtrusion;
@property (readonly) double extrusion;

@property (readonly) double feedRate;
@property (readonly) BOOL hasFeedRate;

@property (readonly) NSData *repetierV2Representation;
@property (readonly) NSString *ASCIIRepresentation;
@end
