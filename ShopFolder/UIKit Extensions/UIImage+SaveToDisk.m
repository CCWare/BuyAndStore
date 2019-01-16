//
//  UIImage+SaveToDisk.m
//  ShopFolder
//
//  Created by Michael on 2011/11/02.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "UIImage+SaveToDisk.h"
#import "StringUtil.h"

@interface UIImage (PrivatMethods)
- (BOOL) _dumpImageToFile: (NSData *)imageData toPath:(NSString *)path;
@end

@implementation UIImage (SaveToDisk)

+ (BOOL) _dumpImageToFile: (NSData *)imageData toPath:(NSString *)path
{
    return [imageData writeToFile:[StringUtil fullPathInDocument:path] atomically:NO];
}

+ (BOOL) savePNGImage:(UIImage *)image toPath:(NSString *)path
{
    NSData *imageData = UIImagePNGRepresentation(image);
    return [self _dumpImageToFile:imageData toPath:path];
}

+ (BOOL) saveJPGImage:(UIImage *)image withQuality:(CGFloat)compressQuality toPath:(NSString *)path
{
    NSData *imageData = UIImageJPEGRepresentation(image, compressQuality);
    return [self _dumpImageToFile:imageData toPath:path];
}
@end
