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
- (NSNumber*)numberForField:(char)field;

@property (nonatomic, readonly) int16_t N;

@property (nonatomic, readonly) uint16_t M;
@property (nonatomic, readonly) uint16_t G;

@property (nonatomic, readonly) float X;
@property (nonatomic, readonly) float Y;
@property (nonatomic, readonly) float Z;
@property (nonatomic, readonly) float E;
@property (nonatomic, readonly) float F;

@property (nonatomic, readonly) uint32_t S;
@property (nonatomic, readonly) uint32_t P;

@property (readonly) NSData *repetierV2Representation;
@property (readonly) NSString *ASCIIRepresentation;
@end