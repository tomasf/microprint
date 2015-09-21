//
//  TFPSlicerProfile.h
//  microprint
//
//  Created by William Waggoner on 9/13/15.
//  Copyright © 2015 Tomas Franzén. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TFPGCode.h"
#import "TFPExtras.h"
#import "TFPGCodeHelpers.h"

typedef enum SlicerProfileType {
    CuraProfile,
    Slic3rProfile,
} SlicerProfileType;

@interface TFPSlicerProfile : NSObject
- (instancetype)initFromLines: (NSArray<TFPGCode *> *)lines;
- (void)setValue:(id)value forUndefinedKey:(NSString *)key;
- (id)objectForKeyedSubscript:(id)key;
- (id)valueForUndefinedKey:(NSString *)key;
- (BOOL)isCuraProfile;
- (BOOL)isSlic3rProfile;
- (BOOL)loadCuraProfile:(NSArray<TFPGCode *> *)lines;
- (BOOL)loadSlic3rProfile:(NSArray<TFPGCode *> *)lines;
- (NSString *)formattedValueForKey:(NSString *)key;
@end
