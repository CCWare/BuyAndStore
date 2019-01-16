//
//  UIView+navigationTitleViewWithImage.m
//  ShopFolder
//
//  Created by Michael on 2012/11/22.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "UIView+navigationTitleViewWithImage.h"

@implementation UIView (navigationTitleViewWithImage)
+ (UIView *)navigationTitleViewWithImage:(UIImage *)image titleLabel:(NSString *)title maxWidth:(CGFloat)width
{
    const CGFloat imageSize = 24.0f;
    const CGFloat imageToLabelSpace = 4.0f;
    const CGFloat maxLabelWidth = width - imageSize - imageToLabelSpace;
    UIFont *labelFont = [UIFont boldSystemFontOfSize:22];
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, imageSize, imageSize)];
    imageView.image = image;
    
    CGSize labelSize = [title sizeWithFont:labelFont
                                  forWidth:maxLabelWidth
                             lineBreakMode:UILineBreakModeTailTruncation];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(imageSize+imageToLabelSpace, 0, labelSize.width, imageSize)];
    label.lineBreakMode = UILineBreakModeTailTruncation;
    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    label.font = labelFont;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    label.text = title;
    
    UIView *titleView = [[UIView alloc] initWithFrame:CGRectMake(0, (44.0-imageSize)/2.0f,
                                                                 imageSize+imageToLabelSpace+labelSize.width, imageSize)];
    [titleView addSubview:imageView];
    [titleView addSubview:label];
    
    return titleView;
}
@end
