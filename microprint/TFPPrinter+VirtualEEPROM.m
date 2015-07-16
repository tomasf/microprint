//
//  TFPPrinter+VirtualEEPROM.m
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-16.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrinter+VirtualEEPROM.h"
#import "Extras.h"
#import "TFPGCodeHelpers.h"


@implementation TFPPrinter (VirtualEEPROM)


- (void)readVirtualEEPROMValueAtIndex:(NSUInteger)index completionHandler:(void(^)(BOOL success, int32_t value))completionHandler {
	[self sendGCode:[TFPGCode codeForReadingVirtualEEPROMAtIndex:index] responseHandler:^(BOOL success, NSString *value) {
		if(!success) {
			completionHandler(NO, 0);
			return;
		}
		
		NSDictionary *values = [TFPGCode dictionaryFromResponseValueString:value];
		completionHandler(YES, [values[@"DT"] intValue]);
	}];
}


- (void)writeVirtualEEPROMValueAtIndex:(NSUInteger)index value:(int32_t)value completionHandler:(void(^)(BOOL success))completionHandler {
	[self sendGCode:[TFPGCode codeForWritingVirtualEEPROMAtIndex:index value:value] responseHandler:^(BOOL success, NSString *value) {
		completionHandler(success);
	}];
}


- (void)readVirtualEEPROMFloatValueAtIndex:(NSUInteger)index completionHandler:(void(^)(BOOL success, float value))completionHandler {
	[self readVirtualEEPROMValueAtIndex:index completionHandler:^(BOOL success, int32_t value) {
		NSSwappedFloat swapped;
		memcpy(&swapped, &value, sizeof(float));
		float result = NSSwapLittleFloatToHost(swapped);
		
		completionHandler(success, result);
	}];
}


- (void)writeVirtualEEPROMFloatValueAtIndex:(NSUInteger)index value:(float)value completionHandler:(void(^)(BOOL success))completionHandler {
	NSSwappedFloat swapped = NSSwapHostFloatToLittle(value);
	int32_t intValue;
	memcpy(&intValue, &swapped, sizeof(swapped));
	
	[self writeVirtualEEPROMValueAtIndex:index value:intValue completionHandler:completionHandler];
}


- (void)readVirtualEEPROMValuesAtIndexes:(NSArray*)indexes completionHandler:(void(^)(BOOL success, NSArray *values))completionHandler {
	NSUInteger firstIndex = [indexes.firstObject unsignedIntegerValue];
	[self readVirtualEEPROMValueAtIndex:firstIndex completionHandler:^(BOOL success, int32_t value) {
		if(!success) {
			completionHandler(NO, nil);
		}
		NSMutableArray *values = [@[@(value)] mutableCopy];
		
		NSArray *rest = [indexes subarrayWithRange:NSMakeRange(1, indexes.count-1)];
		if(rest.count) {
			[self readVirtualEEPROMValuesAtIndexes:rest completionHandler:^(BOOL success, NSArray *subvalues) {
				if(!success) {
					completionHandler(NO, nil);
					return;
				}
				[values addObjectsFromArray:subvalues];

				completionHandler(YES, values);
			}];
		}else{
			completionHandler(YES, values);
		}
	}];
}


- (void)readVirtualEEPROMFloatValuesAtIndexes:(NSArray*)indexes completionHandler:(void(^)(BOOL success, NSArray *values))completionHandler {
	[self readVirtualEEPROMValuesAtIndexes:indexes completionHandler:^(BOOL success, NSArray *values) {
		NSArray *floatValues = [values tf_mapWithBlock:^NSNumber*(NSNumber *intNumber) {
			int32_t value = [intNumber intValue];
			NSSwappedFloat swapped;
			memcpy(&swapped, &value, sizeof(float));
			
			return @(NSSwapLittleFloatToHost(swapped));
		}];
		
		completionHandler(success, floatValues);
	}];
}


- (void)writeVirtualEEPROMValues:(NSArray*)values forKeys:(NSArray*)keys completionHandler:(void(^)(BOOL success))completionHandler {
	NSUInteger firstIndex = [keys.firstObject unsignedIntegerValue];
	int32_t firstValue = [values.firstObject intValue];
	
	[self writeVirtualEEPROMValueAtIndex:firstIndex value:firstValue completionHandler:^(BOOL success) {
		if(!success) {
			completionHandler(NO);
			return;
		}
		NSArray *restKeys = [keys subarrayWithRange:NSMakeRange(1, keys.count-1)];
		NSArray *restValues = [values subarrayWithRange:NSMakeRange(1, values.count-1)];
		
		if(restKeys.count) {
			[self writeVirtualEEPROMValues:restValues forKeys:restKeys completionHandler:^(BOOL success) {
				completionHandler(success);
			}];
		}else{
			completionHandler(success);
		}
	}];
}


- (void)writeVirtualEEPROMValues:(NSDictionary*)valuesForIndexes completionHandler:(void(^)(BOOL success))completionHandler {
	NSMutableArray *keys = [NSMutableArray new];
	NSMutableArray *values = [NSMutableArray new];
	[valuesForIndexes enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSNumber *value, BOOL *stop) {
		[keys addObject:key];
		[values addObject:value];
	}];
	
	[self writeVirtualEEPROMValues:values forKeys:keys completionHandler:completionHandler];
}


- (void)writeVirtualEEPROMFloatValues:(NSDictionary*)valuesForIndexes completionHandler:(void(^)(BOOL success))completionHandler {
	NSMutableDictionary *intValuesForIndexes = [NSMutableDictionary new];
	for(NSNumber *key in valuesForIndexes) {
		NSNumber *floatNumber = valuesForIndexes[key];
		NSSwappedFloat swapped = NSSwapHostFloatToLittle(floatNumber.floatValue);
		int32_t intValue;
		memcpy(&intValue, &swapped, sizeof(swapped));
		
		intValuesForIndexes[key] = @(intValue);
	}
	
	[self writeVirtualEEPROMValues:intValuesForIndexes completionHandler:completionHandler];
}


@end
