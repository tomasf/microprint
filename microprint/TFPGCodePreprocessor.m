//
//  TFPGCodePreprocessor.m
//  MicroPrint
//
//  Created by Tomas Franzén on Mon 2015-06-22.
//

#import "TFPGCodePreprocessor.h"
#import "TFPGCode.h"
#import "Extras.h"


@interface TFPGCodePreprocessor ()
@property (readwrite) TFPGCodeProgram *program;
@end



static double CGVectorDistance(CGVector a, CGVector b) {
	return sqrt(pow(a.dx - b.dx, 2) + pow(a.dy - b.dy, 2));
}


@implementation TFPGCodePreprocessor


- (instancetype)initWithProgram:(TFPGCodeProgram*)program {
	if(!(self = [super init])) return nil;
	
	self.program = program;
	
	return self;
}


- (TFPGCodeProgram*)processUsingParameters:(TFPPrintParameters*)parameters {
	return nil;
}


- (double)boundedTemperature:(double)temperature {
	return MIN(MAX(temperature, 150), 285);
}


- (CGVector)CGVectorFromGCode:(TFPGCode *)code {
	return CGVectorMake([code valueForField:'X'], [code valueForField:'Y']);
}


- (BOOL)isSharpCornerFromLine:(TFPGCode *)currLine toLine:(TFPGCode *)prevLine {
	CGVector vector = [self CGVectorFromGCode:currLine];
	CGVector vector2 = [self CGVectorFromGCode:prevLine];
	
	double num = pow(TFPVectorDot(vector, vector), 2);
	double num2 = pow(TFPVectorDot(vector2, vector2), 2);
	double num3 = acos(TFPVectorDot(vector, vector2) / (num * num2));
	
	return num3 > 0 && num3 < M_PI_2;
}


- (TFPGCode *)makeTackPointForCurrentLine:(TFPGCode *)currLine lastTackPoint:(TFPGCode *)lastTackPoint {
	CGVector a = [self CGVectorFromGCode:currLine];
	CGVector b = [self CGVectorFromGCode:lastTackPoint];
	
	NSUInteger dwellTimeMilliseconds = ceil(CGVectorDistance(a, b));
	if (dwellTimeMilliseconds > 5) {
		return [[TFPGCode codeWithString:@"G4"] codeBySettingField:'P' toValue:dwellTimeMilliseconds];
	}else{
		return nil;
	}
}



@end