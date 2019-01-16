//
//  StringUtil.h
//  ShopFolder
//
//  Created by Michael on 2011/11/02.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Barcode.h"

#define kISBNPrefix @"ISBN"

@interface StringUtil : NSObject

+ (NSString *)fullPathInDocument:(NSString *)path;
+ (NSString *)fullPathInTemp:(NSString *)fileName;
+ (NSString *)fullPathInCache:(NSString *)fileName;
+ (NSString *)fullPathInLibrary:(NSString *)fileName;

+ (NSString *)formatBarcode:(Barcode *)barcode;
+ (NSString *)uniqueFileNameWithExtension:(NSString *)ext;

+ (NSString *)fullPathOfFolderImage:(NSString *)fileName;
+ (NSString *)fullPathOfItemImage:(NSString *)fileName;

+ (NSString *)sizeToString:(unsigned long long)byte; //1KB = 1000 Byte
@end
