//
//  DBFolderItem+Validate.m
//  ShopFolder
//
//  Created by Michael on 2012/09/25.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBFolderItem+Validate.h"
#import "DBItemBasicInfo+Validate.h"

@implementation DBFolderItem (Validate)
- (BOOL)canSave
{
    if([self.basicInfo canSave] &&
       self.createTime > 0)
    {
        return YES;
    }
    
    return NO;
}
@end
