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

#import "TFPPrinterManager.h"
#import "TFPPrinter.h"
#import "TFPExtras.h"
#import "TFPDryRunPrinter.h"
#import "TFPPrintJob.h"
#import "TFPExtrusionOperation.h"
#import "TFPRaiseHeadOperation.h"
#import "TFPGCodeConsoleOperation.h"
#import "TFPPreprocessing.h"
#import "TFPBedLevelCalibration.h"
#import "TFPGCodeHelpers.h"
#import "TFPGCodeHelpers.h"
#import "TFPZeroBedOperation.h"

#import "MAKVONotificationCenter.h"
#import "GBCli.h"


@interface TFPCLIController ()
@property TFPPrinter *printer;
@property TFPOperation *operation;
@property dispatch_source_t interruptSource;

@property NSNumberFormatter *shortPercentFormatter;
@property NSNumberFormatter *longPercentFormatter;
@property NSDateComponentsFormatter *durationFormatter;
@end



@implementation TFPCLIController


- (instancetype)init {
	if(!(self = [super init])) return nil;
	
	self.shortPercentFormatter = [NSNumberFormatter new];
	self.shortPercentFormatter.minimumIntegerDigits = 1;
	self.shortPercentFormatter.minimumFractionDigits = 0;
	self.shortPercentFormatter.maximumFractionDigits = 0;
	self.shortPercentFormatter.numberStyle = NSNumberFormatterPercentStyle;
	
	self.longPercentFormatter = [NSNumberFormatter new];
	self.longPercentFormatter.minimumIntegerDigits = 1;
	self.longPercentFormatter.minimumFractionDigits = 2;
	self.longPercentFormatter.numberStyle = NSNumberFormatterPercentStyle;

	self.durationFormatter = [NSDateComponentsFormatter new];
	self.durationFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleShort;
	
	return self;
}


- (void)runWithArgumentCount:(int)argc arguments:(char **)argv {
	__weak __typeof__(self) weakSelf = self;
	
	GBSettings *factoryDefaults = [GBSettings settingsWithName:@"Factory" parent:nil];
	[factoryDefaults setInteger:0 forKey:@"temperature"];
	[factoryDefaults setObject:@"PLA" forKey:@"filament"];
	[factoryDefaults setInteger:70 forKey:@"height"];
	[factoryDefaults setFloat:2 forKey:@"start"];
	[factoryDefaults setFloat:0.3 forKey:@"target"];
	[factoryDefaults setInteger:1 forKey:@"buffer"];
	
	[factoryDefaults setBool:YES forKey:@"wavebonding"];
	[factoryDefaults setBool:YES forKey:@"backlash"];

	[factoryDefaults setBool:NO forKey:@"dryrun"];
	[factoryDefaults setBool:NO forKey:@"help"];
	[factoryDefaults setBool:NO forKey:@"verbose"];
	
	GBSettings *settings = [GBSettings settingsWithName:@"CmdLine" parent:factoryDefaults];
	
	GBCommandLineParser *parser = [GBCommandLineParser new];
	[parser registerOption:@"temperature" shortcut:0 requirement:GBValueOptional];
	[parser registerOption:@"filament" shortcut:0 requirement:GBValueOptional];
	[parser registerOption:@"buffer" shortcut:0 requirement:GBValueOptional];
	[parser registerOption:@"height" shortcut:0 requirement:GBValueOptional];
	[parser registerOption:@"start" shortcut:0 requirement:GBValueOptional];
	[parser registerOption:@"target" shortcut:0 requirement:GBValueOptional];
	
	[parser registerOption:@"output" shortcut:0 requirement:GBValueOptional];
	[parser registerOption:@"dryrun" shortcut:0 requirement:GBValueNone];
	[parser registerOption:@"help" shortcut:0 requirement:GBValueNone];
	[parser registerOption:@"verbose" shortcut:0 requirement:GBValueNone];
	
	[parser registerOption:@"wavebonding" shortcut:0 requirement:GBValueNone];
	[parser registerOption:@"backlash" shortcut:0 requirement:GBValueNone];

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
		TFLog(@"Using dry-run simulated printer.");
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
	TFLog(@"  print <gcode-path> [--temperature 215] [--filament PLA] [--backlash] [--wavebonding]");
	TFLog(@"    Prints a G-code file.");
	
	TFLog(@"  preprocess <gcode-path> [--output path]");
	TFLog(@"    Applies pre-processing to a G-code file and writes it to a file or stdout. Also accepts same options as 'print'.");

	TFLog(@"  console");
	TFLog(@"    Starts an interactive console where you can send arbitrary G-codes to the printer.");
	
	TFLog(@"  off");
	TFLog(@"    Turn off fan, heater and motors.");
	
	TFLog(@"  extrude [--temperature 230]");
	TFLog(@"    Extrude filament. Useful for loading new filament.");
	
	TFLog(@"  retract [--temperature 275]");
	TFLog(@"    \"Reverse extrude\" that feeds filament backwards. Useful for unloading filament.");
	
	TFLog(@"  raise [--height 70]");
	TFLog(@"    Raises the print head until you press Return or it reaches the set limit (default is 70 mm)");

    TFLog(@"  zerobed");
    TFLog(@"    Calibrates the zero Z location for the bed. This takes two or three minutes and does not change bed height calibration values.");
	
    TFLog(@"  values");
    TFLog(@"    Queries the printer for Bed level and Backlash values and displays the results. Record this information so that the values may be restored easily in case they are erased.");

	TFLog(@"");
	TFLog(@"Options:");
	TFLog(@"  --dryrun: Don't connect to an actual printer; instead simulate a mock printer that echos sent G-codes.");
	TFLog(@"  --temperature <number>: Heater temperature in degrees Celsius. Default is 215 for extrusion/retraction and varies depending on filament type for printing.");
	TFLog(@"  --filament <string>: Filament type. Valid options are PLA, ABS, HIPS and Other. Affects behavior in some preprocessors. Also sets default temperature.");
	TFLog(@"  --wavebonding: Use wave bonding. On by default. Turn off with --wavebonding=0");
	TFLog(@"  --backlash: Use backlash compensation. On by default. Turn off with --backlash=0");
	TFLog(@"  --rawFeedRates: For the console command, this turns off conversion of feed rates to M3D-style inverted feed rates.");
}



