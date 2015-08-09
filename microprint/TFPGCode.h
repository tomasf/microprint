//
//  TFGCodeLine.h
//  MicroPrint
//
//

#import <Foundation/Foundation.h>

@interface TFPGCode : NSObject
+ (instancetype)codeWithString:(NSString*)string;
- (instancetype)initWithString:(NSString*)string;

+ (instancetype)codeWithField:(char)field value:(double)value;
+ (instancetype)codeWithComment:(NSString*)string;

- (TFPGCode*)codeBySettingField:(char)field toValue:(double)value;
- (TFPGCode*)codeByAdjustingField:(char)field offset:(double)offset;
- (TFPGCode*)codeBySettingComment:(NSString*)comment;

@property (readonly, copy) NSString *comment;
@property (readonly) BOOL hasFields;
- (void)enumerateFieldsWithBlock:(void(^)(char field, double value, BOOL *stopFlag))block;

- (BOOL)hasField:(char)field;
- (double)valueForField:(char)field;
- (double)valueForField:(char)field fallback:(double)fallbackValue;
- (NSNumber*)objectAtIndexedSubscript:(NSUInteger)index;

@property (readonly) NSData *repetierV2Representation;
@property (readonly) NSString *ASCIIRepresentation;
@end