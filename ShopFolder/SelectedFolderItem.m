//
//  SelectedFolderItem.m
//  ShopFolder
//
//  Created by Michael on 2012/11/22.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "SelectedFolderItem.h"
#import "CoreDataDatabase.h"

@implementation SelectedFolderItem
@synthesize objectID;
@synthesize selectCount;
@synthesize folderItem;

- (id)initWithFolderItem:(DBFolderItem *)item
{
    if((self = [super init])) {
        self.objectID = item.objectID;
        self.selectCount = item.count;
        self.folderItem = item;
    }
    
    return self;
}

@end
