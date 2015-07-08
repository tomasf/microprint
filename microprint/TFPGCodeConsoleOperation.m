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


- (void)listenForInputLineWithHandler:(void(^)(NSString *line))block {
	dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0, dispatch_get_main_queue());
	dispatch_source_set_event_handler(source, ^{
		NSMutableData *data = [NSMutableData dataWithLength:1024];
		size_t len = read(STDIN_FILENO, data.mutableBytes, data.length);
		[data setLength:len];
		
		if([data tf_indexOfData:[NSData dataWithBytes:"\n" length:1]] != NSNotFound) {
			dispatch_source_cancel(source);
			NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			block(string);
		}
	});
	dispatch_resume(source);
}


- (void)listen {
	__weak __typeof__(self) weakSelf = self;
	printf("> ");
	
	[self listenForInputLineWithHandler:^(NSString *line) {
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
	}];
}



- (void)start {
	setbuf(stdout, NULL);
	
	[self listen];
}


@end