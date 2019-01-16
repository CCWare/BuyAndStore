//
//  Folder.m
//  ShopFolder
//
//  Created by Michael on 2011/09/23.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import "Folder.h"
#import "Database.h"

@implementation Folder

@synthesize ID;
@synthesize name;
@synthesize page;
@synthesize number;
@synthesize color;
@synthesize imagePath;
@synthesize lockPhrease;

@synthesize image;

- (id)copyWithZone: (NSZone *)zone
{
    Folder *cloneFolder = [[[self class] allocWithZone:zone] init];
    
    cloneFolder.ID = self.ID;
    cloneFolder.name = self.name;
    cloneFolder.page = self.page;
    cloneFolder.number = self.number;
    cloneFolder.color = [[UIColor allocWithZone:zone] initWithCGColor:self.color.CGColor];
    cloneFolder.imagePath = self.imagePath;
    cloneFolder.lockPhrease = self.lockPhrease;
    cloneFolder.image = self.image;
    
    return cloneFolder;
}

- (void) copyFrom:(Folder *)source
{
    self.ID = source.ID;
    self.name = source.name;
    self.image = source.image;
    self.imagePath = source.imagePath;
    self.page = source.page;
    self.number = source.number;
    self.color = [source.color copy];
    self.lockPhrease = source.lockPhrease;
}

- (void) resetData
{
    self.ID = 0;
    self.name = nil;
    self.color = kDefaultColor;
    self.imagePath = nil;
    self.lockPhrease = nil;
    self.image = nil;
}


- (BOOL) isUnused
{
    if(self.ID == 0 ||
       [self.name length] == 0)
    {
        return YES;
    }
    
    return NO;
}

- (BOOL) isEmpty
{
    if([self isUnused] ||
       [[Database sharedSingleton] totalItemsInFolder:self] == 0)
    {
        return YES;
    }
    
    return NO;
}

- (BOOL)canSave
{
    return ([self.name length] > 0);
}

@end
