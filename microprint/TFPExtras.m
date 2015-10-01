//
//  Extras.m
//  MicroPrint
//
//

#import "TFPExtras.h"
#import "zlib.h"
@import MachO;


NSString *const TFPErrorDomain = @"TFPErrorDomain";
NSString *const TFPErrorGCodeStringKey = @"GCodeString";
NSString *const TFPErrorGCodeKey = @"GCode";
NSString *const TFPErrorGCodeLineKey = @"GCodeLine";


@implementation NSArray (TFPExtras)

- (NSArray*)tf_mapWithBlock:(id(^)(id object))function {
	NSMutableArray *array = [NSMutableArray new];
	for(id object in self) {
		id value = function(object);
		if(value) {
			[array addObject:value];
		}
	}
	return array;
}


- (NSArray*)tf_selectWithBlock:(BOOL(^)(id object))function {
	NSMutableArray *array = [NSMutableArray new];
	for(id object in self) {
		if(function(object)) {
			[array addObject:object];
		}
	}
	return array;
}


- (NSArray*)tf_rejectWithBlock:(BOOL(^)(id object))function {
	return [self tf_selectWithBlock:^BOOL(id object) {
		return !function(object);
	}];
}


- (NSSet*)tf_set {
	return [NSSet setWithArray:self];
}


@end



@implementation NSData (TFPExtras)


+ (instancetype)tf_singleByte:(uint8_t)byte {
	return [NSData dataWithBytes:&byte length:1];
}


- (NSData*)tf_fletcher16Checksum {
	uint8_t check1 = 0;
	uint8_t check2 = 0;
	
	const uint8_t *bytes = self.bytes;
	for(int i = 0; i < self.length; i++) {
		uint8_t byte = bytes[i];
		check1 = (check1 + byte) % 255;
		check2 = (check2 + check1) % 255;
	}
	
	NSMutableData *checksum = [NSMutableData data];
	[checksum appendBytes:&check1 length:sizeof(check1)];
	[checksum appendBytes:&check2 length:sizeof(check2)];
	return checksum;
}


- (NSUInteger)tf_offsetOfData:(NSData*)subdata {
	return [self rangeOfData:subdata options:0 range:NSMakeRange(0, self.length)].location;
}


- (NSData *)tf_dataByDecodingDeflate {
	NSData *data = self;
	if ([data length] == 0) return data;
	
	NSUInteger full_length = [data length];
	NSUInteger half_length = [data length] / 2;
	
	NSMutableData *decompressed = [NSMutableData dataWithLength:full_length + half_length];
	BOOL done = NO;
	int status;
	
	z_stream strm;
	strm.next_in = (Bytef *)[data bytes];
	strm.avail_in = (uInt)[data length];
	strm.total_out = 0;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	
	if (inflateInit2(&strm, (15+32)) != Z_OK) return nil;
	while (!done) {
		// Make sure we have enough room and reset the lengths.
		if (strm.total_out >= [decompressed length])
			[decompressed increaseLengthBy: half_length];
		strm.next_out = [decompressed mutableBytes] + strm.total_out;
		strm.avail_out = (uInt)([decompressed length] - strm.total_out);
		
		// Inflate another chunk.
		status = inflate (&strm, Z_SYNC_FLUSH);
		if (status == Z_STREAM_END) done = YES;
		else if (status != Z_OK) break;
	}
	if (inflateEnd (&strm) != Z_OK) return nil;
	
	// Set real length.
	if (done) {
		[decompressed setLength:strm.total_out];
		return [NSData dataWithData: decompressed];
	} else {
		return nil;
	}
}


@end


@implementation NSIndexSet (TFPExtras)


+ (NSIndexSet*)tf_indexSetWithIndexes:(NSInteger)firstIndex, ... {
	va_list list;
	va_start(list, firstIndex);
	
	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSetWithIndex:firstIndex];
	NSInteger index;
	while((index = va_arg(list, int)) >= 0) {
		[indexes addIndex:index];
	}
	
	va_end(list);
	return indexes;
}

+ (NSIndexSet*)ww_indexSetFromArray:(NSArray<NSNumber *> *)source {

    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];

    for (NSNumber *index in source) {
        [indexes addIndex:index.intValue];
    }

    return indexes;
}


@end


void TFLog(NSString *format, ...) {
	va_list list;
	va_start(list, format);
	NSString *string = [[NSString alloc] initWithFormat:format arguments:list];
	va_end(list);
	printf("%s\n", string.UTF8String);
}


uint64_t TFNanosecondTime(void) {
	mach_timebase_info_data_t info;
	mach_timebase_info(&info);
	return (mach_absolute_time() * info.numer) / info.denom;
}


CGFloat TFPVectorDot(CGVector a, CGVector b) {
	return a.dx * b.dx + a.dy * b.dy;
}


void TFAssertMainThread() {
	NSCAssert([NSThread isMainThread], @"Whoa. This should be on the main thread but isn't!");
}


void TFMainThread(void(^block)()) {
	if([NSThread isMainThread]) {
		block();
	}else{
		dispatch_async(dispatch_get_main_queue(), block);
	}
}