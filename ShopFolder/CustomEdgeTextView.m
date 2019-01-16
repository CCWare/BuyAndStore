//
//  CustomEdgeTextView.m
//  ShopFolder
//
//  Created by Michael on 2012/1/11.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "CustomEdgeTextView.h"

@implementation CustomEdgeTextView
@synthesize customInset;

- (UIEdgeInsets)contentInset
{
    return self.customInset;
}

@end
