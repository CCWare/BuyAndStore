//
//  DBFolderItem+expiryOperations.h
//  ShopFolder
//
//  Created by Michael on 2012/09/19.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBFolderItem.h"

@interface DBFolderItem (expiryOperations)
- (BOOL)isExpiredIgnoreArchive:(BOOL)ignoreArchive ignoreCount:(BOOL)ignoreCount;
- (BOOL)isExpired;
- (BOOL)isNearExpiredIgnoreArchive:(BOOL)ignoreArchive ignoreCount:(BOOL)ignoreCount;
- (BOOL)isNearExpired;
@end
