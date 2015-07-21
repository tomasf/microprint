//
//  TFPFilament.h
//  microprint
//
//  Created by Tomas Franzén on Sat 2015-07-11.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

@import Foundation;


typedef NS_ENUM(NSUInteger, TFPFilamentType) {
	TFPFilamentTypeUnknown = 0,
	TFPFilamentTypePLA = 'PLA ',
	TFPFilamentTypeABS  = 'ABS ',
	TFPFilamentTypeHIPS = 'HIPS',
	TFPFilamentTypeOther = 'othr',
};



@interface TFPFilament : NSObject
+ (instancetype)defaultFilament;
+ (instancetype)filamentForType:(TFPFilamentType)type;

+ (TFPFilamentType)typeForString:(NSString*)string;

@property (readonly) TFPFilamentType type;
@property (readonly, copy) NSString *name;

@property (readonly) double defaultTemperature;

@property (readonly) NSUInteger fanSpeed;
@end
