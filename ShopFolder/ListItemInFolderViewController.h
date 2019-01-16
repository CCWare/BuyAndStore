//
//  ListItemInFolderViewController.h
//  ShopFolder
//
//  Created by Michael on 2012/11/19.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "FolderItemListViewController.h"
#import "EditItemViewController.h"

@interface ListItemInFolderViewController : FolderItemListViewController
{
    DBFolder *_folder;
    BOOL _isCreatingNewItem;
}

- (id)initWithBasicInfo:(DBItemBasicInfo *)basicInfo
                 folder:(DBFolder *)folder
            preloadData:(LoadedBasicInfoData *)preloadData;
@end
