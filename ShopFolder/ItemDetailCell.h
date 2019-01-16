//
//  ItemDetailCell.h
//  ShopFolder
//
//  Created by Michael on 2012/11/17.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CellLine.h"
#import "DBFolderItem.h"
#import "OutlineLabel.h"

#define kItemDetailCellHeight   120.0f

#define kCheckBoxViewWidth      50.0f

@protocol ItemDetailCellDelegate;

@interface ItemDetailCell : UITableViewCell
{
    DBFolderItem *_folderItem;
    
    UIView *_viewHolder;
    CellLine *_countLine;
    CellLine *_priceLine;
    CellLine *_locationLine;
    CellLine *_dateLine;

    BOOL _showContent;
    
    BOOL _isChecked;
    UIImageView *_checkImageView;
    
    UISlider *_countSlider;
    OutlineLabel *_countLabel;
    BOOL _showSelectIndicator;
    int _selectCount;
}

@property (nonatomic, strong) DBFolderItem *folderItem;
@property (nonatomic, assign) BOOL showContent;
@property (nonatomic, assign) BOOL isChecked;

@property (nonatomic, assign) BOOL showSelectIndicator;
@property (nonatomic, assign) int maxCount;
@property (nonatomic, assign) int selectCount;

@property (nonatomic, weak) id<ItemDetailCellDelegate> delegate;

- (void)showSelectIndicator:(BOOL)show animated:(BOOL)animate;

- (void)updateUI;
@end

@protocol ItemDetailCellDelegate
- (void)cellCheckStatusChanged:(BOOL)checked from:(ItemDetailCell *)sender;
- (void)cellSelectCountChanged:(int)value from:(ItemDetailCell *)sender;
@end
