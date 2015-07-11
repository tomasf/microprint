//
//  TFPExtrusionOperation.m
//  microprint
//
//  Created by Tomas Franzén on Sun 2015-06-28.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPExtrusionOperation.h"
#import "Extras.h"
#import "TFPRepeatingCommandSender.h"

#import "MAKVONotificationCenter.h"


@interface TFPExtrusionOperation ()
@property TFPRepeatingCommandSender *repeatSender;
@property BOOL retract;
@end


@implementation TFPExtrusionOperation


- (instancetype)initWithPrinter:(TFPPrinter*)printer retraction:(BOOL)retract {
	if(!(self = [super initWithPrinter:printer])) return nil;
	
	self.temperature = 215;
	self.retract = retract;
	
	return self;
}


static const double extrudeStepLength = 10;
static const double extrudeFeedRate = 210;


- (void)start {
	__weak TFPPrinter *printer = self.printer;
	__weak __typeof__(self) weakSelf = self;
	
	TFPGCode *fansOn = [TFPGCode codeWithString:@"M106 S255"];
	TFPGCode *fansOff = [TFPGCode codeWithString:@"M107"];
	
	const double minZ = 25;
	
	TFPGCode *tempOn = [[TFPGCode codeWithString:@"M104"] codeBySettingField:'S' toValue:self.temperature];
	TFPGCode *tempAndWait = [[TFPGCode codeWithString:@"M109"] codeBySettingField:'S' toValue:self.temperature];
	TFPGCode *tempOff = [TFPGCode codeWithString:@"M104 S0"];
	
	TFPGCode *motorsOff = [TFPGCode codeWithString:@"M18"];
	
	double extrusionLength = self.retract ? -extrudeStepLength : extrudeStepLength;
	TFPGCode *command = [[[TFPGCode codeWithString:@"G0"] codeBySettingField:'E' toValue:extrusionLength] codeBySettingField:'F' toValue:extrudeFeedRate];
	
	
	[printer sendGCode:fansOn responseHandler:^(BOOL success, NSString *value) {
		
		id<MAKVOObservation> token = [printer addObserver:nil keyPath:@"heaterTemperature" options:0 block:^(MAKVONotification *notification) {
			if(printer.heaterTemperature > 0) {
				TFLog(@"* %.0f°C", printer.heaterTemperature);
			}
		}];
		
		[printer sendGCode:tempOn responseHandler:^(BOOL success, NSString *value) {
			[printer fetchPositionWithCompletionHandler:^(BOOL success, TFP3DVector *position, NSNumber *E) {
				void(^nextStep)() = ^{
					TFLog(@"Heating to %.0f°C...", weakSelf.temperature);
					
					[printer sendGCode:tempAndWait responseHandler:^(BOOL success, NSString *value) {
						[token remove];
						
						[printer setRelativeMode:YES completionHandler:^(BOOL success) {
							TFLog(@"%@. Press Return to stop.", (weakSelf.retract ? @"Retracting" : @"Extruding"));
							
							weakSelf.repeatSender = [[TFPRepeatingCommandSender alloc] initWithPrinter:printer];
							
							weakSelf.repeatSender.nextCodeBlock = ^{
								return command;
							};
							
							weakSelf.repeatSender.stoppingBlock = ^{
								TFLog(@"Stopping...");
							};
							
							
							weakSelf.repeatSender.endedBlock = ^{
								TFLog(@"Switching back to absolute mode and turning off heater, fan and motors...");
								[printer setRelativeMode:NO completionHandler:^(BOOL success) {
									
									[printer sendGCode:tempOff responseHandler:^(BOOL success, NSString *value) {
										[printer sendGCode:fansOff responseHandler:^(BOOL success, NSString *value) {
											[printer sendGCode:motorsOff responseHandler:^(BOOL success, NSString *value) {
												exit(EXIT_SUCCESS);
											}];
										}];
									}];
								}];
							};
							
							[weakSelf.repeatSender start];
						}];
					}];
				};
				
				if(position.z.doubleValue < minZ) {
					[printer setRelativeMode:NO completionHandler:^(BOOL success) {
						[printer moveToPosition:[TFP3DVector vectorWithX:nil Y:nil Z:@(minZ)] EPosition:nil usingFeedRate:-1 completionHandler:^(BOOL success) {
							nextStep();
						}];
					}];
				}else{
					nextStep();
				}
			}];
		}];
	}];

}


@end