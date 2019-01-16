//
//  DBFolder+isEmpty.m
//  ShopFolder
//
//  Created by Michael on 2012/10/14.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBFolder+isEmpty.h"
#import "CoreDataDatabase.h"

@implementation DBFolder (isEmpty)
- (BOOL)isEmpty
{
    if([self.name length] == 0) {
        return YES;
    }
    
    if([CoreDataDatabase totalItemsInFolder:self] == 0) {
        return YES;
    }
    
    return NO;
}
@end
