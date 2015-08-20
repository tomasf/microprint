//
//  TFPBedLevelCompensator.m
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-08-20.
//  Copyright © 2015 Tomas Franzén. All rights reserved.
//

#import "TFPBedLevelCompensator.h"

@import GLKit;



@interface TFPBedLevelCompensator ()
@property TFPBedLevelOffsets level;
@end


static const double bedMinX = 9;
static const double bedMaxX = 99;
static const double bedMinY = 5;
static const double bedMaxY = 95;
static const double bedCenterX = 54;
static const double bedCenterY = 50;



static float sign(GLKVector4 p1, GLKVector4 p2, GLKVector4 p3) {
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
}


static bool IsPointInTriangle(GLKVector4 pt, GLKVector4 v1, GLKVector4 v2, GLKVector4 v3) {
	float multiplier = 0.01f;
	
	GLKVector4 vector = GLKVector4Normalize(GLKVector4Add(GLKVector4Subtract(v1, v2), GLKVector4Subtract(v1, v3)));
	
	GLKVector4 vector2 = GLKVector4Add(v1, GLKVector4MultiplyScalar(vector, multiplier));
	vector = GLKVector4Normalize(GLKVector4Add(GLKVector4Subtract(v2, v1), GLKVector4Subtract(v2, v3)));
	
	GLKVector4 vector3 = GLKVector4Add(v2, GLKVector4MultiplyScalar(vector, multiplier));
	vector = GLKVector4Normalize(GLKVector4Add(GLKVector4Subtract(v3, v1), GLKVector4Subtract(v3, v2)));
	
	GLKVector4 vector4 = GLKVector4Add(v3, GLKVector4MultiplyScalar(vector, multiplier));
	
	BOOL flag = sign(pt, vector2, vector3) < 0;
	BOOL flag2 = sign(pt, vector3, vector4) < 0;
	BOOL flag3 = sign(pt, vector4, vector2) < 0;
	
	return flag == flag2 && flag2 == flag3;
}


static float GetZFromXYAndPlane(GLKVector4 point, GLKVector4 planeABC) {
	return (planeABC.x * point.x + planeABC.y * point.y + planeABC.w) / -planeABC.z;
}


static GLKVector4 calculatePlaneNormalVector(GLKVector4 v1, GLKVector4 v2, GLKVector4 v3) {
	GLKVector4 vector = GLKVector4Subtract(v2, v1);
	GLKVector4 vector2 = GLKVector4Subtract(v3, v1);
	
	return GLKVector4Make(vector.y * vector2.z - vector2.y * vector.z,
						  vector.z * vector2.x - vector2.z * vector.x,
						  vector.x * vector2.y - vector2.x * vector.y,
						  0);
}


static GLKVector4 generatePlaneEquation(GLKVector4 v1, GLKVector4 v2, GLKVector4 v3) {
	GLKVector4 planeNormal = calculatePlaneNormalVector(v1, v2, v3);
	planeNormal.w = -(planeNormal.x * v1.x + planeNormal.y * v1.y + planeNormal.z * v1.z);
	return planeNormal;
}



@implementation TFPBedLevelCompensator {
	GLKVector4 backRightVector;
	GLKVector4 backLeftVector;
	GLKVector4 frontLeftVector;
	GLKVector4 frontRightVector;
	GLKVector4 centerVector;
	
	GLKVector4 backPlane;
	GLKVector4 leftPlane;
	GLKVector4 rightPlane;
	GLKVector4 frontPlane;
}


- (instancetype)initWithBedLevel:(TFPBedLevelOffsets)offsets {
	if(!(self = [super init])) return nil;

	self.level = offsets;
	
	backRightVector = GLKVector4Make(bedMaxX, bedMaxY, offsets.backRight, 0);
	backLeftVector = GLKVector4Make(bedMinX, bedMaxY, offsets.backLeft, 0);
	frontLeftVector = GLKVector4Make(bedMinX, bedMinY, offsets.frontLeft, 0);
	frontRightVector = GLKVector4Make(bedMaxX, bedMinY, offsets.frontRight, 0);
	centerVector = GLKVector4Make(bedCenterX, bedCenterY, 0, 0);
	
	backPlane = generatePlaneEquation(backLeftVector, backRightVector, centerVector);
	leftPlane = generatePlaneEquation(backLeftVector, frontLeftVector, centerVector);
	rightPlane = generatePlaneEquation(backRightVector, frontRightVector, centerVector);
	frontPlane = generatePlaneEquation(frontLeftVector, frontRightVector, centerVector);

	return self;
}


- (double)zAdjustmentAtX:(double)x Y:(double)y {
	GLKVector4 pointVector = GLKVector4Make(x, y, 0, 0);
	double level = 0;
	
	if (x <= frontLeftVector.x && y >= backRightVector.y) {
		level = (GetZFromXYAndPlane(pointVector, backPlane) + GetZFromXYAndPlane(pointVector, leftPlane)) / 2;
		
	} else if (x <= frontLeftVector.x && y <= frontLeftVector.y) {
		level = (GetZFromXYAndPlane(pointVector, frontPlane) + GetZFromXYAndPlane(pointVector, leftPlane)) / 2;
		
	} else if (x >= frontRightVector.x && y <= frontLeftVector.y) {
		level = (GetZFromXYAndPlane(pointVector, frontPlane) + GetZFromXYAndPlane(pointVector, rightPlane)) / 2;
		
	} else if (x >= frontRightVector.x && y >= backRightVector.y) {
		level = (GetZFromXYAndPlane(pointVector, backPlane) + GetZFromXYAndPlane(pointVector, rightPlane)) / 2;
		
		
	} else if (x <= frontLeftVector.x) {
		level = GetZFromXYAndPlane(pointVector, leftPlane);
		
	} else if (x >= frontRightVector.x) {
		level = GetZFromXYAndPlane(pointVector, rightPlane);
		
	} else if (y >= backRightVector.y) {
		level = GetZFromXYAndPlane(pointVector, backPlane);
		
	} else if (y <= frontLeftVector.y) {
		level = GetZFromXYAndPlane(pointVector, frontPlane);
		
		
	} else if (IsPointInTriangle(pointVector, centerVector, frontLeftVector, backLeftVector)) {
		level = GetZFromXYAndPlane(pointVector, leftPlane);
		
	} else if (IsPointInTriangle(pointVector, centerVector, frontRightVector, backRightVector)) {
		level = GetZFromXYAndPlane(pointVector, rightPlane);
		
	} else if (IsPointInTriangle(pointVector, centerVector, backLeftVector, backRightVector)) {
		level = GetZFromXYAndPlane(pointVector, backPlane);
		
	} else if (IsPointInTriangle(pointVector, centerVector, frontLeftVector, frontRightVector)) {
		level = GetZFromXYAndPlane(pointVector, frontPlane);
		
		
	} else {
		NSLog(@"Warning: zAdjustmentAtX:y: for (%.02f, %.02f) not possible", x, y);
	}
	
	return level + self.level.common;
}


@end