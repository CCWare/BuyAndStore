//
//  UIImage+Tint.m
//  ShopFolder
//
//  Created by Michael on 2011/12/02.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "UIImage+Tint.h"

@implementation UIImage (Tint)
- (UIImage *)tintedImageUsingColor:(UIColor *)tintColor
{
    UIGraphicsBeginImageContext(self.size);
    CGRect drawRect = CGRectMake(0, 0, self.size.width, self.size.height);
    [self drawInRect:drawRect];
    [tintColor set];
    UIRectFillUsingBlendMode(drawRect, kCGBlendModeSourceAtop);
    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return tintedImage;
}
@end
