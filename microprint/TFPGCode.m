//
//  TFGCodeLine.m
//  MicroPrint
//
//

#import "TFPGCode.h"
#import "TFPExtras.h"
#import "TFDataBuilder.h"
#import "TFStringScanner.h"


enum {
	offsetN, offsetM, offsetG,
	offsetX, offsetY, offsetZ, offsetE, offsetF,
	offsetS, offsetP,
} TFPGCodeFieldOffsets;



@interface TFPGCode ()
@property (nonatomic, readwrite) int16_t N;

@property (nonatomic, readwrite) uint16_t M;
@property (nonatomic, readwrite) uint16_t G;

@property (nonatomic, readwrite) float X;
@property (nonatomic, readwrite) float Y;
@property (nonatomic, readwrite) float Z;
@property (nonatomic, readwrite) float E;
@property (nonatomic, readwrite) float F;

@property (nonatomic, readwrite) uint32_t S;
@property (nonatomic, readwrite) uint32_t P;

@property (nonatomic, readwrite) uint16 fieldsSetMask;

@property (readwrite, copy) NSString *comment;
@end



@implementation TFPGCode


- (instancetype)initWithComment:(NSString*)comment {
	if(!(self = [super init])) return nil;
	
	self.comment = comment;
	
	return self;
}



+ (instancetype)codeWithString:(NSString*)string {
	return [[self alloc] initWithString:string];
}


+ (instancetype)codeWithComment:(NSString*)string {
	return [[self alloc] initWithComment:string];
}


+ (instancetype)codeWithField:(char)field value:(double)value {
	TFPGCode *code = [self new];
	[code setValue:value forField:field];
	return code;
}


- (int8_t)maskOffsetForField:(char)field {
	switch(field) {
		case 'N': return offsetN;
		case 'G': return offsetG;
		case 'M': return offsetM;
		case 'X': return offsetX;
		case 'Y': return offsetY;
		case 'Z': return offsetZ;
		case 'E': return offsetE;
		case 'F': return offsetF;
		case 'S': return offsetS;
		case 'P': return offsetP;
	}
	return -1;
}


- (BOOL)setValue:(double)value forField:(char)field {
	NSAssert(!isnan(value) && !isinf(value), @"G-code values can't be NaN or infinite");

	int8_t offset = [self maskOffsetForField:field];
	if (offset >= 0) {
		self.fieldsSetMask |= (1<<offset);
	} else {
		return NO;
	}
	
	switch(field) {
		case 'N': self.N = value; break;
		case 'G': self.G = value; break;
		case 'M': self.M = value; break;
		case 'X': self.X = value; break;
		case 'Y': self.Y = value; break;
		case 'Z': self.Z = value; break;
		case 'E': self.E = value; break;
		case 'F': self.F = value; break;
		case 'S': self.S = value; break;
		case 'P': self.P = value; break;
	}
	return YES;
}


- (BOOL)hasFields {
	return self.fieldsSetMask != 0;
}


- (instancetype)initWithString:(NSString*)string {
	if(!(self = [self initWithComment:nil])) return nil;
	
	TFStringScanner *scanner = [TFStringScanner scannerWithString:string];
	
	static NSCharacterSet *valueCharacterSet;
	if(!valueCharacterSet) {
		valueCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789.-+"];
	}
	
	[scanner scanWhitespace];
	
	while(!scanner.atEnd) {
		unichar type = [scanner scanCharacter];
		if(type == ';') {
			self.comment = [scanner scanToEnd];
			break;
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
		
		[self setValue:valueString.doubleValue forField:type];
	}
	
	return self;
}


- (TFPGCode*)createCopy {
	TFPGCode *copy = [self.class new];
	
	copy.comment = self.comment;
	copy.fieldsSetMask = self.fieldsSetMask;
	copy.N = self.N;
	copy.M = self.M;
	copy.G = self.G;
	
	copy.X = self.X;
	copy.Y = self.Y;
	copy.Z = self.Z;
	copy.E = self.E;
	copy.F = self.F;
	
	copy.S = self.S;
	copy.P = self.P;
	
	return copy;
}


- (TFPGCode*)codeBySettingField:(char)field toValue:(double)value {
	TFPGCode *copy = [self createCopy];
	[copy setValue:value forField:field];
	return copy;
}


- (TFPGCode*)codeBySettingComment:(NSString*)comment {
	TFPGCode *copy = [self createCopy];
	copy.comment = comment;
	return copy;
}


- (TFPGCode*)codeByAdjustingField:(char)field offset:(double)offset {
	return [self codeBySettingField:field toValue:[self valueForField:field]+offset];
}


- (NSString *)description {
	return [self ASCIIRepresentation];
}


- (double)valueForField:(char)field {
	switch(field) {
		case 'N': return self.N;
		case 'G': return self.G;
		case 'M': return self.M;
		case 'X': return self.X;
		case 'Y': return self.Y;
		case 'Z': return self.Z;
		case 'E': return self.E;
		case 'F': return self.F;
		case 'S': return self.S;
		case 'P': return self.P;
	}
	return 0;
}


- (double)valueForField:(char)field fallback:(double)fallbackValue {
	if([self hasField:field]) {
		return [self valueForField:field];
	} else {
		return fallbackValue;
	}
}


- (NSNumber*)numberForField:(char)field {
	return [self hasField:field] ? @([self valueForField:field]) : nil;
}


- (BOOL)hasField:(char)field {
	int8_t offset = [self maskOffsetForField:field];
	if (offset < 0) {
		return NO;
	} else {
		return !!(self.fieldsSetMask & (1 << offset));
	}
}


- (NSNumber*)objectAtIndexedSubscript:(NSUInteger)index {
	return [self hasField:index] ? @([self valueForField:index]) : nil;
}


- (void)enumerateFieldsWithBlock:(void(^)(char field, double value, BOOL *stopFlag))block {
	const char *canonicalFieldOrder = "NMGXYZEFSP";
	
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
	
	NSString *fieldBits = @"NMGXYZE FTSP";
	char *fieldTypes = "sssffff fbii";
	
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
