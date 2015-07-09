//
//  TFPGCodeConsoleOperation.m
//  microprint
//
//  Created by Tomas Franzén on Wed 2015-07-08.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPGCodeConsoleOperation.h"
#import "TFPPrinter.h"
#import "Extras.h"


@interface TFPGCodeConsoleOperation ()
@property TFPPrinter *printer;
@end



@implementation TFPGCodeConsoleOperation


- (instancetype)initWithPrinter:(TFPPrinter*)printer {
	if(!(self = [super init])) return nil;
	
	self.printer = printer;
	self.convertFeedRates = YES;
	
	return self;
}


- (void)listen {
	__weak __typeof__(self) weakSelf = self;
	printf("> ");
	
	TFPListenForInputLine(^(NSString *line) {
		TFPGCode *code = [[TFPGCode alloc] initWithString:line];
		if(code) {
			if(self.convertFeedRates) {
				NSInteger G = [code valueForField:'G' fallback:-1];
				if((G == 0 || G == 1) && [code hasField:'F']) {
					code = [code codeBySettingField:'F' toValue:[TFPPrinter convertFeedRate:[code valueForField:'F']]];
				}
			}
			
			[self.printer sendGCode:code responseHandler:^(BOOL success, NSString *value) {
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