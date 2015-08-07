//
//  TFPAppleScriptSupport.m
//  microprint
//
//  Created by Tomas Franzén on Tue 2015-07-21.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPAppleScriptSupport.h"
#import "TFPFilament.h"
#import "TFPPrintingProgressViewController.h"
#import "TFPPrintJob.h"
#import "TFPPrintStatusController.h"
#import "TFPPrinterManager.h"
#import "TFPPrinter.h"
#import "TFPGCodeDocument.h"
#import "TFPExtras.h"


@interface TFPPrintingProgressViewController (Private)
@property TFPPrintJob *printJob;
@property TFPPrintStatusController *printStatusController;
@end


@interface TFPPrintSettingsViewController (Private)
@property TFPPrintingProgressViewController *printingProgressViewController;
- (IBAction)print:(id)sender;
@end


@interface TFPGCodeDocument (Private)
- (TFPPrintSettingsViewController*)printSettingsViewController;
@end



@implementation TFPPrintingProgressViewController (AppleScriptSupport)

- (double)printingProgress {
	return (double)self.printJob.completedRequests / self.printJob.program.lines.count;
}

@end



@implementation TFPPrintSettingsViewController (AppleScriptSupport)

- (BOOL)printing {
	return self.printingProgressViewController != nil;
}

@end



@implementation TFPGCodeDocument (AppleScriptSupport)


- (void)scripting_print:(NSScriptCommand*)command {
	[self.printSettingsViewController print:nil];
}


@end



@implementation NSApplication (AppleScriptSupport)


- (NSArray*)scripting_printers {
	return [TFPPrinterManager sharedManager].printers;
}


- (id)scripting_sendGCode:(NSScriptCommand*)command {
	TFPPrinter *printer = [command.evaluatedArguments objectForKey:@"printer"];
	NSString *codeString = [command.evaluatedArguments objectForKey:@""];
	
	TFPGCode *code = [TFPGCode codeWithString:codeString];
	
	[printer sendGCode:code responseHandler:^(BOOL success, NSDictionary *value) {
		NSMutableDictionary *record = [value mutableCopy];
		record[@"success"] = @(success);
		
		[command resumeExecutionWithResult:record];
	}];
	
	[command suspendExecution];
	return nil;
}


@end




@implementation NSObject (AppleScriptSupport)

- (NSAppleEventDescriptor*)tf_appleEventDescriptor {
	[NSException raise:NSGenericException format:@"tf_appleEventDescriptor not supported for %@", self.class];
	return nil;
}

@end



@implementation NSNull (AppleScriptSupport)

- (NSAppleEventDescriptor*)tf_appleEventDescriptor {
	return [NSAppleEventDescriptor nullDescriptor];
}

@end



@implementation NSArray (AppleScriptSupport)

- (NSAppleEventDescriptor*)tf_appleEventDescriptor {
	NSAppleEventDescriptor *descriptor = [NSAppleEventDescriptor listDescriptor];
	
	[self enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
		[descriptor insertDescriptor:[obj tf_appleEventDescriptor] atIndex:index+1];
	}];
	
	return descriptor;
}

@end



@implementation NSDictionary (AppleScriptSupport)

- (NSAppleEventDescriptor*)tf_appleEventDescriptor {
	NSMutableArray *list = [NSMutableArray new];
	[self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		[list addObject:key];
		[list addObject:obj];
	}];
	
	NSAppleEventDescriptor* recoAed = [NSAppleEventDescriptor recordDescriptor];
	[recoAed setDescriptor:[list tf_appleEventDescriptor] forKeyword:'usrf'];
	return recoAed;
}


- (id)scriptingRecordDescriptor {
	return [self tf_appleEventDescriptor];
}

@end



@implementation NSString (AppleScriptSupport)

- (NSAppleEventDescriptor*)tf_appleEventDescriptor {
	return [NSAppleEventDescriptor descriptorWithString:self];
}


@end


@implementation NSNumber (AppleScriptSupport)

- (NSAppleEventDescriptor*)tf_appleEventDescriptor {
	switch (self.objCType[0]) {
		case 'i':
		case 'c':
		case 's':
		case 'l':
		case 'C':
		case 'I':
		case 'q': {
			int64_t temp = [self longLongValue];
			return [NSAppleEventDescriptor descriptorWithDescriptorType:'comp' bytes:&temp length:sizeof(temp)];
		}
			
		case 'f': {
			float temp = [self floatValue];
			return [NSAppleEventDescriptor descriptorWithDescriptorType:'sing' bytes:&temp length:sizeof(temp)];
		}
		
		case 'd': {
			double temp = [self doubleValue];
			return [NSAppleEventDescriptor descriptorWithDescriptorType:'doub' bytes:&temp length:sizeof(temp)];
		}
			
		case 'B': {
			return [NSAppleEventDescriptor descriptorWithBoolean:[self boolValue]];
		}
	}
	return nil;
}

@end



@implementation TFPPrinter (AppleScriptSupport)

- (NSScriptObjectSpecifier *)objectSpecifier {
	NSScriptClassDescription *containerClassDesc = (NSScriptClassDescription*)[NSScriptClassDescription classDescriptionForClass:[NSApp class]];
	NSArray *printers = [TFPPrinterManager sharedManager].printers;
	NSUInteger printerIndex = [printers indexOfObject:self];
	
	return [[NSIndexSpecifier alloc] initWithContainerClassDescription:containerClassDesc containerSpecifier:nil key:@"printers" index:printerIndex];
}

@end