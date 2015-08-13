//
//  TFPDryRunPrinter.m
//  MicroPrint
//
//  Created by Tomas Franzén on Wed 2015-06-24.
//

#import "TFPDryRunPrinter.h"
#import "TFPExtras.h"


static double speedMultiplier = 10;


@interface TFPPrinter (Private)
@property (readwrite) BOOL pendingConnection;
@property (readwrite) NSString *serialNumber;
@end


@interface TFPDryRunPrinter ()
@property TFP3DVector *simulatedPosition;
@property double feedRate;
@property BOOL relativeMode;
@end


@interface TFPPrinter (HelpersPrivate)
- (void)fetchBedOffsetsWithCompletionHandler:(void(^)(BOOL success, TFPBedLevelOffsets offsets))completionHandler;
- (void)setBedOffsets:(TFPBedLevelOffsets)offsets completionHandler:(void(^)(BOOL success))completionHandler;
@end




@implementation TFPDryRunPrinter


- (instancetype)init {
	if(!(self = [super init])) return nil;
	
	self.simulatedPosition = [TFP3DVector zeroVector];
	
	return self;
}


- (void)sendGCode:(TFPGCode*)code responseHandler:(void(^)(BOOL success, NSDictionary *value))block responseQueue:(dispatch_queue_t)queue {
	NSInteger G = [code valueForField:'G' fallback:-1];
	NSTimeInterval duration = 0.02;
	
	if(G == 0 || G == 1) {
		TFP3DVector *movement = [[code movementVector] vectorByDefaultingToValues:self.simulatedPosition];
		self.feedRate = [code valueForField:'F' fallback:self.feedRate];
		
		if(self.relativeMode) {
			movement = [TFP3DVector vectorWithX:@(self.simulatedPosition.x.doubleValue + movement.x.doubleValue)
											  Y:@(self.simulatedPosition.y.doubleValue + movement.y.doubleValue)
											  Z:@(self.simulatedPosition.z.doubleValue + movement.z.doubleValue)];
		}
		
		double distance = [self.simulatedPosition distanceToPoint:movement];
		
		double calculatedSpeed = (6288.78 * (self.feedRate-830))/((self.feedRate-828.465) * (self.feedRate+79.5622));
		duration = distance / calculatedSpeed;
		duration /= self.speedMultiplier;
		self.simulatedPosition = movement;
		
	} else if(G == 90) {
		self.relativeMode = NO;
		
	} else if(G == 91) {
		self.relativeMode = YES;
    } else if(G == 30 || G == 28) {
        TFP3DVector *movement = [TFP3DVector vectorWithX:@50 Y:@50 Z:(G == 30 ? @0 : self.simulatedPosition.z)];
        self.feedRate = [code valueForField:'F' fallback:self.feedRate];

        double distance = [self.simulatedPosition distanceToPoint:movement];

        double calculatedSpeed = (6288.78 * (self.feedRate-830))/((self.feedRate-828.465) * (self.feedRate+79.5622));
        duration = distance / calculatedSpeed;
        duration = (duration / self.speedMultiplier) + 4;   // At least 4 seconds
        self.simulatedPosition = movement;
    }
	
	dispatch_after(dispatch_time(0, duration * NSEC_PER_SEC), queue, ^{
		if(block) {
			block(YES, @{});
		}
	});
}


- (TFPPrinterColor)color {
	return TFPPrinterColorOther;
}


- (NSString *)firmwareVersion {
	return @"0000000000";
}


- (void)fetchBacklashValuesWithCompletionHandler:(void(^)(BOOL success, TFPBacklashValues values))completionHandler {
	dispatch_after(dispatch_time(0, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		completionHandler(YES, (TFPBacklashValues){0.33, 0.69, 1500});
	});
}


- (void)fetchBedOffsetsWithCompletionHandler:(void (^)(BOOL, TFPBedLevelOffsets))completionHandler {
	dispatch_after(dispatch_time(0, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		completionHandler(YES, (TFPBedLevelOffsets){-0.30, -0.4, -0.65, -1, -0.95});
	});
}


- (void)establishConnectionWithCompletionHandler:(void(^)(NSError *error))completionHandler {
	self.pendingConnection = YES;
	dispatch_after(dispatch_time(0, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		self.serialNumber = @"TEST-00-00-00-00-123-456";
		self.pendingConnection = NO;
		if(completionHandler) {
			completionHandler(nil);
		}
	});
};


- (void)setBedOffsets:(TFPBedLevelOffsets)offsets completionHandler:(void (^)(BOOL))completionHandler {
	TFLog(@"Dry run setBedOffsets: %@", TFPBedLevelOffsetsDescription(offsets));
	[super setBedOffsets:offsets completionHandler:completionHandler];
}


- (double)speedMultiplier {
	return speedMultiplier;
}


+ (void)setSpeedMultiplier:(double)multiplier {
	speedMultiplier = multiplier;
}


@end
