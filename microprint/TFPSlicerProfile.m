//
//  TFPSlicerProfile.m
//  microprint
//
//  Created by William Waggoner on 9/13/15.
//  Copyright © 2015 Tomas Franzén. All rights reserved.
//

#import "TFPSlicerProfile.h"

#define CURA_COMMENT @"CURA_PROFILE_STRING:"
#define SLIC3R_COMMENT @" generated by Slic3r"
#define PROFILE_REGEX @"^\\s*(\\S+[\\S ]*?)\\s*=\\s*(\\S.*)$"

typedef NSMutableDictionary<NSString*, NSString*> ProfileDict;

@interface TFPSlicerProfile ()
@property ProfileDict *values;
@property enum SlicerProfileType profileType;
@end

@implementation TFPSlicerProfile

+ (NSSet *)keyPathsForValuesAffectingWall_thickness {
    return @[@"perimeters", @"external perimeters extrusion width"].tf_set;
}

+ (NSSet *)keyPathsForValuesAffectingPrint_speed {
    return @[@"perimeter_speed"].tf_set;
}

+ (NSSet *)keyPathsForValuesAffectingSupport {
    return @[@"support_material"].tf_set;
}

+ (NSSet *)keyPathsForValuesAffectingPlatform_adhesion {
    return @[@"raft_layers", @"brim_width"].tf_set;
}

- (instancetype)initFromLines: (NSArray<TFPGCode *> *)lines {
    if (self = [super init]) {
        self.values = [NSMutableDictionary dictionaryWithCapacity:200];

        if([self hasCuraProfile: lines]) {
            self.profileType = CuraProfile;
            [self loadCuraProfile:lines];

        } else if ([self hasSlic3rProfile: lines]) {
            self.profileType = Slic3rProfile;
            [self loadSlic3rProfile:lines];

        } else { // No profile we know about ...
            self.values = nil;  // Release the empty dictionary, sorry for the trouble ...
            self = nil;
        }
    }

    return self;
}

// If the key exists in the dictionary, return that; otherwise translate based on profile type
- (id)valueForUndefinedKey:(NSString *)key {
    NSString *retVal= [self.values valueForKey:key];
    if (!retVal) {
        switch (self.profileType) {
            case CuraProfile:
                // We're done ... nothing to see here
                break;

            case Slic3rProfile:
                // Only check for the things we need to translate ...
                if ([key isEqualToString: @"wall_thickness"]) {
                    retVal = @(self.values[@"perimeters"].doubleValue *
                                self.values[@"external perimeters extrusion width"].doubleValue).stringValue;

                } else if ([key isEqualToString: @"print_speed"]) {
                    retVal = self.values[@"perimeter_speed"];

                } else if ([key isEqualToString: @"support"]) {
                    retVal = [self.values[@"support_material"] isEqualTo:@"1"] ? @"Yes" : @"None";

                } else if ([key isEqualToString: @"platform_adhesion"]) {
                    int raftLayers = self.values[@"raft_layers"].intValue;
                    int brimWidth = self.values[@"brim_width"].intValue;

                    if (raftLayers) {
                        retVal = [NSString stringWithFormat:@"Raft(%d)", raftLayers];
                    }

                    if (brimWidth) {
                        NSString *brimString = [NSString stringWithFormat:@"Brim(%d)", brimWidth];

                        if (!retVal) {
                            retVal = brimString;

                        } else {
                            retVal = [retVal stringByAppendingString:[@"/" stringByAppendingString:brimString]];
                        }
                    }

                    if (!retVal) {retVal = @"None";}
                }
                break;

            default:
                break;
        }
    }

    return retVal;
}

- (void)setValue:(NSString *)value forUndefinedKey:(NSString *)key {
    [self willChangeValueForKey:key];

    [self.values setValue:value forKey:key];

    [self didChangeValueForKey:key];
}

- (void)setObject:(NSString *)object forKeyedSubscript:(NSString *)key {
    return [self.values setValue:object forKey:key];
}

- (NSString *)objectForKeyedSubscript:(NSString *)key {
    return [self.values objectForKey:key];
}

- (BOOL)isCuraProfile {
    return self.profileType == CuraProfile;
}

- (BOOL)isSlic3rProfile {
    return self.profileType == Slic3rProfile;
}

- (BOOL)hasCuraProfile:(NSArray<TFPGCode *> *)lines {
    return [self curaProfileComment:lines] != NULL;
}

- (BOOL)hasSlic3rProfile:(NSArray<TFPGCode *> *)lines {
    return lines.count > 0 && [lines[0].comment hasPrefix:SLIC3R_COMMENT];
}

