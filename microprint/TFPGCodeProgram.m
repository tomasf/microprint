//
//  TFGCodeProgram.m
//  MicroPrint
//
//

#import "TFPGCodeProgram.h"
#import "TFPGCode.h"
#import "TFPExtras.h"

@interface TFPGCodeProgram ()
@property (copy, readwrite) NSArray<TFPGCode *> *lines;
@end


@implementation TFPGCodeProgram


- (instancetype)initWithLines:(NSArray<TFPGCode*> *)lines {
	if(!(self = [super init])) return nil;
	
	self.lines = lines;
	
	return self;
}


+ (instancetype)programWithLines:(NSArray<TFPGCode*> *)lines {
	return [[self alloc] initWithLines:lines];
}


- (instancetype)initWithString:(NSString*)string error:(NSError**)outError {
	NSMutableArray *lines = [NSMutableArray new];
	__block BOOL failed = NO;
	__block NSString *failedLine;
	
	[string enumerateLinesUsingBlock:^(NSString *lineString, BOOL *stop) {
		TFPGCode *line = [[TFPGCode alloc] initWithString:lineString];
		if(!line) {
			*stop = YES;
			failed = YES;
			failedLine = lineString;
			return;
		}
		[lines addObject:line];
	}];
	
	if(failed) {
		if(outError) {
			NSString *errorString = [NSString stringWithFormat:@"Failed to parse G-code line:\n%@", failedLine];
			*outError = [NSError errorWithDomain:TFPErrorDomain code:TFPErrorCodeParseError userInfo:@{TFPErrorGCodeStringKey: failedLine, NSLocalizedRecoverySuggestionErrorKey: errorString}];
		}
		return nil;
	}
	
	return [self initWithLines:lines];
}


- (instancetype)initWithFileURL:(NSURL*)URL error:(NSError**)outError {
	NSString *string = [NSString stringWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:NULL];
	if(!string) {
		if(outError) {
			NSString *errorString = @"Failed to parse G-code file. Invalid character encoding?";
			*outError = [NSError errorWithDomain:TFPErrorDomain code:TFPErrorCodeParseError userInfo:@{NSLocalizedRecoverySuggestionErrorKey: errorString}];
		}
		return nil;
	}
	
	return [self initWithString:string error:outError];
}


- (BOOL)writeToFileURL:(NSURL*)URL error:(NSError**)outError {
	return [[self ASCIIRepresentation] writeToURL:URL atomically:YES encoding:NSUTF8StringEncoding error:outError];
}


- (NSString *)ASCIIRepresentation {
	return [[self.lines valueForKey:@"ASCIIRepresentation"] componentsJoinedByString:@"\n"];
}


- (NSString *)description {
	return [[self.lines valueForKey:@"description"] componentsJoinedByString:@"\n"];
}


@end