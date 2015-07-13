//
//  TFDecimal3DPoint.h
//  MicroPrint
//
//

#import <Foundation/Foundation.h>

@interface TFP3DVector : NSObject
+ (instancetype)vectorWithX:(NSNumber*)x Y:(NSNumber*)Y Z:(NSNumber*)Z;

+ (instancetype)zVector:(double)z;

+ (instancetype)zeroVector;
+ (instancetype)emptyVector;

@property (readonly) NSNumber *x;
@property (readonly) NSNumber *y;
@property (readonly) NSNumber *z;

- (double)distanceToPoint:(TFP3DVector*)point;
- (TFP3DVector*)vectorByDefaultingToValues:(TFP3DVector*)defaults;
@end
