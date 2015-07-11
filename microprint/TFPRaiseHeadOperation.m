//
//  TFPRaiseHeadOperation.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPRaiseHeadOperation.h"
#import "TFPRepeatingCommandSender.h"
#import "Extras.h"


@interface TFPRaiseHeadOperation ()
@property TFPRepeatingCommandSender *repeatSender;
@end


@implementation TFPRaiseHeadOperation

static const double raiseStep = 1;


- (void)start {
	__weak __typeof__(self) weakSelf = self;
	__weak TFPPrinter *printer = self.printer;
	double targetHeight = self.targetHeight;
	
	printer.verboseMode = YES;
	
	[printer fetchPositionWithCompletionHandler:^(BOOL success, TFP3DVector *position, NSNumber *E) {		
		[printer setRelativeMode:NO completionHandler:^(BOOL success) {
			__block double Z = position.z.doubleValue;
			
			if(Z < targetHeight) {
				weakSelf.repeatSender = [[TFPRepeatingCommandSender alloc] initWithPrinter:printer];
				
				weakSelf.repeatSender.nextCodeBlock = ^TFPGCode*{
					if(Z < targetHeight) {
						Z += raiseStep;
						return [[TFPGCode codeWithString:@"G0"] codeBySettingField:'Z' toValue:Z];
					}else{
						return nil;
					}
				};
				
				weakSelf.repeatSender.stoppingBlock = ^{
					TFLog(@"Stopping...");
				};
				
				
				weakSelf.repeatSender.endedBlock = ^{
					exit(EXIT_SUCCESS);
				};
				
				TFLog(@"Raising print head. Press Return to stop.");
				[weakSelf.repeatSender start];
				
			}else{
				TFLog(@"Head is already at or above target height.");
				exit(EXIT_SUCCESS);
			}
		}];
	}];
}


@end