//
//  VersionComare.m
//  ShopFolder
//
//  Created by Michael on 2011/10/19.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "VersionCompare.h"

@implementation VersionCompare

/*
 * compareVersions(@"10.4", @"10.3") returns NSOrderedDescending (1)
 * compareVersions(@"10.5", @"10.5.0") returns NSOrderedSame (0)
 * compareVersions(@"10.4 Build 8L127", @"10.4 Build 8P135") returns NSOrderedAscending (-1)
 */
+(NSComparisonResult) compareVersion: (NSString *) leftVersion toVersion:(NSString *) rightVersion
{
    int i;
    
    // Break version into fields (separated by '.')
    NSMutableArray *leftFields = [[NSMutableArray alloc] initWithArray:[leftVersion componentsSeparatedByString:@"."]];
    NSMutableArray *rightFields = [[NSMutableArray alloc] initWithArray:[rightVersion componentsSeparatedByString:@"."]];
    
    // Implict ".0" in case version doesn't have the same number of '.'
    if ([leftFields count] < [rightFields count]) {
        while ([leftFields count] != [rightFields count]) {
            [leftFields addObject:@"0"];
        }
    } else if ([leftFields count] > [rightFields count]) {
        while ([leftFields count] != [rightFields count]) {
            [rightFields addObject:@"0"];
        }
    }
    
    // Do a numeric comparison on each field
    for(i = 0; i < [leftFields count]; i++) {
        NSComparisonResult result = [[leftFields objectAtIndex:i] compare:[rightFields objectAtIndex:i] options:NSNumericSearch];
        if (result != NSOrderedSame) {
            return result;
        }
    }
    
    return NSOrderedSame;
}
@end
