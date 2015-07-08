//
//  TFPCLIController.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPCLIController.h"
#import "TFPGCode.h"
#import "TFPGCodeProgram.h"

#import "TFPFeedRateConversionPreprocessor.h"
#import "TFPBasicPreparationPreprocessor.h"
#import "TFPBedCompensationPreprocessor.h"
#import "TFPBacklashPreprocessor.h"
#import "TFPThermalBondingPreprocessor.h"
#import "TFPWaveBondingPreprocessor.h"

#import "TFPPrinterManager.h"
#import "TFPPrinter.h"
#import "Extras.h"
#import "TFPDryRunPrinter.h"
#import "TFPPrintJob.h"
#import "TFPRepeatingCommandSender.h"
#import "TFPExtrusionOperation.h"
#import "TFPRaiseHeadOperation.h"

#import "MAKVONotificationCenter.h"
#import "GBCli.h"


@interface TFPCLIController ()
@property TFPPrinter *printer;

@property TFPPrintJob *printJob;
@property TFPExtrusionOperation *extrusionOperation;
@property TFPRaiseHeadOperation *raiseHeadOperation;
@end



@implementation TFPCLIController


- (void)runWithArgumentCount:(int)argc arguments:(char **)argv {
	__weak __typeof__(self) weakSelf = self;
	
	GBSettings *factoryDefaults = [GBSettings settingsWithName:@"Factory" parent:nil];
	[factoryDefaults setInteger:0 forKey:@"temperature"];
	[factoryDefaults setObject:@"PLA" forKey:@"filament"];
	[factoryDefaults setInteger:70 forKey:@"height"];
	[factoryDefaults setInteger:1 forKey:@"buffer"];
	
	[factoryDefaults setBool:YES forKey:@"wavebonding"];
	[factoryDefaults setBool:YES forKey:@"backlash"];
	[factoryDefaults setInteger:1200 forKey:@"backlashSpeed"];

	[factoryDefaults setBool:NO forKey:@"dryrun"];
	[factoryDefaults setBool:NO forKey:@"help"];
	[factoryDefaults setBool:NO forKey:@"verbose"];
	
	GBSettings *settings = [GBSettings settingsWithName:@"CmdLine" parent:factoryDefaults];
	
	GBCommandLineParser *parser = [GBCommandLineParser new];
	[parser registerOption:@"temperature" shortcut:0 requirement:GBValueOptional];
	[parser registerOption:@"filament" shortcut:0 requirement:GBValueOptional];
	[parser registerOption:@"buffer" shortcut:0 requirement:GBValueOptional];
	[parser registerOption:@"height" shortcut:0 requirement:GBValueOptional];
	
	[parser registerOption:@"output" shortcut:0 requirement:GBValueOptional];
	[parser registerOption:@"dryrun" shortcut:0 requirement:GBValueNone];
	[parser registerOption:@"help" shortcut:0 requirement:GBValueNone];
	[parser registerOption:@"verbose" shortcut:0 requirement:GBValueNone];
	
	[parser registerOption:@"wavebonding" shortcut:0 requirement:GBValueNone];
	[parser registerOption:@"backlash" shortcut:0 requirement:GBValueNone];
	[parser registerOption:@"backlashSpeed" shortcut:0 requirement:GBValueOptional];

	[parser registerSettings:settings];
	if(![parser parseOptionsWithArguments:argv count:argc]) {
		exit(EXIT_FAILURE);
	}
	
	if([settings boolForKey:@"help"]) {
		[self printHelp];
		exit(EXIT_SUCCESS);
	}
	
	NSString *command = parser.arguments.firstObject;
	if(!command) {
		TFLog(@"Missing command");
		[self printHelp];
		exit(EXIT_FAILURE);
	}
	
	NSString *valueString = parser.arguments.count >= 2 ? parser.arguments[1] : nil;
	
	self.printer = [TFPPrinterManager sharedManager].printers.firstObject;
	
	if([settings boolForKey:@"dryrun"]) {
		self.printer = [TFPDryRunPrinter new];
		[self performCommand:command withArgument:valueString usingSettings:settings];
		
	}else{
		if(!weakSelf.printer) {
			TFLog(@"No connected printer found!");
			exit(EXIT_FAILURE);
		}
		
		[weakSelf.printer establishConnectionWithCompletionHandler:^(NSError *error) {
			TFPPrinter *printer = weakSelf.printer;
			if(!error) {
				TFLog(@"Connected to printer %@ with firmware version %@.", printer.serialNumber, printer.firmwareVersion);
				[self performCommand:command withArgument:valueString usingSettings:settings];
			} else {
				TFLog(@"Failed to connect to printer. Make sure the M3D spooler isn't running (hogging the connection) and try again.");
				exit(EXIT_FAILURE);
			}
		}];
	}
	
	for(;;) [[NSRunLoop currentRunLoop] run];
}


