//
//  Barcode.h
//  ShopFolder
//
//  Created by Michael on 2011/09/23.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Barcode : NSObject {
    int ID;
    NSString *barcodeType;
    NSString *barcodeData;
}

@property (nonatomic, assign) int ID;
@property (nonatomic, strong) NSString *barcodeType;
@property (nonatomic, strong) NSString *barcodeData;

- (id)initWithType:(NSString *)type andData:(NSString *)data;

@end
