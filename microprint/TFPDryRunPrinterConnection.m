//
//  TFPDryRunPrinterConnection.m
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-08-24.
//  Copyright © 2015 Tomas Franzén. All rights reserved.
//

#import "TFPDryRunPrinterConnection.h"
#import "TFPGCode.h"


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
	NSString *response = @"ok";
	
	NSInteger M = [code valueForField:'M' fallback:-1];
	
	switch(M) {
		case 114:
			response = @"ok";
			break;
	}
	
	dispatch_after(dispatch_time(0, 0.001 * NSEC_PER_SEC), self.serialPortQueue, ^{
		[self processIncomingString:response];
	});
}


- (void)openWithCompletionHandler:(void(^)(NSError *error))completionHandler {
	self.state = TFPPrinterConnectionStatePending;
	self.connectionCompletionHandler = completionHandler;

	dispatch_after(dispatch_time(0, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		[self finishEstablishment];
	});
}



@end
