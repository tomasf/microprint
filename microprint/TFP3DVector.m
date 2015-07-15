//
//  TFDecimal3DPoint.m
//  MicroPrint
//
//

#import "TFP3DVector.h"
#import "Extras.h"


@interface TFP3DVector ()
@property (readwrite) NSNumber *x;
@property (readwrite) NSNumber *y;
@property (readwrite) NSNumber *z;
@end


@implementation TFP3DVector


- (instancetype)initWithX:(NSNumber*)X Y:(NSNumber*)Y Z:(NSNumber*)Z {
	if(!(self = [super init])) return nil;
	
	self.x = X;
	self.y = Y;
	self.z = Z;
	
	return self;
}


+ (instancetype)vectorWithX:(NSNumber*)X Y:(NSNumber*)Y Z:(NSNumber*)Z {
	return [[self alloc] initWithX:X Y:Y Z:Z];
}


+ (instancetype)emptyVector {
	return [self vectorWithX:nil Y:nil Z:nil];
}


+ (instancetype)zeroVector {
	return [self vectorWithX:@0 Y:@0 Z:@0];
}


+ (instancetype)zVector:(double)z {
	return [self vectorWithX:nil Y:nil Z:@(z)];
}


+ (instancetype)yVector:(double)y {
	return [self vectorWithX:nil Y:@(y) Z:nil];
}


+ (instancetype)xyVectorWithX:(double)x y:(double)y {
	return [self vectorWithX:@(x) Y:@(y) Z:nil];
}


- (NSString *)description {
	return [NSString stringWithFormat:@"[%@  %@  %@]", self.x ?: @"nil", self.y ?: @"nil", self.z ?: @"nil"];
}


- (TFP3DVector*)vectorByDefaultingToValues:(TFP3DVector*)defaults {
	return [TFP3DVector vectorWithX:(self.x ?: defaults.x) Y:(self.y ?: defaults.y) Z:(self.z ?: defaults.z)];
}


- (double)distanceToPoint:(TFP3DVector*)point {
	point = [point vectorByDefaultingToValues:self];
	
	return sqrt(pow(point.x.doubleValue - self.x.doubleValue, 2) + pow(point.y.doubleValue - self.y.doubleValue, 2) + pow(point.z.doubleValue - self.z.doubleValue, 2));
}

@end
