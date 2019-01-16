//
//  NSManagedObject+DeepCopy.m
//  ShopFolder
//
//  Created by Michael on 2012/09/16.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "NSManagedObject+DeepCopy.h"

@implementation NSManagedObject (DeepCopy)
- (BOOL)copyAttributesFrom:(NSManagedObject *)source
{
    if(source == nil) {
        return NO;
    }
    
    NSString *entityName = [[source entity] name];
    if(![entityName isEqualToString:[[self entity] name]]) {
        NSLog(@"Entity name is different, skip copying");
        return NO;
    }
    
    //loop through all attributes and assign then to the clone
    NSManagedObjectContext *context = (source.managedObjectContext) ? source.managedObjectContext : self.managedObjectContext;
    if(context == nil) {
        return NO;
    }
    
    NSDictionary *attributes = [[NSEntityDescription
                                 entityForName:entityName
                                 inManagedObjectContext:context] attributesByName];
    
    for (NSString *attr in attributes) {
        [self setValue:[source valueForKey:attr] forKey:attr];
    }
    
    return YES;
}

- (NSManagedObject *)deepCopyInContext:(NSManagedObjectContext *)context parentEntity:(NSString *)parentEntityName
{
    NSString *entityName = [[self entity] name];
    
    //create new object in data store
    NSManagedObject *cloned = [NSEntityDescription
                               insertNewObjectForEntityForName:entityName
                               inManagedObjectContext:context];
    
    //loop through all attributes and assign then to the clone
    NSDictionary *attributes = [[NSEntityDescription
                                 entityForName:entityName
                                 inManagedObjectContext:context] attributesByName];
    
    for (NSString *attr in attributes) {
        [cloned setValue:[self valueForKey:attr] forKey:attr];
    }
    
    //Loop through all relationships, and clone them.
    NSDictionary *relationships = [[NSEntityDescription
                                    entityForName:entityName
                                    inManagedObjectContext:context] relationshipsByName];
    for (NSString *relName in [relationships allKeys]){
        NSRelationshipDescription *rel = [relationships objectForKey:relName];
        if(rel == nil ||
           [[rel destinationEntity].name isEqualToString:parentEntityName])
        {
            continue;
        }
        
        if ([rel isToMany]) {
            //get a set of all objects in the relationship
            NSMutableSet *sourceSet = [self mutableSetValueForKey:relName];
            NSMutableSet *clonedSet = [cloned mutableSetValueForKey:relName];
            NSEnumerator *e = [sourceSet objectEnumerator];
            NSManagedObject *relatedObject;
            while ( relatedObject = [e nextObject]){
                //Clone it, and add clone to set
                NSManagedObject *clonedRelatedObject = [relatedObject deepCopyInContext:context
                                                                           parentEntity:[rel entity].name];
                [clonedSet addObject:clonedRelatedObject];
            }
        }else {
            [cloned setValue:[self valueForKey:relName] forKey:relName];
        }
        
    }
    
    return cloned;
}

- (NSManagedObject *)deepCopyInContext:(NSManagedObjectContext *)context
{
    return [self deepCopyInContext:context parentEntity:nil];
}
@end
