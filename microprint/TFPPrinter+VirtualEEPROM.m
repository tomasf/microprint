//
//  TFPPrinter+VirtualEEPROM.m
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-16.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrinter+VirtualEEPROM.h"
#import "TFPExtras.h"
#import "TFPGCodeHelpers.h"


@implementation TFPPrinter (VirtualEEPROM)


+ (uint32_t)encodeVirtualEEPROMIntegerValueForFloat:(float)value {
	NSSwappedFloat swapped = NSSwapHostFloatToLittle(value);
	int32_t intValue;
	memcpy(&intValue, &swapped, sizeof(swapped));
	return intValue;
}


+ (float)decodeVirtualEEPROMFloatValueForInteger:(uint32_t)value {
	NSSwappedFloat swapped;
	memcpy(&swapped, &value, sizeof(float));
	return NSSwapLittleFloatToHost(swapped);
}


- (void)readVirtualEEPROMValueAtIndex:(NSUInteger)index completionHandler:(void(^)(BOOL success, int32_t value))completionHandler {
	[self sendGCode:[TFPGCode codeForReadingVirtualEEPROMAtIndex:index] responseHandler:^(BOOL success, NSDictionary *values) {
		if(!success) {
			completionHandler(NO, 0);
			return;
		}
		completionHandler(YES, [values[@"DT"] intValue]);
	}];
}


- (void)writeVirtualEEPROMValueAtIndex:(NSUInteger)index value:(int32_t)value completionHandler:(void(^)(BOOL success))completionHandler {
	[self sendGCode:[TFPGCode codeForWritingVirtualEEPROMAtIndex:index value:value] responseHandler:^(BOOL success, NSDictionary *value) {
		completionHandler(success);
	}];
}


- (void)readVirtualEEPROMFloatValueAtIndex:(NSUInteger)index completionHandler:(void(^)(BOOL success, float value))completionHandler {
	[self readVirtualEEPROMValueAtIndex:index completionHandler:^(BOOL success, int32_t value) {
		completionHandler(success, [self.class decodeVirtualEEPROMFloatValueForInteger:value]);
	}];
}


- (void)writeVirtualEEPROMFloatValueAtIndex:(NSUInteger)index value:(float)value completionHandler:(void(^)(BOOL success))completionHandler {
	int32_t intValue = [self.class encodeVirtualEEPROMIntegerValueForFloat:value];
	[self writeVirtualEEPROMValueAtIndex:index value:intValue completionHandler:completionHandler];
}


- (void)readVirtualEEPROMValuesAtIndexes:(NSArray*)indexes completionHandler:(void(^)(BOOL success, NSArray *values))completionHandler {
	NSMutableArray *values = [NSMutableArray new];
	[indexes enumerateObjectsUsingBlock:^(NSNumber *indexNumber, NSUInteger index, BOOL *stop) {
		[self readVirtualEEPROMValueAtIndex:indexNumber.integerValue completionHandler:^(BOOL success, int32_t value) {
			[values addObject:@(value)];
			if(index == indexes.count-1) {
				completionHandler(YES, values);
			}
		}];
	}];
}


- (void)readVirtualEEPROMFloatValuesAtIndexes:(NSArray*)indexes completionHandler:(void(^)(BOOL success, NSArray *values))completionHandler {
	[self readVirtualEEPROMValuesAtIndexes:indexes completionHandler:^(BOOL success, NSArray *values) {
		NSArray *floatValues = [values tf_mapWithBlock:^NSNumber*(NSNumber *intNumber) {
			return @([self.class decodeVirtualEEPROMFloatValueForInteger:intNumber.intValue]);
		}];
		
		completionHandler(success, floatValues);
	}];
}


- (void)writeVirtualEEPROMValues:(NSArray*)values forIndexes:(NSArray*)keys completionHandler:(void(^)(BOOL success))completionHandler {
	[keys enumerateObjectsUsingBlock:^(NSNumber *indexNumber, NSUInteger index, BOOL *stop) {
		uint32_t value = [values[index] unsignedIntValue];
		
		[self writeVirtualEEPROMValueAtIndex:indexNumber.unsignedIntegerValue value:value completionHandler:^(BOOL success) {
			if(index == keys.count-1) {
				completionHandler(YES);
			}
		}];
	}];
}


- (void)writeVirtualEEPROMValues:(NSDictionary*)valuesForIndexes completionHandler:(void(^)(BOOL success))completionHandler {
	NSMutableArray *keys = [NSMutableArray new];
	NSMutableArray *values = [NSMutableArray new];
	[valuesForIndexes enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSNumber *value, BOOL *stop) {
		[keys addObject:key];
		[values addObject:value];
	}];
	
	[self writeVirtualEEPROMValues:values forIndexes:keys completionHandler:completionHandler];
}


- (void)writeVirtualEEPROMFloatValues:(NSDictionary*)valuesForIndexes completionHandler:(void(^)(BOOL success))completionHandler {
	NSMutableDictionary *intValuesForIndexes = [NSMutableDictionary new];
	for(NSNumber *key in valuesForIndexes) {
		NSNumber *floatNumber = valuesForIndexes[key];
		intValuesForIndexes[key] = @([self.class encodeVirtualEEPROMIntegerValueForFloat:floatNumber.floatValue]);
	}
	
	[self writeVirtualEEPROMValues:intValuesForIndexes completionHandler:completionHandler];
}


@end
