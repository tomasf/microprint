//
//  TFPDryRunPrinterConnection.m
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-08-24.
//  Copyright © 2015 Tomas Franzén. All rights reserved.
//

#import "TFPDryRunPrinterConnection.h"
#import "TFPGCode.h"
#import "TFPGCodeHelpers.h"
#import "TFPExtras.h"
#import "TFPPrinter+VirtualEEPROM.h"


@interface TFPPrinterConnection (Private)
- (void)processIncomingString:(NSString*)incomingLine;
@property dispatch_queue_t serialPortQueue;
@property (readwrite) TFPPrinterConnectionState state;
- (void)finishEstablishment;
@property (copy) void(^connectionCompletionHandler)(NSError *error);
@end



@implementation TFPDryRunPrinterConnection


- (instancetype)init {
	return [super initWithSerialPort:nil];
}


- (void)sendGCode:(TFPGCode*)code {
	NSInteger M = [code valueForField:'M' fallback:-1];
	NSDictionary *values = nil;
	
	switch(M) {
		case 115:
			values = @{@"X-SERIAL_NUMBER": @"DRYRUN0000123456"};
			break;
			
		case 619: {
			NSInteger index = [code valueForField:'S'];
			float value = 0;
			
			switch(index) {
				case VirtualEEPROMIndexBacklashCompensationX:
					value = 0.33;
					break;
				case VirtualEEPROMIndexBacklashCompensationY:
					value = 0.88;
					break;
				case VirtualEEPROMIndexBacklashCompensationSpeed:
					value = 1500;
					break;
			}
			
			values = @{@"DT": [NSString stringWithFormat:@"%d", [TFPPrinter encodeVirtualEEPROMIntegerValueForFloat:value]]};
			break;
		}
	}
	
	dispatch_after(dispatch_time(0, 0.001 * NSEC_PER_SEC), self.serialPortQueue, ^{
		[self respondOKWithValues:values toCode:code];
	});
}


- (void)respondOKWithValues:(NSDictionary*)values toCode:(TFPGCode*)code {
	NSString *valueString = [[values.allKeys tf_mapWithBlock:^id(NSString *key) {
		return [NSString stringWithFormat:@"%@:%@", key, values[key]];
	}] componentsJoinedByString:@" "] ?: @"";
	NSString *lineNumber = [code hasField:'N'] ? [NSString stringWithFormat:@"%d", code['N'].intValue] : @"";
	NSString *response = [NSString stringWithFormat:@"ok %@ %@", lineNumber, valueString];
	
	[self processIncomingString:response];
}


- (void)openWithCompletionHandler:(void(^)(NSError *error))completionHandler {
	self.state = TFPPrinterConnectionStatePending;
	self.connectionCompletionHandler = completionHandler;

	dispatch_after(dispatch_time(0, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		[self finishEstablishment];
	});
}


@end