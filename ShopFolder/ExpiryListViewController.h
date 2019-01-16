//
//  ExpiryListViewController.h
//  ShopFolder
//
//  Created by Michael on 2012/10/31.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ExpiryItemCell.h"
#import "OutlineLabel.h"

#ifdef _LITE_
#import "InAppPurchaseViewController.h"
#endif

@protocol ExpiryListViewControllerDelegate;

@interface ExpiryListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate,
                                                        ExpiryItemCellDelegate, UIAlertViewDelegate
#ifdef _LITE_
                                                        ,InAppPurchaseViewControllerDelegate
#endif
>
{
    NSMutableArray *_itemsExpired;
    NSMutableArray *_itemsExpireToday;
    NSMutableArray *_itemsNearExpired;
    
    //For large image preview
    UIImageView *_largeImageView;
    UIControl *_largeImageBackgroundView;
    UIImage *_imageForNoImageLabel;
    UIView *_imageLabelBackgroundView;
    UILabel *_imageLabel;
    OutlineLabel *_tapToDismissLabel;
    CGRect _imageAnimateFromFrame;
    UIImage *_emptyImage;
    
    UIFont *_headerLabelFont;
    CGFloat _headerHeight;

#ifdef _LITE_
    UIAlertView *_liteLimitAlert;
#endif
}

@property (strong, nonatomic) IBOutlet UITableView *table;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *closeButton;
@property (nonatomic, weak) id<ExpiryListViewControllerDelegate> delegate;

@end

@protocol ExpiryListViewControllerDelegate
- (void)expiryListShouldDismiss;
@end