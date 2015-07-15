//
//  TFPPrinterManager.m
//  MicroPrint
//
//  Created by Tomas Franzén on Tue 2015-06-23.
//

#import "TFPPrinterManager.h"
#import "TFPPrinter.h"
#import "Extras.h"
#import "TFPDryRunPrinter.h"

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
	self.printers = @[[TFPDryRunPrinter new]];
	[self identifyPrinters];
}


- (void)identifyPrinters {
	for(TFPPrinter *printer in self.printers) {
		if(!printer.serialNumber) {
			[printer establishConnectionWithCompletionHandler:nil];
		}
	}
}


- (NSArray*)printersForSerialPorts:(NSArray*)serialPorts {
	return [[serialPorts tf_selectWithBlock:^BOOL(ORSSerialPort *port) {
		uint16_t vendorID, productID;
		if([port getUSBVendorID:&vendorID productID:&productID]) {
			return vendorID == M3DMicroUSBVendorID && productID == M3DMicroUSBProductID;
		}else{
			return NO;
		}
	}] tf_mapWithBlock:^TFPPrinter*(ORSSerialPort *serialPort) {
		return [[TFPPrinter alloc] initWithSerialPort:serialPort];
	}];
}


- (instancetype)init {
	if(!(self = [super init])) return nil;
	__weak __typeof__(self) weakSelf = self;
	
	self.printers = [self printersForSerialPorts:[ORSSerialPortManager sharedSerialPortManager].availablePorts];
	[self identifyPrinters];
	
	[[ORSSerialPortManager sharedSerialPortManager] addObserver:self keyPath:@"availablePorts" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld block:^(MAKVONotification *notification) {
		NSMutableArray *printers = [weakSelf mutableArrayValueForKey:@"printers"];
		
		if(notification.kind == NSKeyValueChangeRemoval) {
			NSPredicate *wasRemovedPredicate = [NSPredicate predicateWithFormat:@"serialPort IN %@ && pendingConnection = NO", notification.oldValue];
			
			[printers removeObjectsInArray:[weakSelf.printers filteredArrayUsingPredicate:wasRemovedPredicate]];
		
		}else{
			[printers addObjectsFromArray:[weakSelf printersForSerialPorts:notification.newValue]];
			[weakSelf identifyPrinters];
		}
	}];
	
	return self;
}


@end
