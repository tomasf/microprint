#import "TFStringScanner.h"

static NSCharacterSet *digitCharacters, *alphaCharacters, *alphanumericCharacters, *symbolCharacters;


@interface TFStringScanner ()
@property (readwrite, copy, nonatomic) NSString *string;
@property (nonatomic) NSUInteger length;
@property (readwrite) TFTokenType lastTokenType;
@property NSMutableArray *multicharSymbols;
@end



@implementation TFStringScanner


+ (void)initialize {
	digitCharacters = [NSCharacterSet characterSetWithRange:NSMakeRange('0', 10)];
	
	NSMutableCharacterSet *alpha = [NSMutableCharacterSet characterSetWithRange:NSMakeRange('a', 26)];
	[alpha addCharactersInRange:NSMakeRange('A', 26)];
	[alpha addCharactersInString:@"_"];
	alphaCharacters = alpha;
	
	NSMutableCharacterSet *alphanum = [digitCharacters mutableCopy];
	[alphanum formUnionWithCharacterSet:alphaCharacters];
	alphanumericCharacters = alphanum;
	
	NSMutableCharacterSet *symbols = [[alphanumericCharacters invertedSet] mutableCopy];
	[symbols removeCharactersInString:@" \t\r\n"];
	symbolCharacters = symbols;
}


+ (id)scannerWithString:(NSString*)string {
	return [[self alloc] initWithString:string];	
}


- (id)initWithString:(NSString*)string {
	if(!(self = [super init])) return nil;
	
	self.string = string;
	self.length = string.length;
	
	return self;
}


- (NSString *)description {
	NSInteger radius = 15;
	NSUInteger start = MAX((NSInteger)self.location-radius, 0);
	NSUInteger end = MIN(self.location+radius, self.string.length-1);
	NSString *sample = [self.string substringWithRange:NSMakeRange(start, end-start+1)];
	sample = [sample stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
	sample = [sample stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
	NSString *pointString = [[@"" stringByPaddingToLength:self.location-start withString:@" " startingAtIndex:0] stringByAppendingString:@"^"];
	return [NSString stringWithFormat:@"<%@ %p at position %lu>\n%@\n%@", [self class], self, (unsigned long)self.location, sample, pointString];
}


- (void)resortSymbols {
	[self.multicharSymbols sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"length" ascending:NO]]];
}


- (void)addMulticharacterSymbol:(NSString*)symbol {
	if(!self.multicharSymbols) {
		self.multicharSymbols = [NSMutableArray new];
	}
	
	[self.multicharSymbols addObject:symbol];
	[self resortSymbols];
}


- (void)addMulticharacterSymbols:(NSString*)symbol, ... {
	va_list list;
	va_start(list, symbol);
	
	do {
		[self.multicharSymbols addObject:symbol];
	} while((symbol = va_arg(list, NSString*)));
	
	va_end(list);
	[self resortSymbols];
}


- (void)removeMulticharacterSymbol:(NSString*)symbol {
	[self.multicharSymbols removeObject:symbol];
	[self resortSymbols];
}


- (unichar)scanCharacter {
	if(self.atEnd) return 0;
	return [self.string characterAtIndex:self.location++];
}


- (NSString*)scanForLength:(NSUInteger)length {
	if(self.location + length > self.string.length) return nil;
	NSString *sub = [self.string substringWithRange:NSMakeRange(self.location, length)];
	self.location += length;
	return sub;
}


- (BOOL)scanString:(NSString*)substring {
	NSUInteger length = [substring length];
	if(self.location + length > [self.string length]) return NO;
	
	NSString *sub = [self.string substringWithRange:NSMakeRange(self.location, length)];
	
	if([sub isEqual:substring]) {
		self.location += length;
		return YES;
		
	} else return NO;
}


- (NSString*)scanToString:(NSString*)substring {
	NSRange remainingRange = NSMakeRange(self.location, self.string.length-self.location);
	NSUInteger newLocation = [self.string rangeOfString:substring options:0 range:remainingRange].location;
	
	if(newLocation == NSNotFound) {
		self.location = [self.string length];
		return [self.string substringWithRange:remainingRange];
	}
	
	NSString *string = [self.string substringWithRange:NSMakeRange(self.location, newLocation-self.location)];
	self.location = newLocation;
	return string;
}


- (NSString*)scanStringFromCharacterSet:(NSCharacterSet*)set {
	BOOL found = NO;
	NSUInteger start = self.location;
	
	while(!self.atEnd && [set characterIsMember:[self.string characterAtIndex:self.location]]) {
		self.location++;
		found = YES;
	}
	
	return found ? [self.string substringWithRange:NSMakeRange(start, self.location-start)] : nil;
}


- (BOOL)scanWhitespace {
	return [self scanStringFromCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] != nil;
}


- (NSString*)scanToEnd {
	NSString *string = [self.string substringFromIndex:self.location];
	self.location = self.string.length;
	return string;
}


- (NSString*)peekToken {
	NSUInteger loc = self.location;
	NSString *token = [self scanToken];
	self.location = loc;
	return token;
}


- (NSString*)scanToken {
	[self scanWhitespace];
	if(self.atEnd) return nil;
	
	unichar firstChar = [self.string characterAtIndex:self.location];
	
	if([alphaCharacters characterIsMember:firstChar]) {
		self.lastTokenType = TFTokenTypeIdentifier;
		return [self scanStringFromCharacterSet:alphanumericCharacters];
		
	}else if([digitCharacters characterIsMember:firstChar]) {
		self.lastTokenType = TFTokenTypeNumeric;
		return [self scanStringFromCharacterSet:digitCharacters];
	
	}else{
		self.lastTokenType = TFTokenTypeSymbol;
		for(NSString *symbol in self.multicharSymbols)
			if([self scanString:symbol]) return symbol;
		self.location++;
		return [NSString stringWithCharacters:&firstChar length:1];
	}
}


- (BOOL)scanToken:(NSString*)matchToken {
	if([[self peekToken] isEqual:matchToken]) {
		[self scanToken];
		return YES;
	}else return NO;
}


- (BOOL)isAtEnd {
	return self.location >= self.length;
}


@end