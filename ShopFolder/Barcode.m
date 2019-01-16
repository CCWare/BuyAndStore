//
//  Barcode.m
//  ShopFolder
//
//  Created by Michael on 2011/09/23.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import "Barcode.h"


@implementation Barcode
@synthesize ID;
@synthesize barcodeData;
@synthesize barcodeType;

- (id)initWithType:(NSString *)type andData:(NSString *)data
{
    if((self = [super init])) {
        self.barcodeType = type;
        self.barcodeData = data;
    }

    return self;
}

- (id) copyWithZone:(NSZone *)zone
{
    Barcode *cloneObj = [[Barcode alloc] init];
    cloneObj.ID = self.ID;
    cloneObj.barcodeData = self.barcodeData;
    cloneObj.barcodeType = self.barcodeType;
    return cloneObj;
}



@end
