//
//  TFPGCodeDocument.m
//  microprint
//
//  Created by Tomas Franzén on Mon 2015-07-13.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPGCodeDocument.h"
#import "TFPGCodeProgram.h"


@interface TFPGCodeDocument ()
@end


@implementation TFPGCodeDocument


- (void)makeWindowControllers {
	// Override to return the Storyboard file name of the document.
	[self addWindowController:[[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"PrintWindowController"]];
}


- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
	self.data = data;
	return YES;
}


@end
