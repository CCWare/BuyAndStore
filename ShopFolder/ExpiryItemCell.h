//
//  ExpiryItemCell.h
//  ShopFolder
//
//  Created by Michael on 2012/11/30.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "CellLine.h"
#import "EditImageView.h"
#import "Barcode.h"

#define kExpiryItemCellHeight   120.0f
#define kSpaceToImage           4.0f

@protocol ExpiryItemCellDelegate;

@interface ExpiryItemCell : UITableViewCell
{
    NSString *_name;
    Barcode *_barcode;
    float _price;
    NSDate *_expiryDate;
    int _stock;
    
    UIView *_viewHolder;
    CellLine *_nameLine;        //Name or barcode, at most 2 lines
    CellLine *_countLine;       //1 line
    CellLine *_priceLine;       //1 line
    CellLine *_expiryDateLine;  //1 line
    
    UIButton *_cartButton;
    UIButton *_favoriteButton;
    EditImageView *_thumbImageView;
    CGRect _imageViewFrame;
    
    UIButton *_archiveButton;
    CGFloat _archiveButtonSize;
}

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) Barcode *barcode;
@property (nonatomic, strong) UIImage *thumbImage;
@property (nonatomic, assign) int count;
@property (nonatomic, strong) NSDate *expiryDate;

@property (nonatomic, readonly) CGRect imageViewFrame;  //For enlarging in list

@property (nonatomic, weak) id<ExpiryItemCellDelegate> delegate;

- (void)setIsInShoppingList:(BOOL)isInShoppingList;
- (void)setIsFavorite:(BOOL)isFavorite;
- (void)setPrice:(float)price withCurrencyCode:(NSString *)currencyCode;

- (void)updateUI;
@end

@protocol ExpiryItemCellDelegate
- (void)imageTouched:(id)sender;

@optional
- (void)cartButtonPressed:(id)sender;
- (void)favoriteButtonPressed:(id)sender;
- (void)archiveButtonPressed:(id)sender;
@end
