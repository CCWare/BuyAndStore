//
//  BasicInfoCell.h
//  ShopFolder
//
//  Created by Michael on 2012/11/09.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DBItemBasicInfo.h"
#import "PriceStatistics.h"
#import "MKNumberBadgeView.h"
#import "CellLine.h"
#import "EditImageView.h"
#import "LoadedBasicInfoData.h"

#define kBasicInfoCellHeight    120.0f
#define kSpaceToImage           4.0f

@protocol BasicInfoCellDelegate;

@interface BasicInfoCell : UITableViewCell
{
    NSString *_name;
    PriceStatistics *_priceStatistics;
    NSDate *_nextExpiryDate;
    int _stock;
    
    UIView *_viewHolder;
    CellLine *_nameLine;    //Name, at most 2 lines
    CellLine *_stockLine;   //1 line
    CellLine *_priceStatisticsLine;   //Price statistics, 2 lines
    CellLine *_nextExpiryDateLine;  //1 line
    CGFloat _lineWidth;
    
    UIButton *_cartButton;
    UIButton *_favoriteButton;
    UIButton *_editButton;
    EditImageView *_thumbImageView;
    CGRect _imageViewFrame;
    UILabel *_loadingImageLabel;
    
    MKNumberBadgeView *_expiredBadge;
    MKNumberBadgeView *_nearExpiredBadge;
    
    //Those are set to NO in shopping list
    BOOL _showNextExpiredTime;
    BOOL _showExpiryInformation;
    BOOL _showContent;
    BOOL _hideEditButton;
}

- (void)updateFromLoadedBasicInfo:(LoadedBasicInfoData *)info animated:(BOOL)animate;

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) UIImage *thumbImage;
@property (nonatomic, assign) int stock;
@property (nonatomic, strong) PriceStatistics *priceStatistics;
@property (nonatomic, strong) NSDate *nextExpiryDate;
@property (nonatomic, assign) NSUInteger expiredCount;
@property (nonatomic, assign) NSUInteger nearExpiredCount;

@property (nonatomic, assign) BOOL showNextExpiredTime;
@property (nonatomic, assign) BOOL showExpiryInformation;
@property (nonatomic, assign) BOOL showContent;
@property (nonatomic, assign) BOOL hideEditButton;

@property (nonatomic, readonly) CGRect imageViewFrame;  //For enlarging in list

@property (nonatomic, weak) id<BasicInfoCellDelegate> delegate;

- (void)setIsInShoppingList:(BOOL)isInShoppingList;
- (void)setIsFavorite:(BOOL)isFavorite;

- (void)showBadgeAnimatedWithDuration:(NSTimeInterval)time afterDelay:(NSTimeInterval)delay;
- (void)hideBadgeAnimatedWithDuration:(NSTimeInterval)time afterDelay:(NSTimeInterval)delay;

- (void)updateUI;
@end

@protocol BasicInfoCellDelegate
- (void)imageTouched:(BasicInfoCell *)sender;
- (void)editButtonPressed:(BasicInfoCell *)sneder;

@optional
- (void)cartButtonPressed:(BasicInfoCell *)sender;
- (void)favoriteButtonPressed:(BasicInfoCell *)sender;
@end