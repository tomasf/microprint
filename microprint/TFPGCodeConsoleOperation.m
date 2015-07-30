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
			[self.printer sendGCode:code responseHandler:^(BOOL success, NSDictionary *value) {
				if(success) {
					TFLog(@"ok %@", value ?: @"");
				}else{
					TFLog(@"Error: %@", value);
				}
				[weakSelf listen];
			}];
		}else{
			TFLog(@"Syntax error");
			[weakSelf listen];
		}
	});
}



- (void)start {
	setbuf(stdout, NULL);
	
	[self listen];
}


@end