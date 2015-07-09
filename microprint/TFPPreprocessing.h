//
//  TFPPreprocessing.h
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-09.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TFPGCodeProgram, TFPPrintParameters;


@interface TFPPreprocessing : NSObject
+ (TFPGCodeProgram *)programByPreprocessingProgram:(TFPGCodeProgram *)program usingParameters:(TFPPrintParameters *)params;
@end
