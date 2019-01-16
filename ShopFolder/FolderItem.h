//
//  FolderItem.h
//  ShopFolder
//
//  Created by Michael on 2011/09/23.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Barcode.h"
#import "Location.h"
#import "ShoppingItem.h"

@class ShoppingItem;
@interface FolderItem : NSObject {
    int ID;

    NSString *name;
    Barcode *barcode;
    UIImage *image;
    NSString *imagePath;

    int count;
    double price;
    NSDate *createTime;
    NSDate *expireTime;
    NSMutableArray *nearExpiredDays;

    int folderID;
    
    Location *location;
    NSString *note;
    
    BOOL isArchived;
    
    BOOL isInShoppingList;
}

@property (nonatomic, assign) int ID;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) NSString *imagePath;
@property (nonatomic, strong) Barcode *barcode;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) int count;
@property (nonatomic, assign) double price;
@property (nonatomic, strong) NSDate *createTime;
@property (nonatomic, strong) NSDate *expireTime;
@property (nonatomic, strong) NSMutableArray *nearExpiredDays;  //array of NSNumber
@property (nonatomic, assign) int folderID;
@property (nonatomic, strong) Location *location;
@property (nonatomic, strong) NSString *note;
@property (nonatomic, assign) BOOL isArchived;
@property (nonatomic, assign) BOOL isInShoppingList;

- (void) copyFrom:(FolderItem *)source;
- (id)initFromShoppingItem:(ShoppingItem *)shoppingItem;

- (BOOL)isExpired;
- (BOOL)isNearExpired;
- (NSMutableArray *)getNearExpireDates; //array of NSDates
- (BOOL)canSave;
@end
