//
//  NSManagedObject+DeepCopy.h
//  ShopFolder
//
//  Created by Michael on 2012/09/16.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (DeepCopy)
- (BOOL)copyAttributesFrom:(NSManagedObject *)source;
- (NSManagedObject *)deepCopyInContext:(NSManagedObjectContext *)context;
- (NSManagedObject *)deepCopyInContext:(NSManagedObjectContext *)context parentEntity:(NSString *)parentEntityName;
@end
