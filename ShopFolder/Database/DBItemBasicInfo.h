//
//  DBItemBasicInfo.h
//  ShopFolder
//
//  Created by Michael on 2012/12/04.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DBFolderItem, DBShoppingItem;

@interface DBItemBasicInfo : NSManagedObject

@property (nonatomic, retain) NSString * barcodeData;
@property (nonatomic, retain) NSString * barcodeType;
@property (nonatomic, retain) id displayImage;
@property (nonatomic, retain) NSData * imageRawData;
@property (nonatomic) BOOL isFavorite;
@property (nonatomic, retain) NSString * name;
@property (nonatomic) int32_t safeStockCount;
@property (nonatomic) NSTimeInterval lastUpdateTime;
@property (nonatomic, retain) NSSet *folderItems;
@property (nonatomic, retain) DBShoppingItem *shoppingItem;
@end

@interface DBItemBasicInfo (CoreDataGeneratedAccessors)

- (void)addFolderItemsObject:(DBFolderItem *)value;
- (void)removeFolderItemsObject:(DBFolderItem *)value;
- (void)addFolderItems:(NSSet *)values;
- (void)removeFolderItems:(NSSet *)values;

@end
