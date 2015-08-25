//
//  TFPPrinter+VirtualEEPROM.h
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-16.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TFPPrinter.h"


enum VirtualEEPROMIndexes {
	VirtualEEPROMIndexBacklashCompensationX = 0,
	VirtualEEPROMIndexBacklashCompensationY = 1,
	
	VirtualEEPROMIndexBedCompensationBackRight = 2,
	VirtualEEPROMIndexBedCompensationBackLeft = 3,
	VirtualEEPROMIndexBedCompensationFrontLeft = 4,
	VirtualEEPROMIndexBedCompensationFrontRight = 5,
	
	VirtualEEPROMIndexFilamentColor = 6,
	VirtualEEPROMIndexFilamentTypeID = 7,
	VirtualEEPROMIndexFilamentTemperature = 8,
	VirtualEEPROMIndexFilamentAmount = 9,
	
	VirtualEEPROMIndexBacklashExpansionXPlus = 10,
	VirtualEEPROMIndexBacklashExpansionYLPlus = 11,
	VirtualEEPROMIndexBacklashExpansionYRPlus = 12,
	VirtualEEPROMIndexBacklashExpansionYRMinus = 13,
	VirtualEEPROMIndexBacklashExpansionZ = 14,
	VirtualEEPROMIndexBacklashExpansionE = 15,
	
	VirtualEEPROMIndexBedOffsetBackLeft = 16,
	VirtualEEPROMIndexBedOffsetBackRight = 17,
	VirtualEEPROMIndexBedOffsetFrontRight = 18,
	VirtualEEPROMIndexBedOffsetFrontLeft = 19,
	VirtualEEPROMIndexBedOffsetCommon = 20,
	
	VirtualEEPROMIndexReservedForSpooler = 21,
	
	VirtualEEPROMIndexBacklashCompensationSpeed = 22,
	
	VirtualEEPROMIndexG32Version = 23,
	
	VirtualEEPROMIndexG32FirstSample = 64,
	// ...
	VirtualEEPROMIndexG32LastSample = 126,
};


@interface TFPPrinter (VirtualEEPROM)

+ (uint32_t)encodeVirtualEEPROMIntegerValueForFloat:(float)value;
+ (float)decodeVirtualEEPROMFloatValueForInteger:(uint32_t)value;

// Single values, int32
- (void)readVirtualEEPROMValueAtIndex:(NSUInteger)index completionHandler:(void(^)(BOOL success, int32_t value))completionHandler;
- (void)writeVirtualEEPROMValueAtIndex:(NSUInteger)index value:(int32_t)value completionHandler:(void(^)(BOOL success))completionHandler;

// Single values, converted from/to float
- (void)readVirtualEEPROMFloatValueAtIndex:(NSUInteger)index completionHandler:(void(^)(BOOL success, float value))completionHandler;
- (void)writeVirtualEEPROMFloatValueAtIndex:(NSUInteger)index value:(float)value completionHandler:(void(^)(BOOL success))completionHandler;

// Multiple values, int32
- (void)readVirtualEEPROMValuesAtIndexes:(NSArray*)indexes completionHandler:(void(^)(BOOL success, NSArray *values))completionHandler;
- (void)writeVirtualEEPROMValues:(NSDictionary*)valuesForIndexes completionHandler:(void(^)(BOOL success))completionHandler;

// Multiple values, converted from/to float
- (void)readVirtualEEPROMFloatValuesAtIndexes:(NSArray*)indexes completionHandler:(void(^)(BOOL success, NSArray *values))completionHandler;
- (void)writeVirtualEEPROMFloatValues:(NSDictionary*)valuesForIndexes completionHandler:(void(^)(BOOL success))completionHandler;
@end