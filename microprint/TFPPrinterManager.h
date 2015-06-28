//
//  TFPPrinterManager.h
//  MicroPrint
//
//  Created by Tomas Franzén on Tue 2015-06-23.
//

#import <Foundation/Foundation.h>


@interface TFPPrinterManager : NSObject

+ (instancetype)sharedManager;

@property (readonly) NSArray *printers; // Observable
@end