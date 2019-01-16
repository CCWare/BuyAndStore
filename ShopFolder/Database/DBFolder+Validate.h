//
//  DBFolder+Validate.h
//  ShopFolder
//
//  Created by Michael on 2012/09/25.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBFolder.h"

@interface DBFolder (Validate)
- (BOOL)canSave;
- (BOOL)canSaveInContext:(NSManagedObjectContext *)context;
@end
