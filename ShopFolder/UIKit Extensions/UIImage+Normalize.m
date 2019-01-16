//
//  UIImage+Normalize.m
//  ShopFolder
//
//  Created by Michael on 2011/11/05.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "UIImage+Normalize.h"

@implementation UIImage (Normalize)

- (UIImage *) normalize
{
    
    CGColorSpaceRef genericColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef thumbBitmapCtxt = CGBitmapContextCreate(NULL, 
                                                         self.size.width, 
                                                         self.size.height, 
                                                         8, (4 * self.size.width), 
                                                         genericColorSpace, 
                                                         kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(genericColorSpace);
    CGContextSetInterpolationQuality(thumbBitmapCtxt, kCGInterpolationDefault);
    CGRect destRect = CGRectMake(0, 0, self.size.width, self.size.height);
    CGContextDrawImage(thumbBitmapCtxt, destRect, self.CGImage);
    CGImageRef tmpThumbImage = CGBitmapContextCreateImage(thumbBitmapCtxt);
    CGContextRelease(thumbBitmapCtxt);    
    UIImage *result = [UIImage imageWithCGImage:tmpThumbImage];
    CGImageRelease(tmpThumbImage);
    
    return result;    
}

@end
