//
//  TFGCodeProgram.m
//  MicroPrint
//
//

#import "TFPGCodeProgram.h"
#import "TFPGCode.h"
#import "Extras.h"

@interface TFPGCodeProgram ()
@property (copy, readwrite) NSArray *lines;
@end


@implementation TFPGCodeProgram


- (instancetype)initWithLines:(NSArray*)lines {
	if(!(self = [super init])) return nil;
	
	self.lines = lines;
	
	return self;
}


+ (instancetype)programWithLines:(NSArray*)lines {
	return [[self alloc] initWithLines:lines];
}


- (instancetype)initWithString:(NSString*)string {
	NSMutableArray *lines = [NSMutableArray new];
	__block BOOL failed = NO;
	[string enumerateLinesUsingBlock:^(NSString *lineString, BOOL *stop) {
		TFPGCode *line = [[TFPGCode alloc] initWithString:lineString];
		if(!line) {
			*stop = YES;
			failed = YES;
			return;
		}
		[lines addObject:line];
	}];
	
	if(failed) {
		return nil;
	}
	
	if(!(self = [self initWithLines:lines])) return nil;
	
	return self;
}


- (instancetype)initWithFileURL:(NSURL*)URL {
	NSString *string = [NSString stringWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:NULL];
	if(!string) {
		return nil;
	}
	
	return [self initWithString:string];
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