- (TFPPrintParameters*)printParametersForSettings:(GBSettings*)settings {
	TFPPrintParameters *params = [TFPPrintParameters new];
	params.bufferSize = [settings integerForKey:@"buffer"];
	params.verbose = [settings boolForKey:@"verbose"];
	params.useWaveBonding = [settings boolForKey:@"wavebonding"];
	params.useBacklashCompensation = [settings boolForKey:@"backlash"];
	
	params.filament = [TFPFilament filamentForType:[TFPFilament typeForString:[settings objectForKey:@"filament"]]];
	if(!params.filament) {
		TFLog(@"Unknown filament type specified.");
		exit(EXIT_FAILURE);
	}
	
	double temperature = [settings floatForKey:@"temperature"];
	params.idealTemperature = temperature;

	return params;
}


- (void)extrudeOrRetract:(BOOL)retract temperature:(double)temperature {
	TFPExtrusionOperation *extrusionOperation = [[TFPExtrusionOperation alloc] initWithPrinter:self.printer retraction:retract];
	extrusionOperation.temperature = temperature;
	__weak TFPExtrusionOperation *weakOperation = extrusionOperation;
	
	extrusionOperation.preparationProgressBlock = ^(double progress) {
		TFLog(@"Preparing: %.0f%%", progress * 100);
	};
	
	extrusionOperation.extrusionStartedBlock = ^{
		TFLog(@"%@. Press Return to stop.", (retract ? @"Retracting" : @"Extruding"));
	};
	
	extrusionOperation.extrusionStoppedBlock = ^{
		exit(EXIT_SUCCESS);
	};
	
	[extrusionOperation start];
	self.operation = extrusionOperation;
	
	TFPListenForInputLine(^(NSString *line) {
		TFLog(@"Stopping...");
		[weakOperation stop];
	});
}


- (void)zerobed {
    TFPZeroBedOperation* zeroOperation = [[TFPZeroBedOperation alloc] initWithPrinter:self.printer];
    __weak TFPZeroBedOperation* weakOperation = zeroOperation;

    zeroOperation.progressFeedback = ^(NSString* msg){
        TFLog(msg);
    };

    zeroOperation.didStopBlock = ^(BOOL completed) {
        TFLog(@"Complete");
        exit(EXIT_SUCCESS);
    };

    self.operation = zeroOperation;
    [zeroOperation start];

    TFPListenForInputLine(^(NSString *line) {
        TFLog(@"Stopping...");
        [weakOperation stop];
    });
}


