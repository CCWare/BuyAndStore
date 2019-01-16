//
//  ShoppingItem.h
//  ShopFolder
//
//  Created by Chung-Chih Tsai on 2012/05/10.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Barcode.h"
#import "FolderItem.h"

@class FolderItem;
@interface ShoppingItem : NSObject
{
    int _ID;
    NSString *_itemName;
    NSString *_itemImagePath;
    UIImage *_itemImage;
    
    int _originalFolderID;
    int _shoppingCount;
    int _listPosition;
    
    BOOL _hasBought;
    
    //Not saved in database
    float minPrice;
    float avgPrice;
    float maxPrice;
    float _price;
}

@property (nonatomic, assign) int ID;
@property (nonatomic, strong) NSString *itemName;
@property (nonatomic, strong) NSString *itemImagePath;
@property (nonatomic, strong) UIImage *itemImage;
@property (nonatomic, assign) int originalFolderID;
@property (nonatomic, assign) int shoppingCount;
@property (nonatomic, assign) int listPosition;
@property (nonatomic, assign) BOOL hasBought;
@property (nonatomic, assign) float price;

//Not saved in database
@property (nonatomic, assign) float minPrice;
@property (nonatomic, assign) float avgPrice;
@property (nonatomic, assign) float maxPrice;

- (id)initFromFolderItem:(FolderItem *)item;
- (void) copyFrom:(ShoppingItem *)source;
- (BOOL)canSave;
@end
