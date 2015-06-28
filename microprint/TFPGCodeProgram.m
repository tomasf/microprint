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


- (instancetype)initWithString:(NSString*)string {
	NSMutableArray *lines = [NSMutableArray new];
	[string enumerateLinesUsingBlock:^(NSString *lineString, BOOL *stop) {
		TFPGCode *line = [[TFPGCode alloc] initWithString:lineString];
		[lines addObject:line];
	}];
	
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


- (TFPGCodeProgram*)programByStrippingNonFieldCodes {
	NSArray *new = [self.lines tf_selectWithBlock:^BOOL(TFPGCode *code) {
		return code.hasFields;
	}];
	return [[TFPGCodeProgram alloc] initWithLines:new];
}


- (TFP3DVector*)measureSize {
	double minX = 10000, maxX = 0;
	double minY = 10000, maxY = 0;
	double minZ = 10000, maxZ = 0;
	
	BOOL relativeMode = NO;
	double X=0, Y=0, Z=0, E=0;
	
	for(TFPGCode *code in self.lines) {
		if(![code hasField:'G']) {
			continue;
		}
		
		switch ((int)[code valueForField:'G']) {
			case 0:
			case 1: {
				BOOL extruding = [code hasField:'E'] && !isnan([code valueForField:'E']);
				BOOL positiveExtrusion = NO;
				if(extruding) {
					double thisE = [code valueForField:'E'];
					if(relativeMode) {
						positiveExtrusion = (thisE > 0);
						E += thisE;
					}else{
						positiveExtrusion = (thisE > E);
						E = thisE;
					}
				}
				
				if(positiveExtrusion) {
					minX = MIN(minX, X);
					maxX = MAX(maxX, X);
					minY = MIN(minY, Y);
					maxY = MAX(maxY, Y);
					minZ = MIN(minZ, Z);
					maxZ = MAX(maxZ, Z);
				}
				
				if([code hasField:'X']) {
					double thisX = [code valueForField:'X'];
					if(relativeMode) {
						X += thisX;
					}else{
						X = thisX;
					}
				}
				
				if([code hasField:'Y']) {
					double thisY = [code valueForField:'Y'];
					if(relativeMode) {
						Y += thisY;
					}else{
						Y = thisY;
					}
				}
				
				if([code hasField:'Z']) {
					double thisZ = [code valueForField:'Z'];
					if(relativeMode) {
						Z += thisZ;
					}else{
						Z = thisZ;
					}
				}
				
				if(positiveExtrusion) {
					minX = MIN(minX, X);
					maxX = MAX(maxX, X);
					minY = MIN(minY, Y);
					maxY = MAX(maxY, Y);
					minZ = MIN(minZ, Z);
					maxZ = MAX(maxZ, Z);
				}
				
				break;
			}
    
			case 90:
				relativeMode = NO;
				break;
				
			case 91:
				relativeMode = YES;
				break;
				
			case 92:
				break;
		}
	}
	
	return [TFP3DVector vectorWithX:@(maxX-minX) Y:@(maxY-minY) Z:@(maxZ-minZ)];
}


@end