- (NSString *)curaProfileComment:(NSArray<TFPGCode *> *)lines {
    __block NSString *comment;

    [lines enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(TFPGCode *code, NSUInteger idx, BOOL * _Nonnull stop) {
        if([code.comment hasPrefix:CURA_COMMENT]) {
            comment = [code.comment substringFromIndex:CURA_COMMENT.length];
            *stop = YES;
        }
    }];

    return comment;
}

- (BOOL)loadCuraProfile:(NSArray<TFPGCode *> *)lines {
    NSString *base64 = [self curaProfileComment:lines];

    if(base64) {

        NSData *deflatedData = [[NSData alloc] initWithBase64EncodedString:base64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
        NSData *rawData = [deflatedData tf_dataByDecodingDeflate];

        if(rawData) {
            /* The profile is one string in two sections. The sections are separated by \x0C and each profile item is 
             terminated with \x08. We don't care about the sections so we first turn the \x0C into \x08 then split the result
             with \x08 ...
             */
            NSArray *pairs = [[[[NSString alloc] initWithData:rawData encoding:NSUTF8StringEncoding]
                               stringByReplacingOccurrencesOfString:@"\x0C" withString:@"\x08"]
                              componentsSeparatedByString:@"\x08"];

            for(NSString *pairString in pairs) {
                NSUInteger separator = [pairString rangeOfString:@"="].location;
                if(separator == NSNotFound) {
                    continue;
                }

                NSString *key = [pairString substringWithRange:NSMakeRange(0, separator)];
                NSString *value = [pairString substringWithRange:NSMakeRange(separator+1, pairString.length - separator - 1)];
                [self.values setValue:value forKey:key];
            }
        }
    }

    return self.values.count > 0;
}

- (BOOL)loadSlic3rProfile:(NSArray<TFPGCode *> *)lines {
    if(lines.count > 0) {
        TFPGCode *firstLine = lines[0];

        if(![firstLine hasFields] && firstLine.comment && [firstLine.comment hasPrefix:SLIC3R_COMMENT]) {   // Check to be sure it's a Slic3r profile
            NSError *error = NULL;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:PROFILE_REGEX options:0 error:&error];

            if(error) {
                NSLog(@"Regex error: %@:%@", error.localizedFailureReason, error.localizedDescription);
                abort();
            }

            for(TFPGCode *line in lines) {
                if(line.comment){
                    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:line.comment options:0 range:NSMakeRange(0, line.comment.length)];

                    if(matches.count>0) {
                        NSString *key = [line.comment substringWithRange:[matches[0] rangeAtIndex:1]];
                        NSString *val = [line.comment substringWithRange:[matches[0] rangeAtIndex:2]];
                        [self willChangeValueForKey:key];
                        [self.values setValue:val forKey:key];
                        [self didChangeValueForKey:key];
                    }
                }
            }
        }
    }

    return self.values.count > 0;
}

// Return the formatted value for the attribute key. Keys are translated, when necessary, from the original Cura
// names to the appropriate slicer names (sometimes with calculations)
- (NSString *)formattedValueForKey:(NSString *)key {
    NSNumberFormatter *mmFormatter = [NSNumberFormatter new];
    mmFormatter.minimumIntegerDigits = 1;
    mmFormatter.minimumFractionDigits = 2;
    mmFormatter.maximumFractionDigits = 2;
    mmFormatter.positiveSuffix = @" mm";
    mmFormatter.negativeSuffix = @" mm";

    NSNumberFormatter *mmpsFormatter = [mmFormatter copy];
    mmpsFormatter.positiveSuffix = @" mm/s";
    mmpsFormatter.negativeSuffix = @" mm/s";

    NSString *value = [self valueForKey:key];

    double doubleValue = value.doubleValue;

    if([key isEqual:@"layer_height"] || [key isEqual:@"wall_thickness"]) {
        return [mmFormatter stringFromNumber:@(doubleValue)];

    }else if([key isEqual:@"print_speed"]) {
        return [mmpsFormatter stringFromNumber:@(doubleValue)];

    }else if([key isEqual:@"fill_density"]) {
        return [NSString stringWithFormat:@"%d%%", value.intValue]; // Handles values like 20 (Cura) or 20% (Slic3r)

    }else if([key isEqual:@"support"]) {
        if([value isEqual:@"Touching buildplate"]) {
            return @"Buildplate";
        } else {
            return value;
        }
        
    }else if([key isEqual:@"platform_adhesion"]) {
        return value;
        
    }else{
        return nil;
    }
}

@end