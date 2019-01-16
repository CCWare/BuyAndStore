//
//  DBFolder+Validate.m
//  ShopFolder
//
//  Created by Michael on 2012/09/25.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBFolder+Validate.h"
#import "CoreDataDatabase.h"

@implementation DBFolder (Validate)
- (BOOL)canSave
{
    return [self canSaveInContext:[CoreDataDatabase mainMOC]];
}

- (BOOL)canSaveInContext:(NSManagedObjectContext *)context
{
    if([self.name length] == 0) {
        return NO;
    }
    
    DBFolder *folder = [CoreDataDatabase getFolderByName:self.name inContext:context];
    if(folder != nil &&
       ![folder.objectID isEqual:self.objectID])
    {
        return NO;
    }
    
    return YES;
}
@end
