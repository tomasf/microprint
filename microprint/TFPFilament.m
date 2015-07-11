//
//  TFPFilament.m
//  microprint
//
//  Created by Tomas Franzén on Sat 2015-07-11.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPFilament.h"


@interface TFPFilament ()
@property (readwrite) TFPFilamentType type;
@property (readwrite, copy) NSString *name;

@property (readwrite) double temperature;
@end



@implementation TFPFilament


+ (NSDictionary*)filamentSpecification {
	return @{
			 @(TFPFilamentTypePLA):
				 @{
					 @"name": @"PLA",
					 @"temperature": @215,
					 },
			 @(TFPFilamentTypeABS):
				 @{
					 @"name": @"ABS",
					 @"temperature": @275,
					 },
			 @(TFPFilamentTypeHIPS):
				 @{
					 @"name": @"HIPS",
					 @"temperature": @265,
					 },
			 @(TFPFilamentTypeOther):
				 @{
					 @"name": @"Other",
					 @"temperature": @215,
					 },
			 };
}


+ (instancetype)defaultFilament {
	return [self filamentForType:TFPFilamentTypePLA];
}


+ (instancetype)filamentForType:(TFPFilamentType)type {
	return [[self alloc] initWithType:type data:[self filamentSpecification][@(type)]];
}


+ (TFPFilamentType)typeForString:(NSString*)string {
	NSDictionary *names = @{
							@"pla" : @(TFPFilamentTypePLA),
							@"abs" : @(TFPFilamentTypeABS),
							@"hips" : @(TFPFilamentTypeHIPS),
							@"other" : @(TFPFilamentTypeOther),
							};
	NSNumber *type = names[string.lowercaseString];
	return type ? type.integerValue : TFPFilamentTypeUnknown;
}


- (instancetype)initWithType:(TFPFilamentType)type data:(NSDictionary*)spec {
	if(!spec) {
		return nil;
	}
	
	if(!(self = [super init])) return nil;
	
	self.type = type;
	self.name = spec[@"name"];
	self.temperature = [spec[@"temperature"] doubleValue];
	
	return self;
}


- (NSUInteger)fanSpeed {
	return (self.type == TFPFilamentTypePLA) ? 255 : 50;
}


@end