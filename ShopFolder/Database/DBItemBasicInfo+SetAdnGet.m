//
//  DBItemBasicInfo+SetAdnGet.m
//  ShopFolder
//
//  Created by Michael on 2012/10/15.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBItemBasicInfo+SetAdnGet.h"

@implementation DBItemBasicInfo (SetAdnGet)

@dynamic barcode;

//==============================================================
//  [BEGIN] Barcode setter and getter
#pragma mark - Barcode setter and getter
//--------------------------------------------------------------
- (void)setBarcode:(Barcode *)barcode
{
    self.barcodeType = barcode.barcodeType;
    self.barcodeData = barcode.barcodeData;
}

- (Barcode *)barcode
{
    if([self.barcodeData length] == 0) {
        return nil;
    }
    
    return [[Barcode alloc] initWithType:self.barcodeType andData:self.barcodeData];
}
//--------------------------------------------------------------
//  [END] Barcode setter and getter
//==============================================================

//==============================================================
//  [BEGIN] Image setter and getters
#pragma mark - Image setter and getters
//--------------------------------------------------------------
- (UIImage *)getDisplayImage
{
    if(self.imageRawData == nil) {
        return nil;
    }
    
    if(self.displayImage == nil) {
        self.displayImage = [UIImage imageWithData:self.imageRawData];
    }
    
    return self.displayImage;
}

- (void)setUIImage:(UIImage *)image
{
    self.displayImage = image;
    self.imageRawData = (image) ? UIImageJPEGRepresentation(image, 0.75f) : nil;
}
//--------------------------------------------------------------
//  [END] Image setter and getters
//==============================================================

@end
