//
//  TFPVisualPrintProgressView.m
//  microprint
//
//  Created by Tomas Franzén on Sat 2015-08-08.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPVisualPrintProgressView.h"
#import "TFPPrintJob.h"
#import "TFPPrintStatusController.h"


@interface TFPVisualPrintProgressView ()
@property id bitmap;

@property CALayer *drawLayer;
@property CGAffineTransform drawTransform;
@property CGFloat drawScale;
@end



@implementation TFPVisualPrintProgressView


- (void)configureWithPrintStatusController:(TFPPrintStatusController*)statusController parameters:(TFPPrintParameters*)printParameters {
	__weak __typeof__(self) weakSelf = self;
	
	TFPCuboid boundingBox = printParameters.boundingBox;
	CGSize viewSize = self.fullViewSize;
	
	CGFloat drawScale = 2;
	self.bitmap = CFBridgingRelease(CGBitmapContextCreate(NULL, viewSize.width * drawScale, viewSize.height * drawScale, 8, (viewSize.width*drawScale)*4, [NSColorSpace deviceRGBColorSpace].CGColorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast));
	
	self.drawLayer = [CALayer layer];
	self.drawLayer.bounds = CGRectMake(0, 0, viewSize.width, viewSize.height);
	self.drawLayer.backgroundColor = [NSColor whiteColor].CGColor;
	self.drawLayer.anchorPoint = CGPointZero;
	self.drawLayer.actions = @{@"contents": [NSNull null]};
	self.drawLayer.contentsScale = drawScale;
	[self.layer addSublayer:self.drawLayer];
	
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
	
	
	__block double xAdjustment = 0;
	__block double yAdjustment = 0;
	
	statusController.willMoveHandler = ^(TFPAbsolutePosition from, TFPAbsolutePosition to, double feedRate, TFPGCode *code) {
		double distance = TFPAbsolutePositionDistance(from, to);
		
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
		
		if(to.e > from.e && distance > FLT_EPSILON) {
			CGMutablePathRef path = (CGMutablePathRef)CFAutorelease(CGPathCreateMutable());
			CGPathMoveToPoint(path, NULL, fromPoint.x, fromPoint.y);
			CGPathAddLineToPoint(path, NULL, toPoint.x, toPoint.y);
			
			CGContextRef context = (__bridge CGContextRef)weakSelf.bitmap;
			
			CGContextAddPath(context, path);
			CGContextStrokePath(context);
			[weakSelf updateImage];
		}
	};
	
	statusController.layerChangeHandler = ^{
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


- (void)setHidden:(BOOL)hidden {
	[super setHidden:hidden];
	[self updateImage];
}


- (void)updateImage {
	if(!self.hiddenOrHasHiddenAncestor && self.bitmap) {
		self.drawLayer.contents = CFBridgingRelease(CGBitmapContextCreateImage((CGContextRef)self.bitmap));
	}
}


@end
