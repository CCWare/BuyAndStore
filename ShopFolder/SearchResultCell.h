//
//  SearchResultCell.h
//  ShopFolder
//
//  Created by Michael on 2012/11/18.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "ItemDetailCell.h"

#define kSearchItemCellHeight   135.0f

@interface SearchResultCell : ItemDetailCell
{
    NSString *_folderName;
    CellLine *_folderLine;
}

@property (nonatomic, strong) NSString *folderName;

@end
