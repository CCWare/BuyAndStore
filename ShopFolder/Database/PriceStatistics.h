//
//  PriceStatistics.h
//  ShopFolder
//
//  Created by Michael on 2012/11/08.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PriceStatistics : NSObject
{
    double totalPrice;
    uint countOfPrices;
    double minPrice;
    double maxPrice;
    
    NSString *minPriceLocationName;
    NSString *maxPriceLocationName;
}

@property (nonatomic, assign) double totalPrice;
@property (nonatomic, assign) uint countOfPrices;
@property (nonatomic, assign) double minPrice;
@property (nonatomic, assign) double maxPrice;
@property (nonatomic, readonly) double avgPrice;

@property (nonatomic, strong) NSString *minPriceLocationName;
@property (nonatomic, strong) NSString *maxPriceLocationName;
@end
