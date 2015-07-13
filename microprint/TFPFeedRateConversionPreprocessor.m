//
//  TFPFeedRateConversionPreprocessor.m
//  MicroPrint
//
//  Created by Tomas Franzén on Mon 2015-06-22.
//

// Converts feedrate from standard mm/minute to micro-specific inverted feed rate
// Slowest: 830 = 0 mm/s
// Fastest: 30 = 60 mm/s
// Corresponds to Micro3DSpooler.Spooler_Server.SimpleFeedRateFixer


#import "TFPFeedRateConversionPreprocessor.h"
#import "TFPGCode.h"
#import "TFPPrinter.h"
#import "TFPGCodeHelpers.h"


@implementation TFPFeedRateConversionPreprocessor


- (TFPGCodeProgram*)processUsingParameters:(TFPPrintParameters*)parameters {
	NSMutableArray *output = [NSMutableArray new];
	
	for(__strong TFPGCode *line in self.program.lines) {
		if([line hasField:'G'] && [line hasField:'F']) {
			double feedRate = line.feedRate;
			feedRate = [TFPGCode convertFeedRate:feedRate];
			line = [line codeBySettingField:'F' toValue:feedRate];
		}
		
		[output addObject:line];
	}
	
	return [[TFPGCodeProgram alloc] initWithLines:output];
}


@end
