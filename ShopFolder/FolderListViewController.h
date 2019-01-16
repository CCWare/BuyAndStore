//
//  FolderListViewController.h
//  ShopFolder
//
//  Created by Michael on 2012/11/15.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "BasicInfoListViewController.h"
#import "DBFolder.h"

@interface FolderListViewController : BasicInfoListViewController
{
    DBFolder *_folder;
}
- (id)initWithFolder:(DBFolder *)foler;
@end