- (void)printHelp {
	TFLog(@"MicroPrint by Tomas Franzén, tomas@tomasf.se");
	TFLog(@"Spooler and utility program for the M3D Micro 3D printer.");
	TFLog(@"Built %s, %s", __DATE__, __TIME__);
	
	TFLog(@"");
	TFLog(@"Usage: microprint <command> [options]");
	TFLog(@"");
	
	TFLog(@"Commands:");
	TFLog(@"  print <gcode-path> [--temperature 210] [--filament PLA] [--backlash] [--backlashSpeed 1200] [--wavebonding]");
	TFLog(@"    Prints a G-code file.");
	
	TFLog(@"  preprocess <gcode-path> [--output path]");
	TFLog(@"    Applies pre-processing to a G-code file and writes it to a file or stdout. Also accepts same options as 'print'.");
	
	TFLog(@"  off");
	TFLog(@"    Turn off fan, heater and motors.");
	
	TFLog(@"  extrude [--temperature 210]");
	TFLog(@"    Extrude filament. Useful for loading new filament.");
	
	TFLog(@"  retract [--temperature 210]");
	TFLog(@"    \"Reverse extrude\" that feeds filament backwards. Useful for unloading filament.");
	
	TFLog(@"  raise [--height 70]");
	TFLog(@"    Raises the print head until you press Return or it reaches the set limit (default is 70 mm)");
	
	
	TFLog(@"");
	TFLog(@"Options:");
	TFLog(@"  --dryrun: Don't connect to an actual printer; instead simulate a mock printer that echos sent G-codes.");
	TFLog(@"  --temperature <number>: Heater temperature in degrees Celsius. Default is 210 for extrusion/retraction and varies depending on filament type for printing.");
	TFLog(@"  --filament <string>: Filament type. Valid options are PLA, ABS, HIPS and Other. Affects behavior in some preprocessors. Also sets default temperature.");
	TFLog(@"  --wavebonding: Use wave bonding. On by default. Turn off with --wavebonding=0");
	TFLog(@"  --backlash: Use backlash compensation. On by default. Turn off with --backlash=0");
	TFLog(@"  --backlashSpeed <number>: The 'F' speed to use for inserted backlash compensation codes. Default is currently 1200, which seems to produce better prints. Old M3D value is 2900.");
}



- (TFPPrintParameters*)printParametersForSettings:(GBSettings*)settings {
	TFPPrintParameters *params = [TFPPrintParameters new];
	params.bufferSize = [settings integerForKey:@"buffer"];
	params.verbose = [settings boolForKey:@"verbose"];
	params.useWaveBonding = [settings boolForKey:@"wavebonding"];
	params.useBacklashCompensation = [settings boolForKey:@"backlash"];
	params.backlashCompensationSpeed = [settings floatForKey:@"backlashSpeed"];
	
	params.filamentType = [self parseFilamentType:[settings objectForKey:@"filament"]];
	if(params.filamentType == TFPFilamentTypeUnknown) {
		TFLog(@"Unknown filament type specified.");
		exit(EXIT_FAILURE);
	}
	
	double temperature = [settings floatForKey:@"temperature"];
	params.idealTemperature = (temperature > 0) ? temperature : [self defaultTemperatureForFilament:params.filamentType];

	return params;
}


- (void)performCommand:(NSString *)command withArgument:(NSString *)value usingSettings:(GBSettings *)settings {
	if([command isEqual:@"extrude"] || [command isEqual:@"retract"]) {
		
		double temperature = [settings floatForKey:@"temperature"];
		if(temperature < 1) {
			temperature = 210;
		}
		
		self.extrusionOperation = [[TFPExtrusionOperation alloc] initWithPrinter:self.printer retraction:[command isEqual:@"retract"]];
		[self.extrusionOperation start];
		
		
	}else if([command isEqual:@"print"]) {
		[self printPath:value usingParameters:[self printParametersForSettings:settings]];
		
	}else if([command isEqual:@"preprocess"]) {
		[self preprocessGCodePath:value outputPath:[settings objectForKey:@"output"] usingParameters:[self printParametersForSettings:settings]];
		
	}else if([command isEqualTo:@"off"]) {
		[self turnOff];
		
	}else if([command isEqualTo:@"raise"]) {
		self.raiseHeadOperation = [[TFPRaiseHeadOperation alloc] initWithPrinter:self.printer];
		self.raiseHeadOperation.targetHeight = [settings floatForKey:@"height"];
		[self.raiseHeadOperation start];
		
	}else{
		TFLog(@"Invalid command '%@'", command);
		exit(EXIT_FAILURE);
	}
}


