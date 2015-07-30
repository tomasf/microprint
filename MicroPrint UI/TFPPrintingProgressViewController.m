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
#import "TFPPreprocessing.h"
#import "TFPPrintStatusController.h"
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
@property IBOutlet NSView *drawContainer;
@property id bitmap;

@property CALayer *drawLayer;
@property CGAffineTransform drawTransform;
@property CGFloat drawScale;

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
			self.drawContainer.animator.hidden = !expand;
		} completionHandler:nil];
		
	}else{
		self.drawContainerHeightConstraint.constant = expand ? drawContainerExpandedHeight : 0;
		self.drawContainerBottomMarginConstraint.constant = expand ? drawContainerExpandedBottomMargin : 0;
		self.drawContainer.hidden = !expand;
	}
	
	if(expand) {
		[self updateImageIfNeeded];
	}
	
	[[NSUserDefaults standardUserDefaults] setBool:expand forKey:printProgressExpandedKey];
}


- (void)updateImageIfNeeded {
	if(self.viewExpanded && self.bitmap) {
		self.drawLayer.contents = CFBridgingRelease(CGBitmapContextCreateImage((CGContextRef)self.bitmap));
	}
}


- (IBAction)toggleExpanded:(id)sender {
	[self setExpanded:!self.viewExpanded animated:YES];
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
		NSDockTile *dockTile = weakSelf.presentingViewController.view.window.dockTile;
		dockTile.badgeLabel = [weakSelf.percentFormatter stringFromNumber:@(weakSelf.printStatusController.printProgress)];
		[dockTile display];
	}];
	
	__block double xAdjustment = 0;
	__block double yAdjustment = 0;
	
	self.printStatusController.willMoveHandler = ^(TFPAbsolutePosition from, TFPAbsolutePosition to, double feedRate, TFPGCode *code) {
		if([code.comment hasPrefix:@"BACKLASH"]) {
			xAdjustment += from.x - to.x;
			yAdjustment += from.y - to.y;
		}
		
		CGAffineTransform transform = weakSelf.drawTransform;
		CGPoint fromPoint = CGPointApplyAffineTransform(CGPointMake(from.x + xAdjustment, from.y + yAdjustment), transform);
		CGPoint toPoint = CGPointApplyAffineTransform(CGPointMake(to.x + xAdjustment, to.y + yAdjustment), transform);

		/*
		double distance = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2));
		double calculatedSpeed = (6288.78 * (feedRate-830))/((feedRate-828.465) * (feedRate+79.5622));
		NSTimeInterval estimatedDuration = distance / calculatedSpeed;
		estimatedDuration /= weakSelf.printer.speedMultiplier;
		 */
		
		if(to.e > from.e) {
			CGMutablePathRef path = (CGMutablePathRef)CFAutorelease(CGPathCreateMutable());
			CGPathMoveToPoint(path, NULL, fromPoint.x, fromPoint.y);
			CGPathAddLineToPoint(path, NULL, toPoint.x, toPoint.y);

			CGContextRef context = (__bridge CGContextRef)weakSelf.bitmap;

			CGContextAddPath(context, path);
			CGContextStrokePath(context);
			[weakSelf updateImageIfNeeded];
		}
	};
	
	self.printStatusController.layerChangeHandler = ^{
		CGContextRef context = (__bridge CGContextRef)weakSelf.bitmap;
		CGRect entireRect = CGRectMake(0, 0, CGBitmapContextGetWidth(context), CGBitmapContextGetHeight(context));
		CGImageRef image = (CGImageRef)CFAutorelease(CGBitmapContextCreateImage(context));
		
		CGContextSaveGState(context);
		CGContextClearRect(context, entireRect);
		CGContextSetAlpha(context, 0.5);
		CGContextConcatCTM(context, CGAffineTransformInvert(CGContextGetCTM(context)));
		CGContextDrawImage(context, entireRect, image);
		CGContextRestoreGState(context);
	};
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


- (void)viewDidAppear {
	[super viewDidAppear];
	self.view.window.styleMask &= ~NSResizableWindowMask;
}


- (void)viewWillAppear {
	[super viewWillAppear];
	[self.view layoutSubtreeIfNeeded];
	
	TFPCuboid boundingBox = self.printParameters.boundingBox;
	CGSize viewSize = CGSizeMake(self.drawContainer.bounds.size.width, drawContainerExpandedHeight);
	
	CGFloat drawScale = 2;
	self.bitmap = CFBridgingRelease(CGBitmapContextCreate(NULL, viewSize.width * drawScale, viewSize.height * drawScale, 8, (viewSize.width*drawScale)*4, [NSColorSpace deviceRGBColorSpace].CGColorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast));
	
	self.drawLayer = [CALayer layer];
	self.drawLayer.bounds = CGRectMake(0, 0, viewSize.width, viewSize.height);
	self.drawLayer.backgroundColor = [NSColor whiteColor].CGColor;
	self.drawLayer.anchorPoint = CGPointZero;
	self.drawLayer.actions = @{@"contents": [NSNull null]};
	self.drawLayer.contentsScale = drawScale;
	[self.drawContainer.layer addSublayer:self.drawLayer];
	
	CGFloat margin = 20;
	viewSize.width -= 2*margin;
	viewSize.height -= 2*margin;
	
	CGAffineTransform transform = CGAffineTransformIdentity;
	double xScale = viewSize.width / boundingBox.xSize;
	double yScale = viewSize.height / boundingBox.ySize;
	double scale = MIN(xScale, yScale);
	
	CGFloat xOffset = (viewSize.width - (scale*boundingBox.xSize)) / 2 + margin;
	CGFloat yOffset = (viewSize.height - (scale*boundingBox.ySize)) / 2 + margin;
	transform = CGAffineTransformTranslate(transform, xOffset, yOffset);
	transform = CGAffineTransformScale(transform, scale, scale);
	transform = CGAffineTransformTranslate(transform, -boundingBox.x, -boundingBox.y);
	self.drawScale = scale;
	self.drawTransform = transform;
	
	CGContextRef context = (__bridge CGContextRef)self.bitmap;
	CGContextSetLineCap(context, kCGLineCapRound);
	CGContextSetLineWidth(context, self.drawScale * 0.8);
	CGContextSetStrokeColorWithColor(context, [NSColor blackColor].CGColor);
	CGContextScaleCTM(context, drawScale, drawScale);
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