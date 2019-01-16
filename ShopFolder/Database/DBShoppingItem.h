//
//  DBShoppingItem.h
//  ShopFolder
//
//  Created by Michael on 2012/11/16.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DBItemBasicInfo, DBLocation;

@interface DBShoppingItem : NSManagedObject

@property (nonatomic) int32_t count;
@property (nonatomic, retain) NSString * currencyCode;
@property (nonatomic) BOOL hasBought;
@property (nonatomic) int32_t listPosition;
@property (nonatomic) float price;
@property (nonatomic, retain) DBItemBasicInfo *basicInfo;
@property (nonatomic, retain) DBLocation *location;

@end
