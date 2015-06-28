//
//  TFGCodeLine.m
//  MicroPrint
//
//

#import "TFPGCode.h"
#import "Extras.h"
#import "TFDataBuilder.h"


@interface TFPGCode ()
@property (readwrite, copy) NSString *comment;
@property (copy) NSDictionary *fields;
@end


const char *canonicalFieldOrder = "NMGXYZE FTSP    IJRD";


@implementation TFPGCode


- (instancetype)initWithFields:(NSDictionary*)fields comment:(NSString*)comment {
	if(!(self = [super init])) return nil;
	
	self.comment = comment;
	self.fields = fields;
	
	return self;
}


- (instancetype)init {
	return [self initWithFields:@{} comment:nil];
}


+ (instancetype)codeWithString:(NSString*)string {
	return [[self alloc] initWithString:string];
}


+ (instancetype)codeWithField:(char)field value:(double)value {
	return [[self new] codeBySettingField:field toValue:value];
}


- (BOOL)hasFields {
	return self.fields.count > 0;
}


- (instancetype)initWithString:(NSString*)string {
	NSUInteger commentStart = [string rangeOfString:@";"].location;
	NSString *comment;

	if(commentStart != NSNotFound) {
		comment = [string substringFromIndex:commentStart+1];
		string = [string substringToIndex:commentStart];
	}
	
	/*
	static NSRegularExpression *regex;
	if(!regex) {
		regex = [NSRegularExpression regularExpressionWithPattern:@"([A-Z]) (\\d)" options:0 error:NULL];
	}
	string = [regex stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"$1$2"];
	*/
	
	NSArray *fieldStrings = [string componentsSeparatedByString:@" "];
	fieldStrings = [fieldStrings filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
	
	NSMutableDictionary *fields = [NSMutableDictionary new];
	for(NSString *fieldString in fieldStrings) {
		char fieldType = [[fieldString substringToIndex:1] characterAtIndex:0];
		
		id value = fieldString.length > 1 ? @([fieldString substringFromIndex:1].doubleValue) : [NSNull null];
		fields[@(fieldType)] = value;
	}
	
	return [self initWithFields:fields comment:comment];
}


- (TFPGCode*)codeBySettingField:(char)field toValue:(double)value {
	NSMutableDictionary *fields = [self.fields mutableCopy];
	fields[@(field)] = @(value);
	
	return [[self.class alloc] initWithFields:fields comment:self.comment];
}


- (TFPGCode*)codeByAdjustingField:(char)field offset:(double)offset {
	return [self codeBySettingField:field toValue:[self valueForField:field]+offset];
}


- (NSString *)description {
	return [self ASCIIRepresentation];
}


- (double)valueForField:(char)field {
	NSNumber *value = self.fields[@(field)];
	if([value isKindOfClass:[NSNumber class]]) {
		return value.doubleValue;
	}else return NAN;
}


- (double)valueForField:(char)field fallback:(double)fallbackValue {
	double value = [self valueForField:field];
	
	if([self hasField:field] && !isnan(value)) {
		return value;
	} else {
		return fallbackValue;
	}
}


- (BOOL)hasField:(char)field {
	return self.fields[@(field)] != nil;
}


- (NSNumber*)objectAtIndexedSubscript:(NSUInteger)index {
	return self.fields[@(index)];
}


- (TFP3DVector*)movementVector {
	return [TFP3DVector vectorWithX:self['X'] Y:self['Y'] Z:self['Z']];
}


- (BOOL)hasExtrusion {
	return [self hasField:'E'];
}


- (double)extrusion {
	return [self valueForField:'E'];
}


- (double)feedRate {
	return [self valueForField:'F'];
}

- (BOOL)hasFeedRate {
	return [self hasField:'F'];
}


- (NSString *)ASCIIRepresentation {
	NSNumberFormatter *formatter = [NSNumberFormatter new];
	formatter.locale = [NSLocale systemLocale];
	formatter.maximumFractionDigits = 5;
	formatter.minimumIntegerDigits = 1;

	NSMutableArray *items = [NSMutableArray new];
	
	for(NSUInteger i=0; i<strlen(canonicalFieldOrder); i++) {
		char field = canonicalFieldOrder[i];
		if([self hasField:field]) {
			id value = self[field];
			if(value == [NSNull null]) {
				[items addObject:[NSString stringWithFormat:@"%c", field]];
			}else{
				[items addObject:[NSString stringWithFormat:@"%c%@", field, [formatter stringFromNumber:value]]];
			}
		}
	}
	
	if(self.comment) {
		[items addObject:[NSString stringWithFormat:@"; %@", self.comment]];
	}
	
	return [items componentsJoinedByString:@" "];
}


- (NSData*)repetierV2Representation {
	uint16_t flags = 1<<7 | 1<<12; // non-ASCII indicator + v2 flag
	
	char *valueTypes = "sssffff fbii    ffff";
	
	TFDataBuilder *valueDataBuilder = [TFDataBuilder new];
	valueDataBuilder.byteOrder = TFDataBuilderByteOrderLittleEndian;
	
	for(NSUInteger i=0; i<strlen(canonicalFieldOrder); i++) {
		NSNumber *value = self[canonicalFieldOrder[i]];
		if(!value) {
			continue;
		}
		
		flags |= (1<<i);
		
		switch(valueTypes[i]) {
			case 's': [valueDataBuilder appendInt16:value.unsignedShortValue]; break;
			case 'i': [valueDataBuilder appendInt32:value.unsignedIntValue]; break;
			case 'b': [valueDataBuilder appendByte:value.unsignedCharValue]; break;
			case 'f': [valueDataBuilder appendFloat:value.floatValue]; break;
		}
	}
	
	TFDataBuilder *dataBuilder = [TFDataBuilder new];
	dataBuilder.byteOrder = TFDataBuilderByteOrderLittleEndian;
	[dataBuilder appendInt16:flags];
	[dataBuilder appendInt16:0]; // v2-specific flags
	
	[dataBuilder appendData:valueDataBuilder.data];
	[dataBuilder appendData:dataBuilder.data.tf_fletcher16Checksum];
	
	return dataBuilder.data;
}


@end
