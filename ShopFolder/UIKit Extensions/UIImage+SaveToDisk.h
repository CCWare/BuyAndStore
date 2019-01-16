//
//  UIImage+SaveToDisk.h
//  ShopFolder
//
//  Created by Michael on 2011/11/02.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UIImage (SaveToDisk)

+ (BOOL) savePNGImage:(UIImage *)image toPath:(NSString *)path;
+ (BOOL) saveJPGImage:(UIImage *)image withQuality:(CGFloat)compressQuality toPath:(NSString *)path;

@end