- (void)turnOff {
	__weak TFPPrinter *printer = self.printer;

	TFPGCode *heaterOff = [TFPGCode codeWithString:@"M104 S0"];
	TFPGCode *motorsOff = [TFPGCode codeWithString:@"M18"];
	TFPGCode *fansOff = [TFPGCode codeWithString:@"M107"];
	
	[printer sendGCode:heaterOff responseHandler:^(BOOL success, NSString *value) {
		[printer sendGCode:fansOff responseHandler:^(BOOL success, NSString *value) {
			[printer sendGCode:motorsOff responseHandler:^(BOOL success, NSString *value) {
				exit(EXIT_SUCCESS);
			}];
		}];
	}];
}


- (TFPGCodeProgram *)programByPreprocessingProgram:(TFPGCodeProgram *)program usingParameters:(TFPPrintParameters *)params {
	program = [[[TFPBasicPreparationPreprocessor alloc] initWithProgram:program] processUsingParameters:params];
		
	if(params.useWaveBonding) {
		program = [[[TFPWaveBondingPreprocessor alloc] initWithProgram:program] processUsingParameters:params];
	}
	
	program = [[[TFPThermalBondingPreprocessor alloc] initWithProgram:program] processUsingParameters:params];
	program = [[[TFPBedCompensationPreprocessor alloc] initWithProgram:program] processUsingParameters:params];
	
	if(params.useBacklashCompensation) {
		program = [[[TFPBacklashPreprocessor alloc] initWithProgram:program] processUsingParameters:params];
	}
	
	program = [[[TFPFeedRateConversionPreprocessor alloc] initWithProgram:program] processUsingParameters:params];
	return program;
}


- (void)printPath:(NSString *)path usingParameters:(TFPPrintParameters *)params {
	__weak TFPPrinter *printer = self.printer;
	__weak __typeof__(self) weakSelf = self;
	
	if(!path.length) {
		TFLog(@"Missing G-code file path!");
		exit(EXIT_FAILURE);
	}
	
	NSURL *file = [NSURL fileURLWithPath:path];
	
	uint64_t start = TFNanosecondTime();
	__block TFPGCodeProgram *program = [[TFPGCodeProgram alloc] initWithFileURL:file];
	
	NSTimeInterval readDuration = (double)(TFNanosecondTime()-start) / NSEC_PER_SEC;
	TFLog(@"Input G-code program consists of %d lines.", readDuration, (int)program.lines.count, (int)(program.lines.count / readDuration));
	
	NSDateComponentsFormatter *durationFormatter = [NSDateComponentsFormatter new];
	durationFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleShort;
	
	NSNumberFormatter *longPercentFormatter = [NSNumberFormatter new];
	longPercentFormatter.minimumIntegerDigits = 1;
	longPercentFormatter.minimumFractionDigits = 2;
	longPercentFormatter.numberStyle = NSNumberFormatterPercentStyle;
	
	NSNumberFormatter *shortPercentFormatter = [NSNumberFormatter new];
	shortPercentFormatter.minimumIntegerDigits = 1;
	shortPercentFormatter.minimumFractionDigits = 0;
	shortPercentFormatter.maximumFractionDigits = 0;
	shortPercentFormatter.numberStyle = NSNumberFormatterPercentStyle;
	
	TFP3DVector *size = [program measureSize];
	TFLog(@"Print dimensions: X: %.02f mm, Y: %.02f mm, Z: %.02f mm", size.x.doubleValue, size.y.doubleValue, size.z.doubleValue);
	params.maxZ = size.z.doubleValue;
	
	
	[printer fetchBedOffsetsWithCompletionHandler:^(BOOL success, TFPBedLevelOffsets offsets) {
		params.bedLevelOffsets = offsets;
		[printer fetchBacklashValuesWithCompletionHandler:^(BOOL success, TFPBacklashValues values) {
			params.backlashValues = values;
			
			TFLog(@"Pre-processing using bed level %@ and backlash %@ (speed %.0f)", params.bedLevelOffsetsAsString, params.backlashValuesAsString, params.backlashCompensationSpeed);
			
			uint64_t start = TFNanosecondTime();
			program = [weakSelf programByPreprocessingProgram:program usingParameters:params];
			
			NSTimeInterval duration = (double)(TFNanosecondTime()-start) / NSEC_PER_SEC;
			TFLog(@"Pre-processed in %@, resulting in a total of %d G-code lines.", [durationFormatter stringFromTimeInterval:duration], (int)program.lines.count);
			
			weakSelf.printJob = [[TFPPrintJob alloc] initWithProgram:program printer:printer printParameters:params];
			
			__block NSString *lastProgressString;
			
			weakSelf.printJob.progressBlock = ^(double progress) {
				NSString *progressString = [longPercentFormatter stringFromNumber:@(progress)];
				if(![progressString isEqual:lastProgressString]) {
					TFLog(@"Printing: %@", progressString);
					lastProgressString = progressString;
				}
			};
			
			weakSelf.printJob.heatingProgressBlock = ^(double targetTemperature, double currentTemperature) {
				TFLog(@"Heating to %.0f°C: %@", targetTemperature, [shortPercentFormatter stringFromNumber:@(currentTemperature/targetTemperature)]);
			};
			
			weakSelf.printJob.completionBlock = ^(NSTimeInterval duration) {
				NSDateComponentsFormatter *formatter = [NSDateComponentsFormatter new];
				formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleShort;
				
				TFLog(@"Done! Print time: %@", [formatter stringFromTimeInterval:duration]);
				exit(EXIT_SUCCESS);
			};
			
			[weakSelf.printJob start];
		}];
	}];
}