- (void)performCommand:(NSString *)command withArgument:(NSString *)value usingSettings:(GBSettings *)settings {
	command = [command lowercaseString];
	
	if([command isEqual:@"extrude"] || [command isEqual:@"retract"]) {
		double temperature = [settings floatForKey:@"temperature"];
		if(temperature < 1) {
			temperature = 215;
		}
		[self extrudeOrRetract:[command isEqual:@"retract"] temperature:temperature];
		
	}else if([command isEqual:@"print"]) {
		[self printPath:value usingParameters:[self printParametersForSettings:settings]];
		
	}else if([command isEqual:@"preprocess"]) {
		[self preprocessGCodePath:value outputPath:[settings objectForKey:@"output"] usingParameters:[self printParametersForSettings:settings]];
		
	}else if([command isEqualTo:@"off"]) {
		[self turnOff];
		
	}else if([command isEqualTo:@"home"]) {
		[self home];
		
	}else if([command isEqualTo:@"raise"]) {
		TFPRaiseHeadOperation *raiseHeadOperation = [[TFPRaiseHeadOperation alloc] initWithPrinter:self.printer];
		raiseHeadOperation.targetHeight = [settings floatForKey:@"height"];
		
		raiseHeadOperation.didStartBlock = ^{
			TFLog(@"Raising print head. Press Return to stop.");
		};
		
		raiseHeadOperation.didStopBlock = ^(BOOL didMove) {
			if(!didMove) {
				TFLog(@"Head is already at or above target height.");
			}
			exit(EXIT_SUCCESS);
		};
		
		[raiseHeadOperation start];
		self.operation = raiseHeadOperation;
		
		TFPListenForInputLine(^(NSString *line) {
			[raiseHeadOperation stop];
		});
		
	}else if([command isEqual:@"console"]) {
		TFPGCodeConsoleOperation *consoleOperation = [[TFPGCodeConsoleOperation alloc] initWithPrinter:self.printer];
		[consoleOperation start];
		self.operation = consoleOperation;
		
	}else if([command isEqual:@"values"]) {
		TFPPrintParameters *params = [TFPPrintParameters new];
		[self.printer fillInOffsetAndBacklashValuesInPrintParameters:params completionHandler:^(BOOL success) {
			TFLog(@"Bed level: %@", TFPBedLevelOffsetsDescription(params.bedLevelOffsets));
			TFLog(@"Backlash values: %@", TFPBacklashValuesDescription(params.backlashValues));
			exit(EXIT_SUCCESS);
		}];
		
	}else if([command isEqual:@"zerobed"]) {
        [self zerobed];
//        exit(EXIT_SUCCESS);
    }else{
		TFLog(@"Invalid command '%@'", command);
		exit(EXIT_FAILURE);
	}
}


- (void)home {
	[self.printer sendGCode:[TFPGCode codeWithString:@"G28"] responseHandler:^(BOOL success, NSDictionary *value) {
		[self.printer fetchPositionWithCompletionHandler:^(BOOL success, TFP3DVector *position, NSNumber *E) {
			TFLog(@"%@", position);
			exit(EXIT_SUCCESS);
		}];
	}];
}


- (void)turnOff {
	__weak TFPPrinter *printer = self.printer;

	TFPGCode *heaterOff = [TFPGCode codeWithString:@"M104 S0"];
	TFPGCode *motorsOff = [TFPGCode codeWithString:@"M18"];
	TFPGCode *fansOff = [TFPGCode codeWithString:@"M107"];
	
	[printer sendGCode:heaterOff responseHandler:^(BOOL success, NSDictionary *value) {
		[printer sendGCode:fansOff responseHandler:^(BOOL success, NSDictionary *value) {
			[printer sendGCode:motorsOff responseHandler:^(BOOL success, NSDictionary *value) {
				exit(EXIT_SUCCESS);
			}];
		}];
	}];
}


- (TFPGCodeProgram*)readProgramAtPathAndLogInfo:(NSString*)path usingPrintParameters:(TFPPrintParameters*)params {
	if(!path.length) {
		TFLog(@"Missing G-code file path!");
		return nil;
	}
	
	NSURL *file = [NSURL fileURLWithPath:path];
	
	uint64_t start = TFNanosecondTime();
	TFPGCodeProgram *program = [[TFPGCodeProgram alloc] initWithFileURL:file error:nil];
	
	if(!program) {
		TFLog(@"Failed to read G-code program at path: %@", path);
		return nil;
	}
	
	NSTimeInterval readDuration = (double)(TFNanosecondTime()-start) / NSEC_PER_SEC;
	TFLog(@"Input G-code program consists of %d lines.", readDuration, (int)program.lines.count, (int)(program.lines.count / readDuration));

	TFPCuboid box = [program measureBoundingBox];
	TFLog(@"Print dimensions: X: %.02f mm, Y: %.02f mm, Z: %.02f mm", box.xSize, box.ySize, box.zSize);
	params.boundingBox = box;

	return program;
}


