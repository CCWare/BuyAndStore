//
//  ClickOnFolderDelegate.h
//  ShopFolder
//
//  Created by Michael on 2011/10/11.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DBFolder.h"

@protocol ClickOnFolderDelegate <NSObject>
- (void) clickOnFolder: (DBFolder *)folder;
@end
