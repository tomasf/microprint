//
//  TFPBasicPreparationPreprocessor.m
//  MicroPrint
//
//  Created by Tomas Franzén on Mon 2015-06-22.
//

#import "TFPBasicPreparationPreprocessor.h"
#import "TFPGCode.h"
#import "Extras.h"


@implementation TFPBasicPreparationPreprocessor


- (TFPGCodeProgram*)processUsingParameters:(TFPPrintParameters*)parameters {
	BOOL isPLA = parameters.filamentType == TFPFilamentTypePLA;

	NSMutableArray *output = [NSMutableArray new];
	
	NSUInteger fanSpeed = isPLA ? 255 : 50;
	TFPGCode *fanLine = [[TFPGCode codeWithString:@"M106"] codeBySettingField:'S' toValue:fanSpeed];
	[output addObject:fanLine];
	
	[output addObject:[TFPGCode codeWithString:@"M17"]]; // Enable motors
	[output addObject:[TFPGCode codeWithString:@"G90"]]; // Absolute mode
	[output addObject:[[TFPGCode codeWithString:@"M104"] codeBySettingField:'S' toValue:parameters.idealTemperature]]; // Temperature
	[output addObject:[TFPGCode codeWithString:@"G0 Z5 F2900"]]; // Move to 5mm Z?
	[output addObject:[TFPGCode codeWithString:@"G28"]]; // Move to home
	[output addObject:[TFPGCode codeWithString:@"M18"]]; // Disable motors
	[output addObject:[[TFPGCode codeWithString:@"M109"] codeBySettingField:'S' toValue:parameters.idealTemperature]]; // Wait for temperature
	
	[output addObject:[TFPGCode codeWithString:@"G4 S10"]]; // Wait 10 seconds
	
	[output addObject:[TFPGCode codeWithString:@"M17"]]; // Enable motors
	[output addObject:[TFPGCode codeWithString:@"G91"]]; // Relative mode
	[output addObject:[TFPGCode codeWithString:@"G0 E7.5 F2000"]]; // "Prime the nozzle"
	[output addObject:[TFPGCode codeWithString:@"G92 E0"]]; // Reset E to 0
	[output addObject:[TFPGCode codeWithString:@"G90"]]; // Absolute mode
	[output addObject:[TFPGCode codeWithString:@"G0 F2400"]]; // Feed rate 2400
	[output addObject:[TFPGCode codeWithString:@"; can extrude"]]; // Hmm?

	// Add program lines, filtering out those who try to control extruder temperature or fan speed
	[output addObjectsFromArray:[self.program.lines tf_selectWithBlock:^BOOL(TFPGCode *line) {
		if([line hasField:'M']) {
			NSUInteger M = [line valueForField:'M'];
			if(M == 104 || M == 106 || M == 107 || M == 109) {
				return NO;
			}
		}
		return YES;
	}]];
	
	[output addObject:[TFPGCode codeWithString:@"G91"]]; // Relative mode
	[output addObject:[TFPGCode codeWithString:@"G0 E-1 F2000"]]; // Retract
	[output addObject:[TFPGCode codeWithString:@"G0 X5 Y5 F2000"]]; // Retract
	[output addObject:[TFPGCode codeWithString:@"G0 E-8 F2000"]]; // Retract
	[output addObject:[TFPGCode codeWithString:@"M104 S0"]]; // Heater off
	
	if (parameters.maxZ > 60) {
		if (parameters.maxZ < 110) {
			[output addObject:[TFPGCode codeWithString:@"G0 Z3 F2900"]]; // Move up to the back right
		}
		[output addObject:[TFPGCode codeWithString:@"G90"]]; // Absolute mode
		[output addObject:[TFPGCode codeWithString:@"G0 X90 Y84"]]; // Move to the back right a safe distance
	} else {
		[output addObject:[TFPGCode codeWithString:@"G0 Z3 F2900"]]; // Move up to the back right
		[output addObject:[TFPGCode codeWithString:@"G90"]]; // Absolute mode
		[output addObject:[TFPGCode codeWithString:@"G0 X95 Y95"]]; // Move to the back right a safe distance
	}
	
	[output addObject:[TFPGCode codeWithString:@"M107"]]; // Fan off
	[output addObject:[TFPGCode codeWithString:@"M18"]]; // Motors off
	
	return [[TFPGCodeProgram alloc] initWithLines:output];
}


@end