- (TFPGCodeProgram*)preprocessProgramAndLogInfo:(TFPGCodeProgram*)program usingPrintParameters:(TFPPrintParameters*)params {
	NSString *offsetsString = TFPBedLevelOffsetsDescription(params.bedLevelOffsets);
	NSString *backlashString = TFPBacklashValuesDescription(params.backlashValues);
	TFLog(@"Pre-processing using bed level %@ and backlash %@", offsetsString, backlashString);
	
	uint64_t start = TFNanosecondTime();
	program = [TFPPreprocessing programByPreprocessingProgram:program usingParameters:params];
	
	NSTimeInterval duration = (double)(TFNanosecondTime()-start) / NSEC_PER_SEC;
	TFLog(@"Pre-processed in %@, resulting in a total of %d G-code lines.", [self.durationFormatter stringFromTimeInterval:duration], (int)program.lines.count);
	
	return program;
}


- (void)printPath:(NSString *)path usingParameters:(TFPPrintParameters *)params {
	__weak TFPPrinter *printer = self.printer;
	__weak __typeof__(self) weakSelf = self;
	
	__block TFPGCodeProgram *program = [self readProgramAtPathAndLogInfo:path usingPrintParameters:params];
	if(!program) {
		exit(EXIT_FAILURE);
	}

	[self.printer fillInOffsetAndBacklashValuesInPrintParameters:params completionHandler:^(BOOL success) {
		program = [weakSelf preprocessProgramAndLogInfo:program usingPrintParameters:params];
		
		TFPPrintJob *printJob = [[TFPPrintJob alloc] initWithProgram:program printer:printer printParameters:params];
		__weak TFPPrintJob *weakPrintJob = printJob;
		__block NSString *lastProgressString;
		
		printJob.progressBlock = ^() {
			double progress = (double)weakPrintJob.completedRequests / weakPrintJob.program.lines.count;
			NSString *progressString = [weakSelf.longPercentFormatter stringFromNumber:@(progress)];
			if(![progressString isEqual:lastProgressString]) {
				TFPEraseLastLine();
				TFLog(@"Printing: %@", progressString);
				lastProgressString = progressString;
			}
		};
		
		printJob.heatingProgressBlock = ^(double targetTemperature, double currentTemperature) {
			TFPEraseLastLine();
			TFLog(@"Heating to %.0f°C: %@", targetTemperature, [weakSelf.shortPercentFormatter stringFromNumber:@(currentTemperature/targetTemperature)]);
		};
		
		printJob.abortionBlock = ^ {
			NSTimeInterval duration = weakPrintJob.elapsedTime;
			TFLog(@"Print cancelled after %@.", [weakSelf.durationFormatter stringFromTimeInterval:duration]);
			exit(EXIT_SUCCESS);
		};
		
		printJob.completionBlock = ^ {
			NSTimeInterval duration = weakPrintJob.elapsedTime;
			TFLog(@"Done! Print time: %@", [weakSelf.durationFormatter stringFromTimeInterval:duration]);
			exit(EXIT_SUCCESS);
		};
		
		
		weakSelf.interruptSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGINT, 0, dispatch_get_main_queue());
		dispatch_source_set_event_handler(weakSelf.interruptSource, ^{
			TFLog(@"Cancelling print...");
			[weakPrintJob abort];
		});
		dispatch_resume(weakSelf.interruptSource);
		
		struct sigaction action = { 0 };
		action.sa_handler = SIG_IGN;
		sigaction(SIGINT, &action, NULL);
		
		[printJob start];
		weakSelf.operation = printJob;
	}];
}


- (void)preprocessGCodePath:(NSString *)sourcePath outputPath:(NSString *)destinationPath usingParameters:(TFPPrintParameters *)params {
	__weak __typeof__(self) weakSelf = self;

	__block TFPGCodeProgram *program = [self readProgramAtPathAndLogInfo:sourcePath usingPrintParameters:params];
	if(!program) {
		exit(EXIT_FAILURE);
	}
	
	[self.printer fillInOffsetAndBacklashValuesInPrintParameters:params completionHandler:^(BOOL success) {
		program = [weakSelf preprocessProgramAndLogInfo:program usingPrintParameters:params];
		
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
}


@end