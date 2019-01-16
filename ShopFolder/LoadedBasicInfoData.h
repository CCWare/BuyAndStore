//
//  LoadedBasicInfoData.h
//  ShopFolder
//
//  Created by Michael on 2012/11/15.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PriceStatistics.h"
#import "Barcode.h"

@interface LoadedBasicInfoData : NSObject
{
    NSString *name;
    UIImage *image;
    int stock;
    PriceStatistics *priceStatistics;
    NSDate *nextExpiryDate;
    
    NSUInteger rxpiredCount;
    NSUInteger nearExpiredCount;
    
    BOOL isInShoppingList;
    BOOL isFavorite;
    
    Barcode *barcode;
    
    BOOL isFullyLoaded;
}

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, assign) int stock;
@property (nonatomic, strong) PriceStatistics *priceStatistics;
@property (nonatomic, strong) NSDate *nextExpiryDate;
@property (nonatomic, assign) NSUInteger expiredCount;
@property (nonatomic, assign) NSUInteger nearExpiredCount;
@property (nonatomic, assign) BOOL isInShoppingList;
@property (nonatomic, assign) BOOL isFavorite;
@property (nonatomic, strong) Barcode *barcode;

@property (nonatomic, assign) BOOL isFullyLoaded;

@end
