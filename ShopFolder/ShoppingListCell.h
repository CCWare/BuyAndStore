//
//  ShoppingListCell.h
//  ShopFolder
//
//  Created by Chung-Chih Tsai on 2012/05/15.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DBItemBasicInfo.h"
#import "DBShoppingItem.h"
#import "PriceStatistics.h"
#import "CellLine.h"
#import "EditImageView.h"
#import "Barcode.h"
#import <QuartzCore/QuartzCore.h>

#define kShoppingItemCellHeight     150.0f
#define kSpaceToImage               4.0f

@protocol ShoppingListCellDelegate;

@interface ShoppingListCell : UITableViewCell
{
    NSString *_name;
    Barcode *_barcode;
    int _stock;
    int _count;
    PriceStatistics *_priceStatistics;
    float _price;
    
    UIView *_viewHolder;
    CellLine *_nameLine;            //At most 2 lines
    CellLine *_stockLine;           //With stock image
    CellLine *_countLine;           //(Optional)Count to buy, set keepImageSpace to YES
    CellLine *_priceStatisticsLine; //(Optional)At most 2 lines
    CellLine *_priceLine;           //(Optional)Price to buy
    
    BOOL _showContent;
    EditImageView *_thumbImageView;
    
    BOOL _hasBought;
    
    CAGradientLayer *_backgroundGradient;
}

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) Barcode *barcode;
@property (nonatomic, strong) UIImage *thumbImage;
@property (nonatomic, assign) int stock;
@property (nonatomic, assign) int count;
@property (nonatomic, strong) PriceStatistics *priceStatistics;
@property (nonatomic, assign) float price;
@property (nonatomic, assign) BOOL hasBought;

@property (nonatomic, readonly) CGRect imageViewFrame;  //For enlarging in list

@property (nonatomic, weak) id<ShoppingListCellDelegate> delegate;

- (void)updateUI;
@end

@protocol ShoppingListCellDelegate
- (void)boughtStatusChanged:(ShoppingListCell *)cell bought:(BOOL)hasBought;
- (void)imageTouched:(ShoppingListCell *)cell;
@end