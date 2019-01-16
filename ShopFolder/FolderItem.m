//
//  FolderItem.m
//  ShopFolder
//
//  Created by Michael on 2011/09/23.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import "FolderItem.h"
#import "TimeUtil.h"
#import "PreferenceConstant.h"
#import "Database.h"

@implementation FolderItem

@synthesize ID;
@synthesize image;
@synthesize imagePath;
@synthesize barcode;
@synthesize name;
@synthesize count;
@synthesize price;
@synthesize createTime;
@synthesize expireTime;
@synthesize nearExpiredDays;
@synthesize folderID;
@synthesize location;
@synthesize note;
@synthesize isArchived;
@synthesize isInShoppingList;

- (id)initFromShoppingItem:(ShoppingItem *)shoppingItem
{
    if((self = [super init])) {
        self.name = shoppingItem.itemName;
        self.imagePath = shoppingItem.itemImagePath;
        self.image = shoppingItem.itemImage;
        self.barcode = [[Database sharedSingleton] getBarcodeOfShoppingItem:shoppingItem];
        self.count = shoppingItem.shoppingCount;
        self.createTime = [TimeUtil today];
        self.folderID = shoppingItem.originalFolderID;
        self.price = shoppingItem.price;
    }
    
    return self;
}

- (id)copyWithZone: (NSZone *)zone
{
    FolderItem *cloneItem = [[[self class] allocWithZone:zone] init];
    cloneItem.ID = self.ID;
    cloneItem.image = self.image;
    cloneItem.imagePath = self.imagePath;
    cloneItem.barcode = self.barcode;
    cloneItem.name = self.name;
    cloneItem.count = self.count;
    cloneItem.price = self.price;
    cloneItem.createTime = self.createTime;
    cloneItem.expireTime = self.expireTime;
    if(cloneItem.nearExpiredDays == nil) {
        cloneItem.nearExpiredDays = [NSMutableArray array];
    }
    [cloneItem.nearExpiredDays removeAllObjects];
    [cloneItem.nearExpiredDays addObjectsFromArray:self.nearExpiredDays];
    cloneItem.folderID = self.folderID;
    cloneItem.location = self.location;
    cloneItem.note = self.note;
    cloneItem.isArchived = self.isArchived;
    cloneItem.isInShoppingList = self.isInShoppingList;
    
    return cloneItem;
}

- (void) copyFrom:(FolderItem *)source
{
    self.ID = source.ID;
    self.image = source.image;
    self.imagePath = source.imagePath;
    self.barcode = source.barcode;
    self.name = source.name;
    self.count = source.count;
    self.price = source.price;
    self.createTime = source.createTime;
    self.expireTime = source.expireTime;
    if(self.nearExpiredDays == nil) {
        self.nearExpiredDays = [NSMutableArray array];
    }
    [self.nearExpiredDays removeAllObjects];
    [self.nearExpiredDays addObjectsFromArray:source.nearExpiredDays];
    self.folderID = source.folderID;
    self.location = source.location;
    self.note = source.note;
    self.isArchived = source.isArchived;
    self.isInShoppingList = source.isInShoppingList;
}

- (BOOL)isExpired
{
    return (count > 0 && [TimeUtil isExpired:self.expireTime]);
}

- (BOOL) isNearExpired
{
    if(count == 0) {
        return NO;
    }

    [self.nearExpiredDays sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [(NSNumber *)obj1 compare:(NSNumber *)obj2];
    }];
    
    NSNumber *biggestDay = [self.nearExpiredDays lastObject];
    return (![self isExpired] && [TimeUtil isNearExpired:self.expireTime nearExpiredDays:[biggestDay intValue]]);
}

- (NSMutableArray *)getNearExpireDates
{
    NSMutableArray *dates = [NSMutableArray array];
    for(NSNumber *day in self.nearExpiredDays) {
        [dates addObject:[TimeUtil dateFromDate:self.expireTime inDays:[day intValue]]];
    }
    return dates;
}

- (BOOL)canSave
{
    if([self.name length] > 0 ||
       self.image != nil ||
       self.barcode != nil)
    {
        return YES;
    }
    
    return NO;
}

@end
