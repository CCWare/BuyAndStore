//
//  UIView+ConverToImage.m
//  ShopFolder
//
//  Created by Chung-Chih Tsai on 2012/05/22.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "UIView+ConverToImage.h"
#import <QuartzCore/QuartzCore.h>

@implementation UIView (ConverToImage)
- (UIImage *)convertToImage
{
//    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
//    CGContextRef context = CGBitmapContextCreate(NULL, self.frame.size.width, self.frame.size.height, 8,
//                                                 self.frame.size.width*4, colorSpaceRef, kCGImageAlphaPremultipliedLast);
//    CGContextScaleCTM(context, 1.0f, -1.0f);
//    CGContextTranslateCTM(context, 0.0f, -self.frame.size.height);
//    [self.layer renderInContext:context];
//
//    CGImageRef imageRef = CGBitmapContextCreateImage(context);
//    UIImage *result = [[UIImage alloc] initWithCGImage:imageRef];
//    CGImageRelease(imageRef);
//    CGContextRelease(context);
//    CGColorSpaceRelease(colorSpaceRef);
//
//    return result;
    
    CGPoint contentOffset = CGPointZero;
    BOOL isScrollView = [self.class isSubclassOfClass:[UIScrollView class]];
    if(isScrollView) {
        contentOffset = ((UIScrollView *)self).contentOffset;
    }
    
    if(UIGraphicsBeginImageContextWithOptions != NULL) {
        UIGraphicsBeginImageContextWithOptions(self.frame.size, self.opaque, [[UIScreen mainScreen] scale]);
    } else {
        UIGraphicsBeginImageContext(self.frame.size);
    }
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    if(isScrollView) {
        CGContextTranslateCTM(ctx, -contentOffset.x, -contentOffset.y);
    }
    
    [self.layer renderInContext:ctx];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
@end
