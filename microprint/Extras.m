//
//  Extras.m
//  MicroPrint
//
//

#import "Extras.h"
@import MachO;


@implementation NSArray (TFExtras)

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

@end



@implementation NSDecimalNumber (TFExtras)

- (NSDecimalNumber *)tf_squareRoot {
	if ([self compare:[NSDecimalNumber zero]] == NSOrderedAscending) {
		return [NSDecimalNumber notANumber];
	}else if([self isEqual:[NSDecimalNumber zero]]) {
		return self;
	}
	
	NSDecimalNumber *half = [NSDecimalNumber decimalNumberWithMantissa:5 exponent:-1 isNegative:NO];
	NSDecimalNumber *guess = [[self decimalNumberByAdding:[NSDecimalNumber one]] decimalNumberByMultiplyingBy:half];
	
	@try {
		const int NUM_ITERATIONS_TO_CONVERGENCE = 6;
		for (int i = 0; i < NUM_ITERATIONS_TO_CONVERGENCE; i++) {
			guess = [[[self decimalNumberByDividingBy:guess] decimalNumberByAdding:guess] decimalNumberByMultiplyingBy:half];
		}
	} @catch (NSException *exception) {
		// deliberately ignore exception and assume the last guess is good enough
	}
	
	return guess;
}


- (BOOL)tf_nonZero {
	return ![self isEqual:[NSDecimalNumber zero]];
}


@end



@implementation NSData (TFExtras)

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


- (NSUInteger)tf_indexOfData:(NSData*)subdata {
	return [self rangeOfData:subdata options:0 range:NSMakeRange(0, self.length)].location;
}


@end




#import "ORSSerialPort.h"
#import <IOKit/usb/USB.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/serial/IOSerialKeys.h>


@implementation ORSSerialPort (TFExtras)


// Return value must be released with IOObjectRelease
static io_object_t IOEntryAncestorConformingTo(io_object_t object, const io_name_t className) {
	IOObjectRetain(object); // released later
	
	for(;;) {
		io_object_t parent = 0;
		IORegistryEntryGetParentEntry(object, kIOServicePlane, &parent);
		IOObjectRelease(object);
		if(!parent) {
			break;
		}
		if(IOObjectConformsTo(parent, className)) {
			return parent;
		}
		object = parent;
	}
	return 0;
}



- (BOOL)getUSBVendorID:(uint16_t*)vendorID productID:(uint16_t*)productID {
	io_object_t USBInterface = IOEntryAncestorConformingTo(self.IOKitDevice, kIOUSBInterfaceClassName);
	if(!USBInterface) {
		return NO;
	}
	
	NSNumber *vendorIDNumber = CFBridgingRelease(IORegistryEntryCreateCFProperty(USBInterface, CFSTR(kUSBVendorID), kCFAllocatorDefault, 0));
	NSNumber *productIDNumber = CFBridgingRelease(IORegistryEntryCreateCFProperty(USBInterface, CFSTR(kUSBProductID), kCFAllocatorDefault, 0));
	
	*vendorID = vendorIDNumber.unsignedShortValue;
	*productID = productIDNumber.unsignedShortValue;
	
	IOObjectRelease(USBInterface);
	return vendorIDNumber && productIDNumber;
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
