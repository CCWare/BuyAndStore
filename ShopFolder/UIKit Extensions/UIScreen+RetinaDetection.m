//
//  UIScreen+isRetina.m
//  ShopFolder
//
//  Created by Michael on 2011/11/04.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "UIScreen+RetinaDetection.h"

@implementation UIScreen (RetinaDetection)
+ (BOOL) isRetina
{
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2){
        return YES;
    }

    return NO;
}
@end
