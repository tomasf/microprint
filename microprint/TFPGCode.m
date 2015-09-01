//
//  TFGCodeLine.m
//  MicroPrint
//
//

#import "TFPGCode.h"
#import "TFPExtras.h"
#import "TFDataBuilder.h"
#import "TFStringScanner.h"


@interface TFPGCode ()
@property (readwrite, copy) NSString *comment;
@property (copy) NSDictionary *fields;
@end


@implementation TFPGCode


- (instancetype)initWithFields:(NSDictionary*)fields comment:(NSString*)comment {
	if(!(self = [super init])) return nil;
	
	self.comment = comment;
	self.fields = fields;
	
	for(NSNumber *key in fields) {
		double value = [fields[key] doubleValue];
		NSAssert(!isnan(value) && !isinf(value), @"G-code values can't be NaN or infinite");
	}
	
	return self;
}


- (instancetype)init {
	return [self initWithFields:@{} comment:nil];
}


+ (instancetype)codeWithString:(NSString*)string {
	return [[self alloc] initWithString:string];
}


+ (instancetype)codeWithComment:(NSString*)string {
	return [[self alloc] initWithFields:@{} comment:string];
}


+ (instancetype)codeWithField:(char)field value:(double)value {
	return [[self new] codeBySettingField:field toValue:value];
}


- (BOOL)hasFields {
	return self.fields.count > 0;
}


- (instancetype)initWithString:(NSString*)string {
	TFStringScanner *scanner = [TFStringScanner scannerWithString:string];
	NSString *comment;
	NSMutableDictionary *fields = [NSMutableDictionary dictionaryWithCapacity:3];
	
	static NSCharacterSet *valueCharacterSet;
	if(!valueCharacterSet) {
		valueCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789.-+"];
	}
	
	[scanner scanWhitespace];
	
	while(!scanner.atEnd) {
		unichar type = [scanner scanCharacter];
		if(type == ';') {
			comment = [scanner scanToEnd];
			break;
		}
		
		if(type < 'A' || type > 'Z') {
			return nil; // Parse error; invalid field type
		}
		
		NSString *valueString = [scanner scanStringFromCharacterSet:valueCharacterSet];
		
		if(!valueString) {
			// Not a valid number after field start character
			return nil;
		}
		
		BOOL ended = [scanner scanWhitespace] || scanner.isAtEnd;
		if(!ended) {
			return nil; // Parse error; invalid value or garbage after value
		}
		
		fields[@(type)] = @(valueString.doubleValue);
	}
	
	return [self initWithFields:fields comment:comment];
}


- (TFPGCode*)codeBySettingField:(char)field toValue:(double)value {
	NSMutableDictionary *fields = [self.fields mutableCopy];
	fields[@(field)] = @(value);
	
	return [[self.class alloc] initWithFields:fields comment:self.comment];
}


- (TFPGCode*)codeBySettingComment:(NSString*)comment {
	return [[self.class alloc] initWithFields:self.fields comment:comment];
}


- (TFPGCode*)codeByAdjustingField:(char)field offset:(double)offset {
	return [self codeBySettingField:field toValue:[self valueForField:field]+offset];
}


- (NSString *)description {
	return [self ASCIIRepresentation];
}


- (double)valueForField:(char)field {
	return [self.fields[@(field)] doubleValue];
}


- (double)valueForField:(char)field fallback:(double)fallbackValue {
	if([self hasField:field]) {
		return [self valueForField:field];
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


- (void)enumerateFieldsWithBlock:(void(^)(char field, double value, BOOL *stopFlag))block {
	const char *canonicalFieldOrder = "NMGXYZE FTSP    IJRD";
	
	for(NSUInteger i=0; i<strlen(canonicalFieldOrder); i++) {
		char field = canonicalFieldOrder[i];
		
		if(![self hasField:field]) {
			continue;
		}
		
		double value = [self valueForField:field];
		BOOL stop = NO;
		block(field, value, &stop);
		if(stop) {
			break;
		}
	}
}


- (NSString *)ASCIIRepresentation {
	static NSNumberFormatter *formatter;
	if(!formatter) {
		formatter = [NSNumberFormatter new];
		formatter.locale = [NSLocale systemLocale];
		formatter.maximumFractionDigits = 5;
		formatter.minimumFractionDigits = 0;
		formatter.minimumIntegerDigits = 1;
	}
	
	NSMutableArray *items = [NSMutableArray new];
	
	[self enumerateFieldsWithBlock:^(char field, double value, BOOL *stopFlag) {
		[items addObject:[NSString stringWithFormat:@"%c%@", field, [formatter stringFromNumber:@(value)]]];
	}];
	
	if(self.comment) {
		[items addObject:[NSString stringWithFormat:@";%@", self.comment]];
	}
	
	return [items componentsJoinedByString:@" "];
}


- (NSData*)repetierV2Representation {
	__block uint16_t flags = 1<<7 | 1<<12; // non-ASCII indicator + v2 flag
	
	TFDataBuilder *valueDataBuilder = [TFDataBuilder new];
	valueDataBuilder.byteOrder = TFDataBuilderByteOrderLittleEndian;
	
	NSString *fieldBits = @"NMGXYZE FTSP    IJRD";
	char *fieldTypes = "sssffff fbii    ffff";
	
	[self enumerateFieldsWithBlock:^(char field, double value, BOOL *stopFlag) {
		NSUInteger index = [fieldBits rangeOfString:[NSString stringWithFormat:@"%c", field]].location;
		
		flags |= (1<<index);
		
		switch(fieldTypes[index]) {
			case 's': [valueDataBuilder appendInt16:value]; break;
			case 'i': [valueDataBuilder appendInt32:value]; break;
			case 'b': [valueDataBuilder appendByte:value]; break;
			case 'f': [valueDataBuilder appendFloat:value]; break;
		}
	}];
	
	TFDataBuilder *dataBuilder = [TFDataBuilder new];
	dataBuilder.byteOrder = TFDataBuilderByteOrderLittleEndian;
	[dataBuilder appendInt16:flags];
	[dataBuilder appendInt16:0]; // v2-specific flags
	
	[dataBuilder appendData:valueDataBuilder.data];
	[dataBuilder appendData:dataBuilder.data.tf_fletcher16Checksum];
	
	return dataBuilder.data;
}


@end
