//
//  TFPPrintJob.m
//  MicroPrint
//
//  Created by Tomas Franzén on Thu 2015-06-25.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrintJob.h"
#import "TFPGCode.h"
#import "Extras.h"

@import IOKit.pwr_mgt;
#import "MAKVONotificationCenter.h"


static const uint16_t lineNumberWrapAround = 100; // UINT16_MAX


@interface TFPPrintJob ()
@property TFPPrintParameters *parameters;
@property TFPGCodeProgram *program;
@property IOPMAssertionID powerAssertionID;

@property NSInteger codeOffset;
@property NSUInteger lineNumber;
@property uint64_t startTime;

@property dispatch_source_t interruptSource;
@property BOOL aborted;

@property double targetTemperature;
@property NSUInteger pendingRequestCount;
@property NSUInteger completedRequests;
@property NSMutableDictionary *sentCodeRegistry;
@end



@implementation TFPPrintJob


- (instancetype)initWithProgram:(TFPGCodeProgram*)program printer:(TFPPrinter*)printer printParameters:(TFPPrintParameters*)params {
	if(!(self = [super initWithPrinter:printer])) return nil;
	
	self.program = [program programByStrippingNonFieldCodes];
	self.parameters = params;
	
	return self;
}


- (void)jobEnded {
	if(self.powerAssertionID != kIOPMNullAssertionID) {
		IOPMAssertionRelease(self.powerAssertionID);
	}
	
	if(self.interruptSource) {
		dispatch_source_cancel(self.interruptSource);
		self.interruptSource = nil;
	}
}


- (NSTimeInterval)elapsedTime {
	return ((double)(TFNanosecondTime() - self.startTime)) / NSEC_PER_SEC;
}


- (void)jobDidComplete {
	[self jobEnded];
	
	if(self.completionBlock) {
		self.completionBlock([self elapsedTime]);
	}
}


- (void)sendGCode:(TFPGCode*)code {
	__weak __typeof__(self) weakSelf = self;
	
	if(self.parameters.verbose) {
		TFLog(@"Sending %@", code);
	}
	
	uint64_t sendTime = TFNanosecondTime();
	self.pendingRequestCount++;
	
	[self.printer sendGCode:code responseHandler:^(BOOL success, NSString *value) {
		weakSelf.pendingRequestCount--;
		weakSelf.completedRequests++;
		[weakSelf sendMoreIfNeeded];
		if(weakSelf.parameters.verbose) {
			TFLog(@"%d of %d codes. Got response for %@ after %.03f s", (int)weakSelf.completedRequests, (int)weakSelf.program.lines.count, code, ((double)(TFNanosecondTime()-sendTime)) / NSEC_PER_SEC);
		}
		if(weakSelf.progressBlock && !self.aborted) {
			weakSelf.progressBlock((double)weakSelf.completedRequests / self.program.lines.count);
		}
	}];
	
	NSUInteger M = [code valueForField:'M'];
	if(M == 104 || M == 109) {
		self.targetTemperature = [code valueForField:'S'];
	}
}


- (TFPGCode*)popNextLine {
	if(self.codeOffset >= self.program.lines.count) {
		return nil;
	}
	
	if(self.lineNumber == lineNumberWrapAround) {
		[self sendLineNumberReset];
	}
	
	TFPGCode *code = self.program.lines[self.codeOffset];
	self.codeOffset++;
	
	code = [code codeBySettingField:'N' toValue:self.lineNumber];
	self.sentCodeRegistry[@(self.lineNumber)] = code;
	self.lineNumber++;
	
	return code;
}


- (void)sendMoreIfNeeded {
	if(self.aborted) {
		return;
	}
	
	while(self.pendingRequestCount < self.parameters.bufferSize) {
		TFPGCode *code = [self popNextLine];
		if(!code) {
			break;
		}
		[self sendGCode:code];
	}
	
	if(self.completedRequests >= self.program.lines.count) {
		[self jobDidComplete];
	}
}


- (void)sendLineNumberReset {
	TFPGCode *reset = [TFPGCode codeWithString:@"N0 M110"];
	[self.printer sendGCode:reset responseHandler:^(BOOL success, NSString *value) {
	}];
	self.lineNumber = 1;
	self.sentCodeRegistry[@(0)] = reset;
}


- (void)start {
	__weak __typeof__(self) weakSelf = self;
	
	self.codeOffset = 0;
	self.pendingRequestCount = 0;
	self.completedRequests = 0;
	self.startTime = TFNanosecondTime();
	self.sentCodeRegistry = [NSMutableDictionary new];
	
	self.printer.verboseMode = self.parameters.verbose;
	
	[self sendLineNumberReset];
	[self sendMoreIfNeeded];
	
	[self.printer addObserver:self keyPath:@"heaterTemperature" options:0 block:^(MAKVONotification *notification) {
		double temp = weakSelf.printer.heaterTemperature;
		if(temp < 0) {
			weakSelf.targetTemperature = 0;
		}else if(weakSelf.targetTemperature > 0 && weakSelf.heatingProgressBlock){
			weakSelf.heatingProgressBlock(weakSelf.targetTemperature, temp);
		}
	}];
	
	self.printer.resendHandler = ^(NSUInteger lineNumber){
		if(weakSelf.parameters.verbose) {
			TFLog(@"Re-sending line N%d", (int)lineNumber);
		}
		
		TFPGCode *code = weakSelf.sentCodeRegistry[@(lineNumber)];
		code = [code codeBySettingField:'N' toValue:lineNumber];
		
		// Last block is cancelled, decrement pending to balance
		weakSelf.pendingRequestCount--;
		[weakSelf sendGCode:code];
	};
	
	
	IOReturn asserted = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep,
													kIOPMAssertionLevelOn,
													CFSTR("MicroPrint print job"),
													&(self->_powerAssertionID));
	if (asserted != kIOReturnSuccess) {
		TFLog(@"Failed to assert kIOPMAssertionTypeNoIdleSleep!");
		self.powerAssertionID = kIOPMNullAssertionID;
	}
	
	
	self.interruptSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGINT, 0, dispatch_get_main_queue());
	dispatch_source_set_event_handler(self.interruptSource, ^{
		[weakSelf abort];
	});
	dispatch_resume(self.interruptSource);

	struct sigaction action = { 0 };
	action.sa_handler = SIG_IGN;
	sigaction(SIGINT, &action, NULL);
}


- (void)sendAbortSequenceWithCompletionHandler:(void(^)())completionHandler {
	NSArray *codes = @[
					   TGPGCODE(G91),
					   TGPGCODE(G0 E-5 F450),
					   TGPGCODE(G0 Z1 F200),
					   TGPGCODE(G0 E-4 F450),
					   TGPGCODE(G0 Z4 F200),
					   TGPGCODE(G90),
					   TGPGCODE(G0 Y84),
					   TGPGCODE(M106 S0),
					   TGPGCODE(M0)
					   ];
	
	[self.printer sendGCodes:codes completionHandler:^(BOOL success) {
		completionHandler();
	}];
}


- (void)abort {
	TFLog(@"");
	TFLog(@"Cancelling print...");
	
	self.aborted = YES;
	
	if(self.interruptSource) {
		dispatch_source_cancel(self.interruptSource);
		self.interruptSource = nil;
	}
	
	[self sendAbortSequenceWithCompletionHandler:^{
		[self jobEnded];
		
		if(self.abortionBlock) {
			self.abortionBlock([self elapsedTime]);
		}
	}];
}


@end
