//
//  TFPScriptManager.h
//  microprint
//
//  Created by Tomas Franzén on Thu 2015-07-23.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

@import AppKit;


@interface TFPScriptManager : NSObject
@property (readonly) NSArray *recentScripts;

+ (instancetype)sharedManager;

- (void)addRecentScript:(NSURL*)URL;
- (NSOpenPanel*)openPanelForSelectingScript;
- (BOOL)runScriptFile:(NSURL*)URL printName:(NSString*)printName duration:(NSString*)durationString errorInfo:(NSDictionary**)error;
@end