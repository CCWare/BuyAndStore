//
//  FolderView.h
//  ShopFolder
//
//  Created by Michael on 2011/11/04.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FolderImageView.h"
#import "MKNumberBadgeView.h"
#import "DeleteBadgeView.h"
#import "OutlineLabel.h"

@interface FolderView : UIView
{
    FolderImageView *imageView;
    OutlineLabel *label;
    BOOL editing;
    BOOL focused;
    BOOL locked;
    
    MKNumberBadgeView *expiredBadge;
    MKNumberBadgeView *nearExpiredBadge;
    
    CGFloat folderOffsetX;
    UIImageView *lockImageView;
    DeleteBadgeView *deleteBadge;
@private
    CGAffineTransform _setFocusTransform;
    CGFloat badgeRightEnd;
}

@property (nonatomic, strong) FolderImageView *imageView;
@property (nonatomic, strong) OutlineLabel *label;
@property (nonatomic, assign) BOOL editing;
@property (nonatomic, assign) BOOL focused;
@property (nonatomic, assign) BOOL locked;
@property (nonatomic, assign) NSInteger expiredBadgeNumber;
@property (nonatomic, assign) NSInteger nearExpiredBadgeNumber;
@property (nonatomic, readonly) DeleteBadgeView *deleteBadge;

- (void)setFocused:(BOOL)isFocues animated:(BOOL)animated;
- (void)reset;
@end
