//
//  FlexibleHeightTableViewCell.h
//  ShopFolder
//
//  Created by Michael on 2012/1/8.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FlexibleHeightTableViewCell : UITableViewCell
{
    UIView *customizedView;
}

@property (nonatomic, strong) UIView *customizedView;
@end
