//
//  TFPPrintStatusController.m
//  microprint
//
//  Created by Tomas Franzén on Wed 2015-07-15.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPPrintStatusController.h"
#import "Extras.h"

#import "TFTimer.h"
#import "MAKVONotificationCenter.h"


static const NSInteger minimumPrintCodeOffsetForEstimation = 100;


@interface TFPPrintStatusController ()
@property TFPPrintJob *printJob;

@property TFTimer *timer;
@property NSMutableDictionary *phaseRanges;
@property uint64_t printContentStartTime;

@property (readwrite) NSTimeInterval elapsedTime;
@property (readwrite) NSTimeInterval estimatedRemainingTime;
@property (readwrite) BOOL hasRemainingTimeEstimate;

@property (readwrite) double printProgress;
@property (readwrite) TFPPrintPhase currentPhase;
@property (readwrite) double phaseProgress;
@end



@implementation TFPPrintStatusController


- (instancetype)initWithPrintJob:(TFPPrintJob*)printJob {
	if(!(self = [super init])) return nil;
	__weak __typeof__(self) weakSelf = self;
	
	NSParameterAssert(printJob != nil);
	
	self.printJob = printJob;
	[self determinePhaseRanges];
	
	self.timer = [TFTimer timerWithInterval:1 repeating:YES block:^{
		[weakSelf periodicalUpdate];
	}];
	
	[self.printJob addObserver:self keyPath:@"completedRequests" options:NSKeyValueObservingOptionInitial block:^(MAKVONotification *notification) {
		[weakSelf progressUpdate];
	}];
	
	return self;
}


- (void)progressUpdate {
	NSUInteger offset = self.printJob.completedRequests;
	self.currentPhase = [self printPhaseForIndex:offset];
	NSRange phaseRange = [self rangeForPrintPhase:self.currentPhase];
	
	self.phaseProgress = (double)(offset-phaseRange.location) / phaseRange.length;
	
	NSRange raftRange = [self rangeForPrintPhase:TFPPrintPhaseAdhesion];
	NSRange modelRange = [self rangeForPrintPhase:TFPPrintPhaseModel];
	
	NSRange printRange = modelRange;
	if(raftRange.location != NSNotFound) {
		printRange = NSUnionRange(printRange, raftRange);
	}
	
	NSInteger printStartOffset = (NSInteger)offset-(NSInteger)printRange.location;
	double printProgress = (double)printStartOffset / printRange.length;
	self.printProgress = MIN(MAX(printProgress, 0), 1);
	
	if(printProgress > 0 && self.printContentStartTime == 0) {
		self.printContentStartTime = TFNanosecondTime();
	}
	
	if(printStartOffset >= minimumPrintCodeOffsetForEstimation && printProgress <= 1) {
		NSTimeInterval elapsedPrintTime = (double)(TFNanosecondTime()-self.printContentStartTime) / NSEC_PER_SEC;
		NSTimeInterval fullTime = elapsedPrintTime / printProgress;
		NSTimeInterval remainingTime = (1-printProgress) * fullTime;
		
		self.estimatedRemainingTime = remainingTime;
		self.hasRemainingTimeEstimate = YES;
	}else{
		self.hasRemainingTimeEstimate = NO;
	}
}


- (void)periodicalUpdate {
	self.elapsedTime = self.printJob.elapsedTime;
}


- (void)determinePhaseRanges {
	__block TFPPrintPhase phase = TFPPrintPhasePreamble;
	__block NSUInteger startLine = 0;
	NSMutableDictionary *phaseRanges = [NSMutableDictionary new];
	
	[self.printJob.program.lines enumerateObjectsUsingBlock:^(TFPGCode *code, NSUInteger index, BOOL *stop) {
		if(!code.comment) {
			return;
		}
		NSRange range = NSMakeRange(startLine, index-startLine);
		
		if([code.comment hasPrefix:@"LAYER:"]) {
			NSInteger layerIndex = [[code.comment substringFromIndex:6] integerValue];
			
			if(phase == TFPPrintPhasePreamble) {
				phaseRanges[@(TFPPrintPhasePreamble)] = [NSValue valueWithRange:range];
				
				if(layerIndex < 0) {
					phase = TFPPrintPhaseAdhesion;
				}else{
					phase = TFPPrintPhaseModel;
				}
				startLine = index;
			}else if(phase == TFPPrintPhaseAdhesion && layerIndex >= 0) {
				phaseRanges[@(TFPPrintPhaseAdhesion)] = [NSValue valueWithRange:range];
				phase = TFPPrintPhaseModel;
				startLine = index;
			}
		}else if([code.comment isEqual:@"POSTAMBLE"]) {
			phaseRanges[@(TFPPrintPhaseModel)] = [NSValue valueWithRange:range];
			phase = TFPPrintPhasePostamble;
			startLine = index;
		}else if([code.comment isEqual:@"END"]) {
			phaseRanges[@(TFPPrintPhasePostamble)] = [NSValue valueWithRange:range];
		}
	}];
	
	self.phaseRanges = phaseRanges;
}


- (TFPPrintPhase)printPhaseForIndex:(NSUInteger)index {
	for(NSNumber *phaseNumber in self.phaseRanges) {
		NSRange range = [self.phaseRanges[phaseNumber] rangeValue];
		if(NSLocationInRange(index, range)) {
			return phaseNumber.unsignedIntegerValue;
		}
	}
	return TFPPrintPhaseInvalid;
}


- (NSRange)rangeForPrintPhase:(TFPPrintPhase)phase {
	NSValue *value = self.phaseRanges[@(phase)];
	if (value) {
		return value.rangeValue;
	} else {
		return NSMakeRange(NSNotFound, 0);
	}
}


@end
