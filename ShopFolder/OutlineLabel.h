//
//  OutlineLabel.h
//  ShopFolder
//
//  Created by Michael on 2011/12/27.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OutlineLabel : UILabel
{
    UIColor *outlineColor;
    CGFloat outlineWidth;
}

@property (nonatomic, strong) UIColor *outlineColor;
@property (nonatomic, assign) CGFloat outlineWidth;
@end
