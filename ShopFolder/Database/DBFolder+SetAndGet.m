//
//  DBFolder+SetAndGet.m
//  ShopFolder
//
//  Created by Michael on 2012/10/15.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBFolder+SetAndGet.h"

@implementation DBFolder (SetAndGet)
- (void)setImage:(UIImage *)image
{
    if(image == nil) {
        self.imageRawData = nil;
        self.displayImage = nil;
    } else {
        self.displayImage = image;
        self.imageRawData = UIImageJPEGRepresentation(image, 0.75f);
    }
}

- (UIImage *)getDisplayImage
{
    if(self.imageRawData == nil) {
        return nil;
    }

    @synchronized(self) {
        if(self.displayImage == nil) {
            self.displayImage = [UIImage imageWithData:self.imageRawData];
        }
    }
    
    return self.displayImage;
}
@end
