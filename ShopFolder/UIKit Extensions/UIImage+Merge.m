//
//  UIImage+Merge.m
//  ShopFolder
//
//  Created by Chung-Chih Tsai on 2012/05/22.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "UIImage+Merge.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+ConverToImage.h"

@implementation UIImage (Merge)
+ (UIImage *)mergeImage:(UIImage *)foregroundImage intoImage:(UIImage *)backgroundImage atPosition:(CGPoint)position alpha:(CGFloat)transparency
{
    CGRect foregroundRect = CGRectMake(position.x, position.y, foregroundImage.size.width, foregroundImage.size.height);
    CGRect backgroundRect = CGRectMake(0, 0, backgroundImage.size.width, backgroundImage.size.height);
    
    if(position.x < 0) {
        backgroundRect.origin.x -= position.x;
        foregroundRect.origin.x = 0;
    }
    if(position.y < 0) {
        backgroundRect.origin.y -= position.y;
        foregroundRect.origin.y = 0;
    }

    CGRect mergedRect = CGRectUnion(foregroundRect, backgroundRect);

    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, mergedRect.size.width, mergedRect.size.height,
                                                 8, mergedRect.size.width*4, colorSpaceRef,
                                                 kCGImageAlphaPremultipliedLast);
    
    CGContextDrawImage(context, backgroundRect, backgroundImage.CGImage);
    CGContextDrawImage(context, foregroundRect, foregroundImage.CGImage);

    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    UIImage *result = [[UIImage alloc] initWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpaceRef);
    return result;
}

+ (UIImage *)drawView:(UIView *)view onImage:(UIImage *)image atPosition:(CGPoint)position alpha:(CGFloat)transparency
{
    //1. Draw view into UIImage
    UIImage *viewImage = [view convertToImage];
    
    //2. Merge to self
    return [UIImage mergeImage:viewImage intoImage:image atPosition:position alpha:transparency];
}
@end
