//
//  FavoriteListViewController.h
//  ShopFolder
//
//  Created by Michael on 2012/12/03.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "BasicInfoListViewController.h"

@protocol FavoriteListViewControllerDelegate;

@interface FavoriteListViewController : BasicInfoListViewController
{
    
}
@property (nonatomic, weak) id<FavoriteListViewControllerDelegate> delegate;
@end

@protocol FavoriteListViewControllerDelegate
- (void)didSelectItemBasicInfo:(DBItemBasicInfo *)basicInfo;
- (void)shouldDismissFavoriteList;
@end