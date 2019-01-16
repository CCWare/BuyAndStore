//
//  BasicInfoCellLine.h
//  ShopFolder
//
//  Created by Michael on 2012/11/14.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

@class UnderLineView;
@interface CellLine : UIView
{
    UIImageView *_thumbImageView;
    UILabel *_titleLabel;
    UILabel *_contentLabel;
    
    UnderLineView *_underline;
    BOOL _showUnderline;
    
    BOOL _keepImageSpace;
}

@property (nonatomic, readonly) UIImageView *thumbImageView;
@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, readonly) UILabel *contentLabel;
@property (nonatomic, readonly) UIView *underline;

@property (nonatomic, assign) BOOL showUnderline;
@property (nonatomic, assign) BOOL keepImageSpace;

- (void)updateUI;

@end
