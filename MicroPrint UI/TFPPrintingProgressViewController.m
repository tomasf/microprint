//
//  TFPPrintingProgressViewController.m
//  microprint
//
//  Created by Tomas Franzén on Tue 2015-07-14.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrintingProgressViewController.h"
#import "TFPPrintJob.h"
#import "TFPExtras.h"
#import "TFPGCodeProgram.h"
#import "TFPPrinter.h"
#import "TFPPrintParameters.h"
#import "TFPPrintStatusController.h"
#import "TFPVisualPrintProgressView.h"

#import "MAKVONotificationCenter.h"
@import QuartzCore;


static NSString *const printProgressExpandedKey = @"PrintProgressExpanded";
static const CGFloat drawContainerExpandedHeight = 300;
static const CGFloat drawContainerExpandedBottomMargin = 20;


@interface TFPPrintingProgressViewController ()
@property IBOutlet NSTextField *statusLabel;
@property IBOutlet NSTextField *elapsedTimeLabel;
@property IBOutlet NSTextField *remainingTimeLabel;
@property IBOutlet NSProgressIndicator *progressIndicator;

@property IBOutlet NSLayoutConstraint *drawContainerHeightConstraint;
@property IBOutlet NSLayoutConstraint *drawContainerBottomMarginConstraint;

@property BOOL viewExpanded;
@property IBOutlet NSButton *expandButton;
@property IBOutlet TFPVisualPrintProgressView *printProgressView;

@property NSDateComponentsFormatter *durationFormatter;
@property NSDateComponentsFormatter *approximateDurationFormatter;
@property NSDateFormatter *shortTimeFormatter;
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
	
	self.shortTimeFormatter = [NSDateFormatter new];
	self.shortTimeFormatter.dateStyle = NSDateFormatterNoStyle;
	self.shortTimeFormatter.timeStyle = NSDateFormatterShortStyle;
	
	return self;
}


- (void)viewDidLoad {
	[super viewDidLoad];
	
	[self.view layoutSubtreeIfNeeded];
	self.printProgressView.fullViewSize = self.printProgressView.bounds.size;

	BOOL expand = [[NSUserDefaults standardUserDefaults] boolForKey:printProgressExpandedKey];
	[self setExpanded:expand animated:NO];
}


- (void)setExpanded:(BOOL)expand animated:(BOOL)animate {
	self.viewExpanded = expand;
	self.expandButton.state = expand ? NSOnState : NSOffState;
	
	if(animate) {
		[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
			context.duration = 0.25;
			context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
			
			self.drawContainerHeightConstraint.animator.constant = expand ? drawContainerExpandedHeight : 0;
			self.drawContainerBottomMarginConstraint.animator.constant = expand ? drawContainerExpandedBottomMargin : 0;
			self.printProgressView.animator.hidden = !expand;
		} completionHandler:nil];
		
	}else{
		self.drawContainerHeightConstraint.constant = expand ? drawContainerExpandedHeight : 0;
		self.drawContainerBottomMarginConstraint.constant = expand ? drawContainerExpandedBottomMargin : 0;
		self.printProgressView.hidden = !expand;
	}

	[[NSUserDefaults standardUserDefaults] setBool:expand forKey:printProgressExpandedKey];
}


- (IBAction)toggleExpanded:(id)sender {
	[self setExpanded:!self.viewExpanded animated:YES];
}


- (void)configurePrintJob {
	__weak __typeof__(self) weakSelf = self;
	
	self.printJob.progressBlock = ^(){
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
		NSDockTile *dockTile = weakSelf.presentingViewController.view.window.dockTile;
		dockTile.badgeLabel = [weakSelf.percentFormatter stringFromNumber:@(weakSelf.printStatusController.printProgress)];
		[dockTile display];
	}];
	
	[self.printProgressView configureWithPrintStatusController:self.printStatusController parameters:self.printParameters];
}


- (void)warnAboutOutOfBounds {
	NSAlert *alert = [NSAlert new];
	alert.messageText = @"The model appears to be outside of the printer's printable area.";
	alert.informativeText = @"This may be due to the model being too large or positioned incorrectly. Make sure your slicer has the correct print area set.";
	[alert addButtonWithTitle:@"Cancel"];
	[alert addButtonWithTitle:@"Continue Anyway"];
	
	[alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
		if(returnCode == NSAlertFirstButtonReturn) {
			[self dismissController:nil];
			self.endHandler(NO);
		}else{
			[self configurePrintJob];
		}
	}];
}


- (void)start {
	__weak __typeof__(self) weakSelf = self;
	
	TFPPrintParameters *params = self.printParameters;
	
	self.progressIndicator.indeterminate = YES;
	[self.progressIndicator startAnimation:nil];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		TFPGCodeProgram *program = self.program;
		BOOL withinBounds = [program withinM3DMicroPrintableVolume];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if(weakSelf.aborted) {
				return;
			}
			weakSelf.printJob = [[TFPPrintJob alloc] initWithProgram:program printer:weakSelf.printer printParameters:params];
			
			if(withinBounds) {
				[weakSelf configurePrintJob];
			}else{
				[weakSelf warnAboutOutOfBounds];
			}
		});
	});
}


