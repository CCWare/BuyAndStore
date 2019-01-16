//
//  CustomEdgeTextView.h
//  ShopFolder
//
//  Created by Michael on 2012/1/11.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CustomEdgeTextView : UITextView
{
    UIEdgeInsets customInset;
}

@property (nonatomic, assign) UIEdgeInsets customInset;
@end
