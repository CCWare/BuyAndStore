//
//  DBFolderItem.h
//  ShopFolder
//
//  Created by Michael on 2012/11/08.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DBFolder, DBItemBasicInfo, DBLocation, DBNotifyDate;

@interface DBFolderItem : NSManagedObject

@property (nonatomic, retain) NSString * changeLog;
@property (nonatomic) int32_t count;
@property (nonatomic) NSTimeInterval createTime;
@property (nonatomic, retain) NSString * currencyCode;
@property (nonatomic) BOOL isArchived;
@property (nonatomic) NSTimeInterval lastUpdateTime;
@property (nonatomic, retain) NSString * note;
@property (nonatomic) float price;
@property (nonatomic) BOOL isUserCreated;
@property (nonatomic, retain) DBItemBasicInfo *basicInfo;
@property (nonatomic, retain) DBNotifyDate *expiryDate;
@property (nonatomic, retain) DBFolder *folder;
@property (nonatomic, retain) DBLocation *location;
@property (nonatomic, retain) NSSet *nearExpiryDates;
@end

@interface DBFolderItem (CoreDataGeneratedAccessors)

- (void)addNearExpiryDatesObject:(DBNotifyDate *)value;
- (void)removeNearExpiryDatesObject:(DBNotifyDate *)value;
- (void)addNearExpiryDates:(NSSet *)values;
- (void)removeNearExpiryDates:(NSSet *)values;

@end
