//
//  TFPRepeatingCommandSender.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPRepeatingCommandSender.h"
#import "Extras.h"


@interface TFPRepeatingCommandSender ()
@property BOOL stopFlag;
@end


@implementation TFPRepeatingCommandSender


- (void)repeat {
	__weak __typeof__(self) weakSelf = self;
	TFPGCode *code = self.nextCodeBlock();
	
	if(code) {
		[self.printer sendGCode:code responseHandler:^(BOOL success, NSString *value) {
			if(weakSelf.stopFlag) {
				weakSelf.endedBlock();
			}else{
				[weakSelf repeat];
			}
		}];
		
	} else {
		weakSelf.endedBlock();
	}
}



- (void)start {
	__weak __typeof__(self) weakSelf = self;
	
	dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0, dispatch_get_main_queue());
	dispatch_source_set_event_handler(source, ^{
		NSMutableData *data = [NSMutableData dataWithLength:1024];
		size_t len = read(STDIN_FILENO, data.mutableBytes, data.length);
		[data setLength:len];
		
		if([data tf_indexOfData:[NSData dataWithBytes:"\n" length:1]] != NSNotFound) {
			if(weakSelf.stoppingBlock) {
				weakSelf.stoppingBlock();
			}
			weakSelf.stopFlag = YES;
			dispatch_source_cancel(source);
		}
	});
	dispatch_resume(source);
	
	[self repeat];

}


@end
