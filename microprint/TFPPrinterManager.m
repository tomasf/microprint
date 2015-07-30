//
//  TFPPrinterManager.m
//  MicroPrint
//
//  Created by Tomas Franzén on Tue 2015-06-23.
//

#import "TFPPrinterManager.h"
#import "TFPPrinter.h"
#import "TFPExtras.h"
#import "TFPDryRunPrinter.h"
#import "TFPPrinterConnection.h"

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


- (void)startDryRunMode {
	[[self mutableArrayValueForKey:@"printers"] addObject:[TFPDryRunPrinter new]];
}


- (NSArray*)printersForSerialPorts:(NSArray*)serialPorts {
	return [[serialPorts tf_selectWithBlock:^BOOL(ORSSerialPort *port) {
		return port.USBVendorID.unsignedShortValue == M3DMicroUSBVendorID && port.USBProductID.unsignedShortValue == M3DMicroUSBProductID;
	}] tf_mapWithBlock:^TFPPrinter*(ORSSerialPort *serialPort) {
		TFPPrinterConnection *connection = [[TFPPrinterConnection alloc] initWithSerialPort:serialPort];
		return [[TFPPrinter alloc] initWithConnection:connection];
	}];
}


- (instancetype)init {
	if(!(self = [super init])) return nil;
	__weak __typeof__(self) weakSelf = self;
	
	self.printers = [self printersForSerialPorts:[ORSSerialPortManager sharedSerialPortManager].availablePorts];
	
	[[ORSSerialPortManager sharedSerialPortManager] addObserver:self keyPath:@"availablePorts" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld block:^(MAKVONotification *notification) {
		NSMutableArray *printers = [weakSelf mutableArrayValueForKey:@"printers"];
		
		if(notification.kind == NSKeyValueChangeRemoval) {
			NSArray *removedPrinters = [weakSelf.printers tf_selectWithBlock:^BOOL(TFPPrinter *printer) {
				return [printer printerShouldBeInvalidatedWithRemovedSerialPorts:notification.oldValue];
			}];
			[printers removeObjectsInArray:removedPrinters];
		
		}else{
			[printers addObjectsFromArray:[weakSelf printersForSerialPorts:notification.newValue]];
		}
	}];
	
	return self;
}


@end
