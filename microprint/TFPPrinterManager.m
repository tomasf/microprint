//
//  TFPPrinterManager.m
//  MicroPrint
//
//  Created by Tomas Franzén on Tue 2015-06-23.
//

#import "TFPPrinterManager.h"
#import "TFPPrinter.h"
#import "Extras.h"

#import "MAKVONotificationCenter.h"
#import "ORSSerialPortManager.h"


static const uint16_t M3DMicroUSBVendorID = 0x03EB;
static const uint16_t M3DMicroUSBProductID = 0x2404;


@interface TFPPrinterManager ()
@property (readwrite) NSArray *printers; // Observable
@end


@implementation TFPPrinterManager


+ (instancetype)sharedManager {
	static TFPPrinterManager *singleton;
	return singleton ?: (singleton = [self new]);
}


- (instancetype)init {
	if(!(self = [super init])) return nil;
	
	self.printers = [[[ORSSerialPortManager sharedSerialPortManager].availablePorts tf_selectWithBlock:^BOOL(ORSSerialPort *port) {
		uint16_t vendorID, productID;
		if([port getUSBVendorID:&vendorID productID:&productID]) {
			return vendorID == M3DMicroUSBVendorID && productID == M3DMicroUSBProductID;
		}else{
			return NO;
		}
	}] tf_mapWithBlock:^TFPPrinter*(ORSSerialPort *serialPort) {
		return [[TFPPrinter alloc] initWithSerialPort:serialPort];
	}];
	
	
	[[ORSSerialPortManager sharedSerialPortManager] addObserver:self keyPath:@"availablePorts" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld block:^(MAKVONotification *notification) {
		// TBI
	}];
	
	return self;
}


@end
