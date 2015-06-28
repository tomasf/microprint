//
//  main.m
//  MicroPrint
//
//

#import "TFPCLIController.h"

int main(int argc, char * argv[]) {
	@autoreleasepool {
		[[TFPCLIController new] runWithArgumentCount:argc arguments:argv];
	}
    return 0;
}
