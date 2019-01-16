//
//  VersionComare.h
//  ShopFolder
//
//  Created by Michael on 2011/10/19.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VersionCompare : NSObject

+(NSComparisonResult) compareVersion: (NSString *) leftVersion toVersion:(NSString *) rightVersion;
@end
