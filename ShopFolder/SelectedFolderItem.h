//
//  SelectedFolderItem.h
//  ShopFolder
//
//  Created by Michael on 2012/11/22.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "DBFolderItem.h"

@interface SelectedFolderItem : NSObject
{
    NSManagedObjectID *objectID;
    DBFolderItem *folderItem;
    int selectCount;
}

@property (nonatomic, strong) NSManagedObjectID *objectID;
@property (nonatomic, assign) int selectCount;
@property (nonatomic, strong) DBFolderItem *folderItem;

- (id)initWithFolderItem:(DBFolderItem *)folderItem;
@end
