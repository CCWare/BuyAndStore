//
//  DBNotifyDate.h
//  ShopFolder
//
//  Created by Michael on 2012/10/30.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DBFolderItem;

@interface DBNotifyDate : NSManagedObject

@property (nonatomic) NSTimeInterval date;
@property (nonatomic, retain) NSSet *expireItems;
@property (nonatomic, retain) NSSet *nearExpireItems;
@end

@interface DBNotifyDate (CoreDataGeneratedAccessors)

- (void)addExpireItemsObject:(DBFolderItem *)value;
- (void)removeExpireItemsObject:(DBFolderItem *)value;
- (void)addExpireItems:(NSSet *)values;
- (void)removeExpireItems:(NSSet *)values;

- (void)addNearExpireItemsObject:(DBFolderItem *)value;
- (void)removeNearExpireItemsObject:(DBFolderItem *)value;
- (void)addNearExpireItems:(NSSet *)values;
- (void)removeNearExpireItems:(NSSet *)values;

@end
