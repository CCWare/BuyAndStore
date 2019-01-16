//
//  ShoppingItem.m
//  ShopFolder
//
//  Created by Chung-Chih Tsai on 2012/05/10.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "ShoppingItem.h"
#import "Database.h"

@implementation ShoppingItem
@synthesize ID=_ID;
@synthesize itemName=_itemName;
@synthesize itemImagePath=_itemImagePath;
@synthesize itemImage=_itemImage;
@synthesize originalFolderID=_originalFolderID;
@synthesize shoppingCount=_shoppingCount;
@synthesize listPosition=_listPosition;
@synthesize hasBought=_hasBought;
@synthesize price=_price;

//Not saved in database
@synthesize minPrice;
@synthesize avgPrice;
@synthesize maxPrice;

- (void)_init
{
    self.shoppingCount = 1;
    self.listPosition = [[Database sharedSingleton] totalShoppingItems];
}

- (id)init
{
    if((self = [super init])) {
        [self _init];
    }
    
    return self;
}

- (id)initFromFolderItem:(FolderItem *)item
{
    if((self = [super init])) {
        self.itemName = item.name;
        self.itemImagePath = item.imagePath;
        self.itemImage = item.image;
        self.originalFolderID = item.folderID;
        self.hasBought = NO;
//        self.price = item.price;
        [self _init];
    }
    
    return self;
}

- (id)copyWithZone: (NSZone *)zone
{
    ShoppingItem* cloneItem = [[[self class] allocWithZone:zone] init];
    cloneItem.ID = self.ID;
    cloneItem.itemImage = self.itemImage;
    cloneItem.itemImagePath = self.itemImagePath;
    cloneItem.itemName = self.itemName;
    cloneItem.originalFolderID = self.originalFolderID;
    cloneItem.shoppingCount = self.shoppingCount;
    cloneItem.hasBought = self.hasBought;
    cloneItem.listPosition = self.listPosition;
    cloneItem.price = self.price;
    
    return cloneItem;
}

- (void) copyFrom:(ShoppingItem *)source
{
    self.ID = source.ID;
    self.itemImage = source.itemImage;
    self.itemImagePath = source.itemImagePath;
    self.itemName = source.itemName;
    self.originalFolderID = source.originalFolderID;
    self.shoppingCount = source.shoppingCount;
    self.hasBought = source.hasBought;
    self.listPosition = source.listPosition;
    self.price = source.price;
}

- (BOOL)canSave
{
    if([self.itemName length] > 0 ||
       self.itemImage != nil)
    {
        return YES;
    }
    
    return NO;
}
@end
