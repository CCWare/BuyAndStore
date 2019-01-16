//
//  UIImage+Merge.h
//  ShopFolder
//
//  Created by Chung-Chih Tsai on 2012/05/22.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//



@interface UIImage (Merge)
+ (UIImage *)mergeImage:(UIImage *)sourceImage intoImage:(UIImage *)targetImage atPosition:(CGPoint)position alpha:(CGFloat)transparency;
+ (UIImage *)drawView:(UIView *)view onImage:(UIImage *)image atPosition:(CGPoint)position alpha:(CGFloat)transparency;
@end
