//
//  ListItemCell.h
//  ShopFolder
//
//  Created by Michael on 2011/11/14.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ListItemCell : UITableViewCell
{
    NSString *textBeforeEditing;
    BOOL isModified;
    NSString *textAfterModified;
}
@end
