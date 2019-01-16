//
//  DBFolder.h
//  ShopFolder
//
//  Created by Michael on 2012/10/30.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DBFolderItem;

@interface DBFolder : NSManagedObject

@property (nonatomic, retain) id displayImage;
@property (nonatomic, retain) NSData * imageRawData;
@property (nonatomic, retain) NSString * name;
@property (nonatomic) int32_t number;
@property (nonatomic) int32_t page;
@property (nonatomic, retain) NSString * password;
@property (nonatomic) BOOL useItemImageAsCover;
@property (nonatomic, retain) NSSet *items;
@end

@interface DBFolder (CoreDataGeneratedAccessors)

- (void)addItemsObject:(DBFolderItem *)value;
- (void)removeItemsObject:(DBFolderItem *)value;
- (void)addItems:(NSSet *)values;
- (void)removeItems:(NSSet *)values;

@end
