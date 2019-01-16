//
//  StringUtil.m
//  ShopFolder
//
//  Created by Michael on 2011/11/02.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "StringUtil.h"
#import "Database.h"    //For converting database

@implementation StringUtil

+ (NSString *)_appendFileName:(NSString *)fileName toPath:(NSString *)path
{
    NSString *newPath = ([path hasSuffix:@"/"]) ? [path copy] : [path stringByAppendingString:@"/"];
    
    if([fileName length] == 0) {
        return newPath;
    }
    
    if([fileName hasPrefix:newPath]) {
        return [fileName copy];
    } else {
        newPath = [newPath stringByAppendingString:fileName];
    }
    
    return newPath;
}

+ (NSString *)fullPathInDocument:(NSString *)fileName
{
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentsDirectory = [paths objectAtIndex:0];
    
    return [StringUtil _appendFileName:fileName toPath:documentsDirectory];
}

+ (NSString *)fullPathInTemp:(NSString *)fileName
{
    return [StringUtil _appendFileName:fileName toPath:NSTemporaryDirectory()];
}

+ (NSString *)fullPathInCache:(NSString *)fileName
{
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString* cacheDirectory = [paths objectAtIndex:0];
    return [StringUtil _appendFileName:fileName toPath:cacheDirectory];
}

+ (NSString *)fullPathInLibrary:(NSString *)fileName
{
    NSURL *libraryPath = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    return [self _appendFileName:fileName toPath:[libraryPath path]];
}

+ (NSString *)formatBarcode: (Barcode *)barcode
{
    if(barcode == nil ||
       [barcode.barcodeData length] == 0)
    {
        return nil;
    }

    NSString *result = nil;
    if([barcode.barcodeType hasPrefix:kISBNPrefix]) {
        result = [NSString stringWithFormat:@"%@ %@", kISBNPrefix, barcode.barcodeData];
    } else {
        result = barcode.barcodeData;
    }
    
    return result;
}

+ (NSString *)uniqueFileNameWithExtension:(NSString *)ext
{
    CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef uuidStr = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
    CFRelease(uuidRef);
    
    NSString *fileName = nil;
    if([ext length] > 0) {
        fileName = [NSString stringWithFormat:@"%@.%@", uuidStr, ext];
    } else {
        fileName = [NSString stringWithFormat:@"%@", uuidStr];
    }
    CFRelease(uuidStr);
    
    return fileName;
}

+ (NSString *)fullPathOfFolderImage:(NSString *)fileName
{
    if([kFolderImagePrefix hasSuffix:@"/"]) {
        return [StringUtil fullPathInDocument: [NSString stringWithFormat:@"%@%@", kFolderImagePrefix, fileName]];
    }
    
    return [StringUtil fullPathInDocument: [NSString stringWithFormat:@"%@/%@", kFolderImagePrefix, fileName]];
}

+ (NSString *)fullPathOfItemImage:(NSString *)fileName
{
    if([kItemImagePrefix hasSuffix:@"/"]) {
        return [StringUtil fullPathInDocument: [NSString stringWithFormat:@"%@%@", kItemImagePrefix, fileName]];
    }
    
    return [StringUtil fullPathInDocument: [NSString stringWithFormat:@"%@/%@", kItemImagePrefix, fileName]];
}

+ (NSString *)sizeToString:(unsigned long long)byte
{
    // < 1 KB, show Byte
    if(byte < 1000) {
        return [NSString stringWithFormat:@"%llu Byte", byte];
    }
    
    // < 1 MB, show KB
    if(byte < 1000*1000) {
        return [NSString stringWithFormat:@"%.01f KB", byte/1000.0f];
    }
    
    // < 950MB, show MB
    if(byte < 1000*1000*950) {
        return [NSString stringWithFormat:@"%.02f MB", byte/(1000.0f*1000.0f)];
    }
    
    // < 1TB, show GB
    if(byte < 10000*10000*10000) {
        return [NSString stringWithFormat:@"%.02f GB", byte/(1000.0f*1000.0f*1000.0f)];
    }
    
    return [NSString stringWithFormat:@"%llu Byte", byte];
}
@end
