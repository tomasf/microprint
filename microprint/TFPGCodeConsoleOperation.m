//
//  TFPGCodeConsoleOperation.m
//  microprint
//
//  Created by Tomas Franzén on Wed 2015-07-08.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPGCodeConsoleOperation.h"
#import "TFPPrinter.h"
#import "TFPExtras.h"
#import "TFPGCodeHelpers.h"


@interface TFPGCodeConsoleOperation ()
@end



@implementation TFPGCodeConsoleOperation


- (void)listen {
	__weak __typeof__(self) weakSelf = self;
	printf("> ");
	
	TFPListenForInputLine(^(NSString *line) {
		TFPGCode *code = [[TFPGCode alloc] initWithString:line];
		if(code) {			
			[self.context sendGCode:code responseHandler:^(BOOL success, NSDictionary *value) {
				[weakSelf listen];
			}];
		}else{
			TFLog(@"Syntax error");
			[weakSelf listen];
		}
	});
}



- (BOOL)start {
	if(![super start]) {
		return NO;
	}
	
	setbuf(stdout, NULL);
	
	self.printer.incomingCodeBlock = ^(NSString *line){
		TFLog(@"  %@", line);
	};
	
	[self listen];
	return YES;
}


@end