- (void)viewDidAppear {
	[super viewDidAppear];
	self.view.window.styleMask &= ~NSResizableWindowMask;
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
	alert.alertStyle = NSCriticalAlertStyle;
	alert.messageText = @"Are you sure you want to abort the print?";
	[alert addButtonWithTitle:@"Don't Abort"];
	[alert addButtonWithTitle:@"Abort Print"];
	
	[alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
		if(returnCode == NSAlertSecondButtonReturn) {
			[self.printJob abort];
		}
	}];
}


- (NSString*)pauseActionName {
	if(self.printJob.state == TFPPrintJobStatePaused) {
		return @"Resume";
	} else {
		return @"Pause";
	}
}


+ (NSSet *)keyPathsForValuesAffectingPauseActionName {
	return @[@"printJob.state"].tf_set;
}


- (BOOL)canPause {
	return self.printJob.state == TFPPrintJobStatePrinting || self.printJob.state == TFPPrintJobStatePaused;
}


+ (NSSet *)keyPathsForValuesAffectingCanPause {
	return @[@"printJob.state"].tf_set;
}


- (IBAction)pause:(id)sender {
	if(self.printJob.state == TFPPrintJobStatePrinting) {
		
		NSAlert *alert = [NSAlert new];
		alert.alertStyle = NSCriticalAlertStyle;
		alert.messageText = @"Are you sure you want to pause?";
		alert.informativeText = @"Pausing and resuming is likely to produce a small dent or blob in your print. Cleaning the nozzle before resuming often helps and is recommended, but keep in mind the nozzle is hot.";
		
		[alert addButtonWithTitle:@"Pause"];
		[alert addButtonWithTitle:@"Don't Pause"];
		
		[alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
			if(returnCode == NSAlertFirstButtonReturn) {
				[self.printJob pause];
			}
		}];
		
	}else if(self.printJob.state == TFPPrintJobStatePaused) {
		[self.printJob resume];
	}
}


- (NSString*)layerString {
	if(self.printStatusController.currentLayer) {
		NSInteger number = self.printStatusController.currentLayer.layerIndex;
		if(number >= 0) {
			number++;
		}
		return [NSString stringWithFormat:@"%d of %d", (int)number, (int)self.printStatusController.layerCount];
	}else{
		return @"";
	}
}


+ (NSSet *)keyPathsForValuesAffectingLayerString {
	return @[@"printStatusController.currentLayer", @"printStatusController.layerCount"].tf_set;
}


- (NSString*)elapsedTimeString {
	return [self.durationFormatter stringFromTimeInterval:self.printStatusController.elapsedTime];
}


+ (NSSet *)keyPathsForValuesAffectingElapsedTimeString {
	return [NSSet setWithObject:@"printStatusController.elapsedTime"];
}


- (NSString*)remainingTimeString {
	if(self.printStatusController.hasRemainingTimeEstimate) {
		NSTimeInterval estimate = self.printStatusController.estimatedRemainingTime;
		NSString *remainingTime = [self.approximateDurationFormatter stringFromTimeInterval:estimate];
		NSString *completionTime = [self.shortTimeFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:estimate]];
		return [NSString stringWithFormat:@"%@ (%@)", remainingTime, completionTime];
		
	}else{
		return @"Calculating…";
	}
}


+ (NSSet *)keyPathsForValuesAffectingRemainingTimeString {
	return @[@"printStatusController.elapsedRemainingTime", @"printStatusController.hasRemainingTimeEstimate"].tf_set;
}


- (NSString*)statusString {
	TFAssertMainThread();
	
	switch(self.printJob.state) {
		case TFPPrintJobStatePreparing:
			return @"Starting…";
			
		case TFPPrintJobStateHeating:
			return [NSString stringWithFormat:@"Heating to %.0f: %.0f%%",
					self.printer.heaterTargetTemperature,
					(self.printer.heaterTemperature/self.printer.heaterTargetTemperature)*100
					];
		
		case TFPPrintJobStatePrinting: {
			NSString *progress = [self.longPercentFormatter stringFromNumber:@(self.printStatusController.phaseProgress)];
			NSString *phase;
			BOOL printProgress = YES;
			
			switch(self.printStatusController.currentPhase) {
				case TFPPrintPhaseSkirt:
					phase = @"Printing Skirt";
					printProgress = NO;
					break;
				case TFPPrintPhaseAdhesion:
					phase = @"Printing Bed Adhesion";
					break;
				case TFPPrintPhaseModel:
					phase = @"Printing Model";
					break;
					
				case TFPPrintPhaseInvalid:
					return @"";
			}
			
			if(printProgress) {
				return [NSString stringWithFormat:@"%@: %@", phase, progress];
			} else {
				return phase;
			}
		}
			
		case TFPPrintJobStatePaused:
			return @"Paused";
			
		case TFPPrintJobStatePausing:
			return @"Pausing…";
			
		case TFPPrintJobStateResuming:
			return @"Resuming…";
			
		case TFPPrintJobStateAborting:
			return @"Stopping…";
			
		case TFPPrintJobStateFinishing:
			return @"Finishing…";
	}
}


+ (NSSet *)keyPathsForValuesAffectingStatusString {
	return @[@"state", @"printStatusController.currentPhase", @"printStatusController.phaseProgress",
			 @"printJob.state", @"printer.heaterTemperature"].tf_set;
}


@end