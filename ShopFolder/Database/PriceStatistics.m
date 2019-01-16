//
//  PriceStatistics.m
//  ShopFolder
//
//  Created by Michael on 2012/11/08.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "PriceStatistics.h"

@implementation PriceStatistics
@synthesize totalPrice;
@synthesize countOfPrices;
@synthesize minPrice;
@synthesize maxPrice;
@dynamic avgPrice;

@synthesize minPriceLocationName;
@synthesize maxPriceLocationName;

- (id)init
{
    if((self = [super init])) {
        minPrice = INT_MAX;
        maxPrice = -INT_MAX;
        totalPrice = 0.0f;
        countOfPrices = 0;
    }
    
    return self;
}

- (double)avgPrice
{
    if(countOfPrices == 0) {
        return 0.0f;
    }
    
    return totalPrice/countOfPrices;
}
@end
