//
//  DBItemBasicInfo+SetAdnGet.h
//  ShopFolder
//
//  Created by Michael on 2012/10/15.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBItemBasicInfo.h"
#import "Barcode.h"

@interface DBItemBasicInfo (SetAdnGet)

//Barcode
@property (nonatomic) Barcode *barcode;

//Image
- (UIImage *)getDisplayImage;
- (void)setUIImage:(UIImage *)image;
@end
