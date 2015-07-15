//
//  TFPUIExtras.m
//  microprint
//
//  Created by Tomas Franzén on Tue 2015-07-14.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPUIExtras.h"
#import "TFPOperation.h"
#import "Extras.h"
@import AppKit;


@implementation TFPPrinter (UIExtras)


- (NSImage *)printerImage {
	static NSMutableDictionary *images;
	if(!images) {
		images = [NSMutableDictionary new];
	}
	
	NSDictionary *colorMapping = @{
								   @(TFPPrinterColorBlack): [NSColor colorWithCalibratedWhite:0.245 alpha:1.000],
								   @(TFPPrinterColorSilver): [NSColor colorWithCalibratedWhite:0.549 alpha:1.000],
								   @(TFPPrinterColorLightBlue): [NSColor colorWithCalibratedRed:0.220 green:0.761 blue:0.918 alpha:1.000],
								   @(TFPPrinterColorGreen): [NSColor colorWithCalibratedRed:0.400 green:0.906 blue:0.224 alpha:1.000],
								   @(TFPPrinterColorOrange): [NSColor colorWithCalibratedRed:0.988 green:0.255 blue:0.149 alpha:1.000],
								   @(TFPPrinterColorWhite): [NSColor colorWithCalibratedWhite:0.948 alpha:1.000],
								   @(TFPPrinterColorGrape): [NSColor colorWithDeviceRed:0.441 green:0.299 blue:0.678 alpha:1.000],
								   @(TFPPrinterColorOther): [NSColor redColor],
								   };
	
	NSImage *image = images[@(self.color)];
	if(image) {
		return image;
	}
	
	image = [[NSImage imageNamed:@"Micro"] copy];
	NSColor *color = colorMapping[@(self.color)];

	[image lockFocus];
	[color set];
	NSRectFillUsingOperation((CGRect){CGPointZero, image.size}, NSCompositeSourceIn);
	[image unlockFocus];
	
	images[@(self.color)] = image;
	return image;
}


+ (NSSet *)keyPathsForValuesAffectingPrinterImage {
	return [NSSet setWithObject:@"color"];
}


- (NSString*)activityString {
	if(self.currentOperation) {
		return self.currentOperation.activityDescription;
		
	}else if(self.pendingConnection) {
		return @"Connecting…";
		
	}else{
		return @"Idle";
	}
}


+ (NSSet *)keyPathsForValuesAffectingActivityString {
	return @[@"currentOperation.activityDescription", @"pendingConnection"].tf_set;
}


- (NSString*)displayName {
	return self.serialNumber ?: @"Printer";
}


+ (NSSet *)keyPathsForValuesAffectingDisplayName {
	return @[@"serialNumber"].tf_set;
}


@end