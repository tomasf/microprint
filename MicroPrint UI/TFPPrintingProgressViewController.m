//
//  TFPPrintingProgressViewController.m
//  microprint
//
//  Created by Tomas Franzén on Tue 2015-07-14.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrintingProgressViewController.h"
#import "TFPPrintJob.h"
#import "Extras.h"
#import "TFPGCodeProgram.h"
#import "TFPPrinter.h"
#import "TFPPrintParameters.h"
#import "TFPPreprocessing.h"
#import "TFPPrintStatusController.h"
#import "MAKVONotificationCenter.h"


@interface TFPPrintingProgressViewController ()
@property IBOutlet NSTextField *statusLabel;
@property IBOutlet NSTextField *elapsedTimeLabel;
@property IBOutlet NSTextField *remainingTimeLabel;
@property IBOutlet NSProgressIndicator *progressIndicator;

@property NSDateComponentsFormatter *durationFormatter;
@property NSDateComponentsFormatter *approximateDurationFormatter;
@property NSNumberFormatter *percentFormatter;
@property NSNumberFormatter *longPercentFormatter;

@property TFPPrintJob *printJob;
@property TFPPrintStatusController *printStatusController;
@property BOOL aborted;
@end



@implementation TFPPrintingProgressViewController


- (instancetype)initWithCoder:(NSCoder *)coder {
	if(!(self = [super initWithCoder:coder])) return nil;
	
	self.durationFormatter = [NSDateComponentsFormatter new];
	self.durationFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
	
	self.approximateDurationFormatter = [NSDateComponentsFormatter new];
	self.approximateDurationFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
	self.approximateDurationFormatter.includesApproximationPhrase = YES;
	self.approximateDurationFormatter.allowedUnits = NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
	
	self.percentFormatter = [NSNumberFormatter new];
	self.percentFormatter.numberStyle = NSNumberFormatterPercentStyle;
	self.percentFormatter.maximumFractionDigits = 1;

	self.longPercentFormatter = [NSNumberFormatter new];
	self.longPercentFormatter.numberStyle = NSNumberFormatterPercentStyle;
	self.longPercentFormatter.maximumFractionDigits = 2;
	self.longPercentFormatter.minimumFractionDigits = 2;
	
	return self;
}


- (void)configurePrintJob {
	__weak __typeof__(self) weakSelf = self;
	
	self.printJob.progressBlock = ^(){
	};
	
	self.printJob.heatingProgressBlock = ^(double targetTemperature, double currentTemperature) {
		TFAssertMainThread();
		weakSelf.statusLabel.stringValue = [NSString stringWithFormat:@"Heating to %.0f: %d%%", targetTemperature, (int)((currentTemperature/targetTemperature)*100)];
	};
	
	self.printJob.abortionBlock = ^{
		TFAssertMainThread();
		[weakSelf dismissController:nil];
		if(weakSelf.endHandler) {
			weakSelf.endHandler(NO);
		}
	};
	
	self.printJob.completionBlock = ^{
		TFAssertMainThread();
		NSWindow *window = weakSelf.view.window;
		[weakSelf dismissController:nil];
		[window orderOut:nil];

		if(weakSelf.endHandler) {
			weakSelf.endHandler(YES);
		}
	};
	
	[self.printJob start];
	self.progressIndicator.indeterminate = NO;
	
	self.printStatusController = [[TFPPrintStatusController alloc] initWithPrintJob:self.printJob];
	
	[self.printStatusController addObserver:self keyPath:@"printProgress" options:0 block:^(MAKVONotification *notification) {
		//weakSelf.parentWindow.dockTile.badgeLabel = [weakSelf.percentFormatter stringFromNumber:@(weakSelf.printStatusController.printProgress)];
		//[weakSelf.parentWindow.dockTile display];
	}];
}


- (void)start {
	__weak __typeof__(self) weakSelf = self;
	
	TFPPrintParameters *params = self.printParameters;
	
	self.progressIndicator.indeterminate = YES;
	[self.progressIndicator startAnimation:nil];
	
	[self.printer fillInOffsetAndBacklashValuesInPrintParameters:params completionHandler:^(BOOL success) {
		TFAssertMainThread();
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			TFPGCodeProgram *program = [[TFPGCodeProgram alloc] initWithFileURL:self.GCodeFileURL error:nil];
			program = [TFPPreprocessing programByPreprocessingProgram:program usingParameters:params];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				if(weakSelf.aborted) {
					return;
				}
				weakSelf.printJob = [[TFPPrintJob alloc] initWithProgram:program printer:weakSelf.printer printParameters:params];
				[weakSelf configurePrintJob];
			});
		});
	}];
}


- (IBAction)abort:(id)sender {
	__weak __typeof__(self) weakSelf = self;
	
	if(!self.printJob) {
		self.aborted = YES;
		[self dismissController:nil];
		if(weakSelf.endHandler) {
			weakSelf.endHandler(NO);
		}
		return;
	}
	
	NSAlert *alert = [NSAlert new];
	alert.messageText = @"Are you sure you want to abort the print?";
	[alert addButtonWithTitle:@"Don't Abort"];
	[alert addButtonWithTitle:@"Abort Print"];
	
	[alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
		if(returnCode == NSAlertSecondButtonReturn) {
			[self.printJob abort];
			self.statusLabel.stringValue = @"Stopping…";
		}
	}];
}


- (NSString*)elapsedTimeString {
	return [self.durationFormatter stringFromTimeInterval:self.printStatusController.elapsedTime];
}


+ (NSSet *)keyPathsForValuesAffectingElapsedTimeString {
	return [NSSet setWithObject:@"printStatusController.elapsedTime"];
}


- (NSString*)remainingTimeString {
	if(self.printStatusController.hasRemainingTimeEstimate) {
		return [self.approximateDurationFormatter stringFromTimeInterval:self.printStatusController.estimatedRemainingTime];
	}else{
		return @"Calculating…";
	}
}


+ (NSSet *)keyPathsForValuesAffectingRemainingTimeString {
	return @[@"printStatusController.elapsedRemainingTime", @"printStatusController.hasRemainingTimeEstimate"].tf_set;
}


- (NSString*)statusString {
	if(!self.printJob) {
		return @"Pre-processing…";
	} else {
		
		NSString *progress = [self.longPercentFormatter stringFromNumber:@(self.printStatusController.phaseProgress)];
		NSString *phase;
		
		switch(self.printStatusController.currentPhase) {
			case TFPPrintPhasePreamble:
				phase = @"Starting Print";
				break;
			case TFPPrintPhaseAdhesion:
				phase = @"Printing Bed Adhesion";
				break;
			case TFPPrintPhaseModel:
				phase = @"Printing Model";
				break;
			case TFPPrintPhasePostamble:
				phase = @"Finishing";
				break;
				
			case TFPPrintPhaseInvalid:
				return @"";
		}
		
		return [NSString stringWithFormat:@"%@: %@", phase, progress];
	}
}


+ (NSSet *)keyPathsForValuesAffectingStatusString {
	return @[@"printJob", @"printStatusController.currentPhase", @"printStatusController.phaseProgress"].tf_set;
}


@end