- (void)preprocessGCodePath:(NSString *)sourcePath outputPath:(NSString *)destinationPath usingParameters:(TFPPrintParameters *)params {
	NSURL *file = [NSURL fileURLWithPath:sourcePath];
	__weak TFPPrinter *printer = self.printer;
	__weak __typeof__(self) weakSelf = self;

	if(!sourcePath.length) {
		TFLog(@"Missing G-code file path!");
		exit(EXIT_FAILURE);
	}

	uint64_t start = TFNanosecondTime();
	__block TFPGCodeProgram *program = [[TFPGCodeProgram alloc] initWithFileURL:file];
	
	NSTimeInterval readDuration = (double)(TFNanosecondTime()-start) / NSEC_PER_SEC;
	TFLog(@"Input G-code program consists of %d lines.", readDuration, (int)program.lines.count, (int)(program.lines.count / readDuration));
	
	TFP3DVector *size = [program measureSize];
	TFLog(@"Print dimensions: X: %.02f mm, Y: %.02f mm, Z: %.02f mm", size.x.doubleValue, size.y.doubleValue, size.z.doubleValue);
	params.maxZ = size.z.doubleValue;
	
	
	[printer fetchBedOffsetsWithCompletionHandler:^(BOOL success, TFPBedLevelOffsets offsets) {
		params.bedLevelOffsets = offsets;
		[printer fetchBacklashValuesWithCompletionHandler:^(BOOL success, TFPBacklashValues values) {
			params.backlashValues = values;
			
			TFLog(@"Pre-processing using bed level %@ and backlash %@", params.bedLevelOffsetsAsString, params.backlashValuesAsString);
			
			uint64_t start = TFNanosecondTime();
			program = [weakSelf programByPreprocessingProgram:program usingParameters:params];
			
			TFLog(@"Pre-processed in %.02f seconds, resulting in a total of %d G-code lines.", (double)(TFNanosecondTime()-start) / NSEC_PER_SEC, (int)program.lines.count);
			
			if(destinationPath) {
				NSURL *destinationURL = [NSURL fileURLWithPath:destinationPath];
				NSError *error;
				if (![program writeToFileURL:destinationURL error:&error]) {
					TFLog(@"Writing to file failed: %@", error);
					exit(EXIT_FAILURE);
				}
			}else{
				for(TFPGCode *code in program.lines) {
					TFLog(@"%@", code.ASCIIRepresentation);
				}
			}
			exit(EXIT_SUCCESS);
		}];
	}];
}


- (TFPFilamentType)parseFilamentType:(NSString *)string {
	NSDictionary *names = @{
							@"pla" : @(TFPFilamentTypePLA),
							@"abs" : @(TFPFilamentTypeABS),
							@"hips" : @(TFPFilamentTypeHIPS),
							@"other" : @(TFPFilamentTypeOther),
							};
	NSNumber *type = names[string.lowercaseString];
	return type ? type.integerValue : TFPFilamentTypeUnknown;
}


- (double)defaultTemperatureForFilament:(TFPFilamentType)type {
	return [@{
			  @(TFPFilamentTypePLA): @210,
			  @(TFPFilamentTypeABS): @265,
			  @(TFPFilamentTypeHIPS): @245,
			  @(TFPFilamentTypeOther): @210,
			  }[@(type)] doubleValue];
}


@end