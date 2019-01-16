//
//  DBLocation.h
//  ShopFolder
//
//  Created by Michael on 2012/10/30.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DBFolderItem, DBShoppingItem;

@interface DBLocation : NSManagedObject

@property (nonatomic, retain) NSString * address;
@property (nonatomic) double altitude;
@property (nonatomic) BOOL hasGeoInfo;
@property (nonatomic) double horizontalAccuracy;
@property (nonatomic) double latitude;
@property (nonatomic) int32_t listPosition;
@property (nonatomic) double longitude;
@property (nonatomic, retain) NSString * name;
@property (nonatomic) double verticalAccuracy;
@property (nonatomic, retain) NSSet *folderItems;
@property (nonatomic, retain) NSSet *shoppingItems;
@end

@interface DBLocation (CoreDataGeneratedAccessors)

- (void)addFolderItemsObject:(DBFolderItem *)value;
- (void)removeFolderItemsObject:(DBFolderItem *)value;
- (void)addFolderItems:(NSSet *)values;
- (void)removeFolderItems:(NSSet *)values;

- (void)addShoppingItemsObject:(DBShoppingItem *)value;
- (void)removeShoppingItemsObject:(DBShoppingItem *)value;
- (void)addShoppingItems:(NSSet *)values;
- (void)removeShoppingItems:(NSSet *)values;

@end
