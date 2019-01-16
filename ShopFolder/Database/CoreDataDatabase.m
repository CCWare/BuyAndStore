//
//  CoreDataDatabase.m
//  ShopFolder
//
//  Created by Michael on 2012/09/15.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "CoreDataDatabase.h"
#import <CoreData/CoreData.h>
#import "FlurryAnalytics.h"
#import "TimeUtil.h"
#import "NSManagedObject+DeepCopy.h"
#import "StringUtil.h"
#import "VersionCompare.h"
#import "DBFolderItem+expiryOperations.h"
#import "DBFolderItem+ChangeLog.h"
#import "Database.h"    //For upgrading DB
#import "DBItemBasicInfo+SetAdnGet.h"
#import "UIApplication+BadgeUpdate.h"
#import "ExpiryNotificationScheduler.h"

#define kImpotedLocationKey     @"ImportedLocations"  //Same as in Defaults.plist

#define kFolderEntityName           @"DBFolder"
#define kFolderItemEntityName       @"DBFolderItem"
#define kItemBasicInfoEntityName    @"DBItemBasicInfo"
#define kShoppingItemEntityName     @"DBShoppingItem"
#define kLocationEntityName         @"DBLocation"
#define kNotifyDateEntityName       @"DBNotifyDate"

static NSManagedObjectContext *_mainMOC = nil;    //get from main thread
static NSPersistentStoreCoordinator *_persistentStore = nil;

@interface CoreDataDatabase ()
+ (void)_receiveApplicationWillResignActiveNotification:(NSNotification *)notif;
+ (void)_receiveApplicationDidBecomeActiveNotification:(NSNotification *)notif;
@end

@implementation CoreDataDatabase

+ (BOOL)needToUpgradeDatabase
{
    NSString *oldDatatbase = [StringUtil fullPathInDocument:kDBName];
    if(![[NSFileManager defaultManager] fileExistsAtPath:oldDatatbase]) {
        return NO;
    }
    
    return [[Database sharedSingleton] needToUpgradeDatabase];
}

+ (BOOL)upgradeDatabase
{
    NSString *oldDatatbase = [StringUtil fullPathInDocument:kDBName];
    if(![[NSFileManager defaultManager] fileExistsAtPath:oldDatatbase]) {
        return YES;
    }
    
    [ExpiryNotificationScheduler disableReceivingNotifications];
    BOOL success = [[Database sharedSingleton] upgradeDatabase];
    if(success) {
        [ExpiryNotificationScheduler rescheduleAllNotifications];
    }
    [ExpiryNotificationScheduler enableReceivingNotifications];
    
    return success;
}

+ (NSURL *)databaseURL
{
    NSURL *libraryPath = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [libraryPath URLByAppendingPathComponent:kDataBaseFileName];
    return storeURL;
}

+ (NSURL *)externalBlobURL
{
    NSURL *libraryPath = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [libraryPath URLByAppendingPathComponent:kDatabaseExtStorage];
    return storeURL;
}

+ (NSManagedObjectContext *)getContextForCurrentThread
{
    if([NSThread isMainThread] &&
       _mainMOC != nil)
    {
        return _mainMOC;
    }
    
    if(_persistentStore == nil) {
        _persistentStore = [self persistentStoreCoordinator];
    }
//    NSPersistentStoreCoordinator *persistentStore = [self persistentStoreCoordinator];
    NSManagedObjectContext *managedObjectContext = [NSManagedObjectContext new];
    [managedObjectContext setPersistentStoreCoordinator:_persistentStore];
    
    return managedObjectContext;
}

+ (NSManagedObjectContext *)mainMOC
{
    return _mainMOC;
}

+ (void)renewMainMOC
{
#ifdef DEBUG
    if(dispatch_get_current_queue() != dispatch_get_main_queue()) {
        NSLog(@"Must renew main MOC in main thread");
        abort();
    }
#endif
    
    _mainMOC = [self getContextForCurrentThread];
}

+ (void)resetDatabase
{
#ifdef DEBUG
    if(dispatch_get_current_queue() != dispatch_get_main_queue()) {
        NSLog(@"Must reset database in main thread");
        abort();
    }
#endif
    
    _mainMOC = nil;
    _persistentStore = nil;
    
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtURL:[self databaseURL] error:&error];
    
    NSURL *libraryPath = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *extStoreURL = [libraryPath URLByAppendingPathComponent:kDatabaseExtStorage];
    
    if(![[NSFileManager defaultManager] removeItemAtURL:extStoreURL error:&error]) {
        NSLog(@"Cannot remove %@ ErrorNo:%d, %@", extStoreURL, [error code], error);
        
        //Remove contents and try again
        NSDirectoryEnumerator* enumarator = [[NSFileManager defaultManager] enumeratorAtURL:extStoreURL
                                                                 includingPropertiesForKeys:nil
                                                                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                               errorHandler:nil];
        NSURL *extFile;
        while (extFile = [enumarator nextObject]) {
            if(![[NSFileManager defaultManager] removeItemAtURL:extFile error:&error]) {
                NSLog(@"Cannot remove %@ ErrorNo:%d, %@", extFile, [error code], error);
            }
        }
        
        if(![[NSFileManager defaultManager] removeItemAtURL:extStoreURL error:&error]) {
            NSLog(@"Cannot remove %@ ErrorNo:%d, %@", extStoreURL, [error code], error);
        }
    }
    
    [self renewMainMOC];
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
+ (NSManagedObjectModel *)managedObjectModel
{
    //Use "bundleForClass:self" instead of "mainBundle" for UnitTest
    //parameter of URLForResource is the name of xcdatamodeld file
    NSURL *modelURL = [[NSBundle bundleForClass:self] URLForResource:@"BuyRecord" withExtension:@"momd"];
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
+ (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    NSURL *storeURL = [self databaseURL];
    BOOL isDatabaseCreated = [[NSFileManager defaultManager] fileExistsAtPath:[storeURL path]];
    
    NSError *error = nil;
    NSPersistentStoreCoordinator *persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
                                                                initWithManagedObjectModel:[self managedObjectModel]];
    
    NSDictionary *updateOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                                   [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    if ([persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                 configuration:nil
                                                           URL:storeURL
                                                       options:updateOptions
                                                         error:&error])
    {
        if(!isDatabaseCreated) {
            //TODO: Put built-in data if needed
        }
    } else {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        //        abort();
    }
    
    return persistentStoreCoordinator;
}

+ (void)initialize {
    //Create
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _mainMOC = [self getContextForCurrentThread];
        //Register application status change callbacks
    });
}

+ (void)_receiveApplicationWillResignActiveNotification:(NSNotification *)notif
{
    
}

+ (void)_receiveApplicationDidBecomeActiveNotification:(NSNotification *)notif
{
    
}

+ (BOOL)commitChanges:(NSError **)error
{
    return [self commitChanges:error inContext:_mainMOC];
}

+ (BOOL)commitChanges:(NSError **)error inContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return NO;
    }
    
    if ([context hasChanges] &&
        ![context save:error])
    {
        [FlurryAnalytics logEvent:@"Fail to commit changes"];
        if(error) {
            NSLog(@"Fail to commit changes. Error %@, %@", *error, [*error userInfo]);
        } else {
            NSLog(@"Fail to commit changes");
        }
        return NO;
    }
    
    return YES;
}

+ (void)cancelUnsavedChanges
{
    [self cancelUnsavedChangesInContext:_mainMOC];
}

+ (void)cancelUnsavedChangesInContext:(NSManagedObjectContext *)context
{
    if(context != nil) {
        [context rollback];
    }
}

+ (NSManagedObject *)getObjectByID:(NSManagedObjectID *)objectID
{
    return [self getObjectByID:objectID inContext:_mainMOC];
}

+ (NSManagedObject *)getObjectByID:(NSManagedObjectID *)objectID inContext:(NSManagedObjectContext *)context
{
    if(objectID == nil ||
       context == nil)
    {
        return nil;
    }
    
    return [context objectWithID:objectID];
}

//==============================================================
//  [BEGIN] Folder operation APIs
#pragma mark - Folder operation APIs
//--------------------------------------------------------------
+ (DBFolder *)obtainFolder
{
    return [self obtainFolderInContext:_mainMOC];
}

+ (DBFolder *)obtainFolderInContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return nil;
    }
    
    return [NSEntityDescription insertNewObjectForEntityForName:kFolderEntityName
                                         inManagedObjectContext:context];
}

+ (DBFolder *)obtainTempFolder
{
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:kFolderEntityName inManagedObjectContext:_mainMOC];
    return (DBFolder *)[[NSManagedObject alloc] initWithEntity:entityDescription insertIntoManagedObjectContext:nil];
}

+ (DBFolder *)getFolderInPage:(int)page withNumber:(int)number
{
    return [self getFolderInPage:page withNumber:number inContext:_mainMOC];
}

+ (DBFolder *)getFolderInPage:(int)page withNumber:(int)number inContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return nil;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderEntityName];
    NSPredicate *pagePredicate = [NSPredicate predicateWithFormat:@"%K == %d", kAttrPage, page];
    NSPredicate *numberPredicate = [NSPredicate predicateWithFormat:@"%K == %d", kAttrNumber, number];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                         [NSArray arrayWithObjects:pagePredicate, numberPredicate, nil]];
    request.fetchLimit = 1;
    
    NSError *error;
    NSArray *queryResults = [context executeFetchRequest:request error:&error];
    if(queryResults == nil) {
        NSLog(@"Fail to get folder @ (%d, %d)", page, number);
        return nil;
    }
    
    if([queryResults count] == 0) {
//        NSLog(@"No matched folder @ (%d, %d)", page, number);
        return nil;
    }
    
    return (DBFolder *)[queryResults objectAtIndex:0];
}

+ (DBFolder *)getFolderByName:(NSString *)name
{
    return [self getFolderByName:name inContext:_mainMOC];
}

+ (DBFolder *)getFolderByName:(NSString *)name inContext:(NSManagedObjectContext *)context
{
    if(context == nil ||
       [name length] == 0)
    {
        return nil;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrName, name];
    request.fetchLimit = 1;
    
    NSError *error;
    NSArray *queryResult = [context executeFetchRequest:request error:&error];
    if(queryResult == nil) {
        NSLog(@"Fail to get folder by name \"%@\"", name);
        return nil;
    }
    
    if([queryResult count] == 0) {
//        NSLog(@"No matched folder by name \"%@\"", name);
        return nil;
    }
    
    return (DBFolder *)[queryResult objectAtIndex:0];
}

+ (void)removeFolderAndClearItems:(DBFolder *)folder 
{
    if(folder == nil ||
       folder.managedObjectContext == nil)
    {
        return;
    }
    
    for(DBFolderItem *item in folder.items) {
        if(item.managedObjectContext) {
            [_mainMOC deleteObject:item];
        }
    }
    
    [_mainMOC deleteObject:folder];
}

/**
 *  Get number of folders which have the name.
 *  This may include the unsaved folder.
 *
 *  @param Name to test.
 *  @return Number of folders which have the name
 */
+ (int)numberOfFoldersWithName:(NSString *)name 
{
    if([name length] == 0) {
        return 0;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrName, name];
    
    NSError *error;
    int count = [_mainMOC countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        return 0;
    }

    return count;
}

+ (int)numberOfFolderItemWithBasicInfo:(DBItemBasicInfo *)basicInfo
{
    if(basicInfo == nil) {
        return 0;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrBasicInfo, basicInfo];
    
    NSError *error;
    int count = [_mainMOC countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        return 0;
    }
    
    return count;
}

+ (BOOL)isEmptyPage:(int)pageNumber 
{
    if(pageNumber < 0) {
        return NO;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %d", kAttrPage, pageNumber];
    
    NSError *error;
    int count = [_mainMOC countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        //Error occurs
        NSLog(@"Error occurs in isEmptyPage. Error %d, %@", error.code, error);
    }

    return (count == 0);
}
//--------------------------------------------------------------
//  [END] Folder operation APIs
//==============================================================

//==============================================================
//  [BEGIN] FolderItem operation APIs
#pragma mark - FolderItem operation APIs
//--------------------------------------------------------------
+ (DBItemBasicInfo *)obtainItemBasicInfo
{
    return [self obtainItemBasicInfoInContext:_mainMOC];
}

+ (DBItemBasicInfo *)obtainItemBasicInfoInContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return nil;
    }
    
    return [NSEntityDescription insertNewObjectForEntityForName:kItemBasicInfoEntityName
                                         inManagedObjectContext:context];
}

+ (DBItemBasicInfo *)obtainTempItemBasicInfo
{
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:kItemBasicInfoEntityName inManagedObjectContext:_mainMOC];
    return (DBItemBasicInfo *)[[NSManagedObject alloc] initWithEntity:entityDescription insertIntoManagedObjectContext:nil];
}

+ (void)removeItemBasicInfo:(DBItemBasicInfo *)basicInfo
{
    [self removeItemBasicInfo:basicInfo inContext:_mainMOC];
}

+ (void)removeItemBasicInfo:(DBItemBasicInfo *)basicInfo inContext:(NSManagedObjectContext *)context
{
    if(context == nil ||
       basicInfo == nil ||
       basicInfo.managedObjectContext == nil)
    {
        return;
    }
    
    [context deleteObject:basicInfo];
}

+ (void)_initFolderItem:(DBFolderItem *)folderItem
{
    if(folderItem) {
        folderItem.createTime = [[TimeUtil today] timeIntervalSinceReferenceDate];
        [folderItem addItemCreateLog];
        folderItem.count = 1;
    }
}

+ (DBFolderItem *)obtainFolderItem
{
    return [self obtainFolderItemInContext:_mainMOC];
}

+ (DBFolderItem *)obtainFolderItemInContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return nil;
    }
    
    DBFolderItem *folderItem = [NSEntityDescription insertNewObjectForEntityForName:kFolderItemEntityName
                                                             inManagedObjectContext:context];
    [self _initFolderItem:folderItem];
    return folderItem;
}

+ (DBFolderItem *)obtainTempFolderItem
{
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:kFolderItemEntityName inManagedObjectContext:_mainMOC];
    DBFolderItem *folderItem = (DBFolderItem *)[[NSManagedObject alloc] initWithEntity:entityDescription
                                                        insertIntoManagedObjectContext:nil];
    [self _initFolderItem:folderItem];
    return folderItem;
}

+ (void)_initFolderItem:(DBFolderItem *)folderItem fromShoppingItem:(DBShoppingItem *)shoppingItem
{
    DBItemBasicInfo *basicInfo = shoppingItem.basicInfo;
    if(folderItem.managedObjectContext == nil) {
        basicInfo = [CoreDataDatabase obtainTempItemBasicInfo];
        [basicInfo copyAttributesFrom:shoppingItem.basicInfo];
    }
    
    folderItem.basicInfo = basicInfo;
    folderItem.count = shoppingItem.count;
    folderItem.price = shoppingItem.price;
    folderItem.currencyCode = shoppingItem.currencyCode;
    folderItem.location = shoppingItem.location;
}

+ (DBFolderItem *)obtainFolderItemFromShoppingItem:(DBShoppingItem *)shoppingItem 
{
    DBFolderItem *folderItem = [self obtainFolderItem];
    [self _initFolderItem:folderItem fromShoppingItem:shoppingItem];
    
    return folderItem;
}

+ (DBFolderItem *)obtainTempFolderItemFromShoppingItem:(DBShoppingItem *)shoppingItem 
{
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:kFolderItemEntityName inManagedObjectContext:_mainMOC];
    DBFolderItem *folderItem = (DBFolderItem *)[[NSManagedObject alloc] initWithEntity:entityDescription
                                                        insertIntoManagedObjectContext:nil];
    [self _initFolderItem:folderItem fromShoppingItem:shoppingItem];
    return folderItem;
}

+ (void)removeItem:(DBFolderItem *)item
{
    [self removeItem:item inContext:_mainMOC];
}

+ (void)removeItem:(DBFolderItem *)item inContext:(NSManagedObjectContext *)context
{
    if(context == nil ||
       item == nil ||
       item.managedObjectContext == nil)
    {
        return;
    }
    
    //Keep folder information, so that folderView can update its expiry badge.
    //Also keep the basicInfo information, so that scheduler can get its name.
    [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextObjectsDidChangeNotification
                                                        object:item
                                                      userInfo:[NSDictionary dictionaryWithObject:[NSSet setWithObject:item]
                                                                                           forKey:NSDeletedObjectsKey]];
    [context deleteObject:item];
}

+ (void)removeItems: (NSMutableArray *)items 
{
    for(DBFolderItem *item in items) {
        if(item.managedObjectContext) {
            [_mainMOC deleteObject:item];
        }
    }
}

+ (DBFolderItem *)duplicateItem:(DBFolderItem *)item 
{
    if(item == nil ||
       item.managedObjectContext == nil)
    {
        return nil;
    }
    
    DBFolderItem *newItem = (DBFolderItem *)[item deepCopyInContext:_mainMOC];
    newItem.createTime = [[TimeUtil today] timeIntervalSinceReferenceDate];
    newItem.lastUpdateTime = newItem.createTime;
    newItem.changeLog = nil;
    [newItem addItemCreateLog];
//    newItem.isUserCreated = NO;
    
    return newItem;
}

+ (void)moveItem:(DBFolderItem *)item toFolder:(DBFolder *)folder withCount:(int)count 
{
    if(item == nil ||
       folder == nil)
    {
        return;
    }
    
    if(item.folder == folder) {
        return;
    }
    
    item.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
    if(count == item.count) {
        //Update folder would be ok
        item.folder = folder;
    } else {
        //1. Add new item to new folder
        DBFolderItem *newItem = (DBFolderItem *)[item deepCopyInContext:_mainMOC];
        newItem.isUserCreated = NO;
        newItem.count = count;
        newItem.folder = folder;
        newItem.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
        item.count -= count;
        [item addCountChangeLogFromOldCount:(item.count+count)];
    }
}

+ (DBItemBasicInfo *)getItemBasicInfoByName:(NSString *)name shouldExcludeBarcode:(BOOL)excludeBarcode
{
    return [self getItemBasicInfoByName:name shouldExcludeBarcode:excludeBarcode inContext:_mainMOC];
}

+ (DBItemBasicInfo *)getItemBasicInfoByName:(NSString *)name  shouldExcludeBarcode:(BOOL)excludeBarcode inContext:(NSManagedObjectContext *)context
{
    if(context == nil ||
       [name length] == 0)
    {
        return nil;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kItemBasicInfoEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrName, name];
    
    NSError *error;
    NSArray *queryResult = [context executeFetchRequest:request error:&error];
    if(queryResult == nil) {
        NSLog(@"Fail to get DBItemBasicInfo by name \"%@\"", name);
        return nil;
    }
    
    if([queryResult count] == 0) {
//        NSLog(@"No matched DBItemBasicInfo by name \"%@\"", name);
        return nil;
    }
    
    DBItemBasicInfo *basicInfoWithBarcode;
    DBItemBasicInfo *basicInfoWithoutBarcode;
    for(DBItemBasicInfo *basicInfo in queryResult) {
        if([basicInfo.barcodeData length] == 0) {
            basicInfoWithoutBarcode = basicInfo;
        } else {
            basicInfoWithBarcode = basicInfo;
        }
    }
    
    if(excludeBarcode) {
        return basicInfoWithoutBarcode;
    } else {
        if(basicInfoWithBarcode) {
            return basicInfoWithBarcode;
        } else {
            return basicInfoWithoutBarcode;
        }
    }
    
    return nil;
}

+ (DBItemBasicInfo *)getItemBasicInfoByBarcode:(Barcode *)barcode
{
    return [self getItemBasicInfoByBarcode:barcode inContext:_mainMOC];
}

+ (DBItemBasicInfo *)getItemBasicInfoByBarcode:(Barcode *)barcode inContext:(NSManagedObjectContext *)context
{
    if(context == nil ||
       [barcode.barcodeData length] == 0)
    {
        return nil;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kItemBasicInfoEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrBarcodeData, barcode.barcodeData];
    request.fetchLimit = 1;
    
    NSError *error;
    NSArray *queryResults = [context executeFetchRequest:request error:&error];
    if(queryResults == nil) {
        NSLog(@"Fail to get item by barcode %@", barcode.barcodeData);
        return nil;
    }
    
    if([queryResults count] == 0) {
//        NSLog(@"No matched item with barcode %@", barcode.barcodeData);
        return nil;
    }
    
    return (DBItemBasicInfo *)[queryResults objectAtIndex:0];
}

+ (PriceStatistics *)getPriceStatisticsOfBasicInfo:(DBItemBasicInfo *)basicInfo
{
    if(basicInfo == nil ||
       basicInfo.managedObjectContext == nil)
    {
        return nil;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K != 0 AND %K == 1 AND %K == %@", kAttrPrice, kAttrIsUserCreated, kAttrBasicInfo, basicInfo];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = @[kAttrPrice/*, kAttrLocation*/];
    
    NSError *error;
    NSArray *queryResults = [basicInfo.managedObjectContext executeFetchRequest:request error:&error];
    double price;
    DBLocation *location;
    PriceStatistics *s = [PriceStatistics new];
    for(NSDictionary *result in queryResults) {
        price = [[result objectForKey:kAttrPrice] doubleValue];
        location = nil;
        
        s.countOfPrices++;
        s.totalPrice += price;
        
        if(price < s.minPrice) {
            s.minPrice = price;
            
//            location = (DBLocation *)[self getObjectByID:(NSManagedObjectID *)[result objectForKey:kAttrLocation]
//                                               inContext:basicInfo.managedObjectContext];
//            s.minPriceLocationName = location.name;
        }
        
        if(price > s.maxPrice) {
            s.maxPrice = price;
            
//            if(location == nil) {
//                location = (DBLocation *)[self getObjectByID:(NSManagedObjectID *)[result objectForKey:kAttrLocation]
//                                                   inContext:basicInfo.managedObjectContext];
//            }
//            s.maxPriceLocationName = location.name;
        }
    }
    
    return s;
}

+ (NSDate *)getNextExpiryDateOfBasicInfo:(DBItemBasicInfo *)basicInfo
{
    if(basicInfo == nil ||
       basicInfo.managedObjectContext == nil)
    {
        return nil;
    }
    
    NSDate *date = nil;
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K > 0 AND %K == 0 AND %K == %@ AND %K.%K > %@",
                         kAttrCount, kAttrIsArchived,
                         kAttrBasicInfo, basicInfo,
                         kAttrExpiryDate, kAttrDate, [NSDate date]];
    request.fetchLimit = 1;
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:
                                 [NSString stringWithFormat:@"%@.%@", kAttrExpiryDate, kAttrDate]
                                                              ascending:YES]];
//    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:kAttrExpiryDate
//                                                              ascending:YES
//                                                             comparator:^NSComparisonResult(id obj1, id obj2) {
//                                                                 DBNotifyDate *date1 = (DBNotifyDate *)obj1;
//                                                                 DBNotifyDate *date2 = (DBNotifyDate *)obj2;
//                                                                 
//                                                                 if(date1.date < date2.date) {
//                                                                     return NSOrderedAscending;
//                                                                 } else if(date1.date > date2.date) {
//                                                                     return NSOrderedDescending;
//                                                                 }
//                                                                 
//                                                                 return NSOrderedSame;
//                                                             }]];
    
    NSString *keyToFetch = [NSString stringWithFormat:@"%@.%@", kAttrExpiryDate, kAttrDate];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = @[keyToFetch];
    
    NSError *error;
    NSArray *queryResults = [basicInfo.managedObjectContext executeFetchRequest:request error:&error];
    if([queryResults count] > 0) {
        NSDictionary *result = [queryResults objectAtIndex:0];
        date = (NSDate *)[result objectForKey:keyToFetch];
    }
    
    return date;
}

+ (void)removeImageOnlyItemBasicInfo
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kItemBasicInfoEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == nil AND %K == nil AND %K.@count == 0 AND %K == nil AND %K == 0",
                         kAttrName, kAttrBarcodeData, kAttrFolderItems, kAttrShoppingItem, kAttrIsFavorite];
    
    NSManagedObjectContext *moc = [self getContextForCurrentThread];
    NSError *error;
    NSArray *queryResults = [moc executeFetchRequest:request error:&error];
    if([queryResults count] > 0) {
        for(DBItemBasicInfo *basicInfo in queryResults) {
            [self removeItemBasicInfo:basicInfo inContext:moc];
        }
    }
}
//--------------------------------------------------------------
//  [END] FolderItem operation APIs
//==============================================================

//==============================================================
//  [BEGIN] Location Operation APIs
#pragma mark - Location Operation APIs
//--------------------------------------------------------------
+ (DBLocation *)obtainLocation
{
    return [self obtainLocationInContext:_mainMOC];
}

+ (DBLocation *)obtainLocationInContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return nil;
    }
    
    return [NSEntityDescription insertNewObjectForEntityForName:kLocationEntityName
                                         inManagedObjectContext:context];
}

+ (DBLocation *)obtainTempLocation
{
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:kLocationEntityName inManagedObjectContext:_mainMOC];
    return (DBLocation *)[[NSManagedObject alloc] initWithEntity:entityDescription
                                  insertIntoManagedObjectContext:nil];
}

+ (void)removeLocation:(DBLocation *)location 
{
    if(location == nil ||
       location.managedObjectContext == nil)
    {
        return;
    }
    
    //1. Modify list positions after location.listPosition
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kLocationEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K > %d", kAttrListPosition, location.listPosition];
    
    NSError *error;
    NSArray *queryResult = [_mainMOC executeFetchRequest:request error:&error];
    if(queryResult == nil) {
        NSLog(@"Fail to get location with position > %d", location.listPosition);
    }
    
    if([queryResult count] == 0) {
//        NSLog(@"No matched location with position > %d", location.listPosition);
    }
    
    for(DBLocation *nextLocation in queryResult) {
        nextLocation.listPosition--;
    }
    
    //2. Remove location from folderItem and shoppingItem
    request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrLocation, location];
    
    queryResult = [_mainMOC executeFetchRequest:request error:&error];
    if([queryResult count] > 0) {
        for(DBFolderItem *folderItem in queryResult) {
            folderItem.location = nil;
        }
    }
    
    request = [NSFetchRequest fetchRequestWithEntityName:kShoppingItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrLocation, location];
    
    queryResult = [_mainMOC executeFetchRequest:request error:&error];
    if([queryResult count] > 0) {
        for(DBShoppingItem *shoppingItem in queryResult) {
            shoppingItem.location = nil;
        }
    }
    
    //3. Remove location
    [_mainMOC deleteObject:location];
}

+ (BOOL)isLocationExistWithName:(NSString *)name 
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kLocationEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrName, name];
    request.fetchLimit = 1;
    
    NSError *error;
    int count = [_mainMOC countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        //Error occurs
        NSLog(@"Error occurs in isLocationExistWithName. Error %d, %@", error.code, error);
    }
    
    return (count != 0);
}

+ (void)moveLocation:(DBLocation *)location to:(int)newPosition 
{
    if(location == nil) {
        return;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kLocationEntityName];
    NSError *error;

    if(location.listPosition < newPosition) { //Move downward
        NSPredicate *beginPredicate = [NSPredicate predicateWithFormat:@"%K > %d", kAttrListPosition, location.listPosition];
        NSPredicate *endPredicate = [NSPredicate predicateWithFormat:@"%K <= %d", kAttrListPosition, newPosition];
        request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:beginPredicate, endPredicate, nil]];
        
        NSArray *queryResult = [_mainMOC executeFetchRequest:request error:&error];
        if(queryResult == nil) {
            NSLog(@"Fail to get locations between (%d %d]", location.listPosition, newPosition);
        }
        
        for(DBLocation *midLocation in queryResult) {
            midLocation.listPosition--;
        }
    } else {                                    //Move upward
        NSPredicate *beginPredicate = [NSPredicate predicateWithFormat:@"%K >= %d", kAttrListPosition, newPosition];
        NSPredicate *endPredicate = [NSPredicate predicateWithFormat:@"%K < %d", kAttrListPosition, location.listPosition];
        request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:beginPredicate, endPredicate, nil]];
        
        NSArray *queryResult = [_mainMOC executeFetchRequest:request error:&error];
        if(queryResult == nil) {
            NSLog(@"Fail to get locations between [%d %d)", newPosition, location.listPosition);
        }
        
        for(DBLocation *midLocation in queryResult) {
            midLocation.listPosition++;
        }
    }
    
    location.listPosition = newPosition;
}

+ (BOOL)shouldImportLocationsForCountry:(NSString *)countryCode 
{
    NSDictionary *prebuildLocationRoot = [NSDictionary dictionaryWithContentsOfFile:
                                          [[NSBundle mainBundle] pathForResource:@"PrebuildLocations" ofType:@"plist"]];
    NSDictionary *prebuildVersionToLocationMap = [prebuildLocationRoot objectForKey:countryCode]; //version -> list map
    NSArray *prebuildLocationVersions = [prebuildVersionToLocationMap allKeys]; //1.0, 2.0, ...
    prebuildLocationVersions = [prebuildLocationVersions sortedArrayUsingComparator:
                                ^NSComparisonResult(id obj1, id obj2) {
                                    return [VersionCompare compareVersion:(NSString *)obj1 toVersion:(NSString *)obj2];
                                }];
    
    //Get current imported version of the country
    NSMutableDictionary *importedLocations = [NSMutableDictionary dictionaryWithDictionary:
                                              [[NSUserDefaults standardUserDefaults] dictionaryForKey:kImpotedLocationKey]];
    NSString *currentVersion = [importedLocations objectForKey:countryCode];
    if([currentVersion length] == 0) {
        currentVersion = @"0.0";
        
        //Add country code and version into user defaults
        [importedLocations setValue:currentVersion forKey:countryCode];
        [[NSUserDefaults standardUserDefaults] setValue:importedLocations forKey:kImpotedLocationKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        return YES;
    }
    
    if([VersionCompare compareVersion:(NSString *)[prebuildLocationVersions lastObject] toVersion:currentVersion] == NSOrderedSame) {
        NSLog(@"Already imported newest(%@) location for %@", currentVersion, countryCode);
        return NO;
    }
    
    return YES;
}

+ (void)importLocationsInCountry:(NSString *)countryCode 
{
    if([countryCode length] == 0) {
        return;
    }
    
    //Get prebuild versions
    NSDictionary *prebuildLocationRoot = [NSDictionary dictionaryWithContentsOfFile:
                                          [[NSBundle mainBundle] pathForResource:@"PrebuildLocations" ofType:@"plist"]];
    NSDictionary *prebuildVersionToLocationMap = [prebuildLocationRoot objectForKey:countryCode]; //version -> list map
    NSArray *prebuildLocationVersions = [prebuildVersionToLocationMap allKeys]; //1.0, 2.0, ...
    prebuildLocationVersions = [prebuildLocationVersions sortedArrayUsingComparator:
                                ^NSComparisonResult(id obj1, id obj2) {
                                    return [VersionCompare compareVersion:(NSString *)obj1 toVersion:(NSString *)obj2];
                                }];
    
    //Get current imported version of the country
    NSMutableDictionary *importedLocations = [NSMutableDictionary dictionaryWithDictionary:
                                              [[NSUserDefaults standardUserDefaults] dictionaryForKey:kImpotedLocationKey]];
    NSString *currentVersion = [importedLocations objectForKey:countryCode];
    if([currentVersion length] == 0) {
        currentVersion = @"0.0";
        
        //Add country code and version into user defaults
        [importedLocations setValue:currentVersion forKey:countryCode];
        [[NSUserDefaults standardUserDefaults] setValue:importedLocations forKey:kImpotedLocationKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    if([VersionCompare compareVersion:(NSString *)[prebuildLocationVersions lastObject] toVersion:currentVersion] == NSOrderedSame) {
#ifdef DEBUG
        NSLog(@"Already imported newest(%@) location for %@", currentVersion, countryCode);
#endif
        return;
    }
    
    //Import locations
    NSArray *prebuildLocationNames = nil;
    NSString *prebuildLocationName;
    for(NSString *prebuildVersion in prebuildLocationVersions) {
        if([VersionCompare compareVersion:currentVersion toVersion:prebuildVersion] != NSOrderedAscending) {
            continue;
        }
        
        prebuildLocationNames = [prebuildVersionToLocationMap objectForKey:prebuildVersion];
        DBLocation *newLocation = nil;
        int nLastPosition = [self totalLocations];
        for(prebuildLocationName in prebuildLocationNames) {
            if([self isLocationExistWithName:prebuildLocationName]) {
                continue;
            }
            
            //If not exites, add to database
            newLocation = [self obtainLocation];
            newLocation.name = prebuildLocationName;
            newLocation.listPosition = nLastPosition;
            nLastPosition++;
        }
        
        currentVersion = prebuildVersion;
    }
    
    [importedLocations setValue:currentVersion forKey:countryCode];
    [[NSUserDefaults standardUserDefaults] setValue:importedLocations forKey:kImpotedLocationKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
//--------------------------------------------------------------
//  [END] Location Operation APIs
//==============================================================

//==============================================================
//  [BEGIN] ShoppingItem Operation APIs
#pragma mark - ShoppingItem Operation APIs
//--------------------------------------------------------------
+ (DBShoppingItem *)obtainShoppingItem
{
    return [self obtainShoppingItemInContext:_mainMOC];
}

+ (DBShoppingItem *)obtainShoppingItemInContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return nil;
    }
    
    DBShoppingItem *shoppingItem =  [NSEntityDescription insertNewObjectForEntityForName:kShoppingItemEntityName
                                                                  inManagedObjectContext:context];
    shoppingItem.count = 1;
    shoppingItem.listPosition = [self totalShoppingItemsInContext:context] - 1;
    return shoppingItem;
}

+ (DBShoppingItem *)obtainTempShoppingItem
{
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:kShoppingItemEntityName inManagedObjectContext:_mainMOC];
    return (DBShoppingItem *)[[NSManagedObject alloc] initWithEntity:entityDescription
                                      insertIntoManagedObjectContext:nil];
}

+ (DBShoppingItem *)getShoppingItemFromFolderItem:(DBFolderItem *)item 
{
    if(item == nil ||
       item.basicInfo == nil)
    {
        return nil;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kShoppingItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K ==  %@", kAttrBasicInfo, item.basicInfo];
    request.fetchLimit = 1;
    
    NSError *error;
    NSArray *queryResults = [_mainMOC executeFetchRequest:request error:&error];
    if(queryResults == nil) {
        NSLog(@"Fail to get shoppingItem from folderItem %@", item);
        return nil;
    }
    
    if([queryResults count] == 0) {
//        NSLog(@"No matched shoppingItem from folderItem %@", item);
        return nil;
    }
    
    return (DBShoppingItem *)[queryResults objectAtIndex:0];
}

+ (BOOL)isShoppingItemExisted:(DBShoppingItem *)shoppingItem 
{
    //For checking if there is a same shopping item after edting from another one.
    if(shoppingItem == nil ||
       shoppingItem.basicInfo == nil)
    {
        return NO;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kShoppingItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrBasicInfo, shoppingItem.basicInfo];
    [request setIncludesPendingChanges:NO];
    request.fetchLimit = 1;
    
    NSError *error;
    int count = [_mainMOC countForFetchRequest:request error:&error];
    if (count == NSNotFound) {
        return NO;
    }
    
    return (count != 0);
}

+ (BOOL)isItemInShoppingList:(DBFolderItem *)item 
{
    if(item == nil ||
       item.basicInfo == nil)
    {
        return NO;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kShoppingItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrBasicInfo, item.basicInfo];
    request.fetchLimit = 1;
    
    NSError *error;
    int count = [_mainMOC countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        return NO;
    }
    
    return (count != 0);
}

+ (void)addItemToShoppingList:(DBFolderItem *)item 
{
    if(item == nil ||
       item.basicInfo == nil)
    {
        return;
    }
    
    //1. Update current shoppingItems' position
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kShoppingItemEntityName];
    NSError *error;
    NSArray *shoppingItems = [_mainMOC executeFetchRequest:request error:&error];
    for(DBShoppingItem *shoppingItem in shoppingItems) {
        shoppingItem.listPosition++;
    }
    
    //2. Add new item
    DBShoppingItem *shoppingItem = [self obtainShoppingItem];
    shoppingItem.basicInfo = item.basicInfo;
}

+ (void)removeShoppingItem:(DBShoppingItem *)shoppingItem updatePositionOfRestItems:(BOOL)update
{
    if(shoppingItem == nil ||
       shoppingItem.managedObjectContext == nil)
    {
        return;
    }
    
    //1. Update shoppingItems' listPosition
    if(update) {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kShoppingItemEntityName];
        request.predicate = [NSPredicate predicateWithFormat:@"%K > %d", kAttrListPosition, shoppingItem.listPosition];
        NSError *error;
        NSArray *shoppingItems = [_mainMOC executeFetchRequest:request error:&error];
        for(DBShoppingItem *belowShoppingItem in shoppingItems) {
            belowShoppingItem.listPosition--;
        }
    }
    
    //2. Delete shoppingItem
    [_mainMOC deleteObject:shoppingItem];
}

+ (void)moveShoppingItem:(DBShoppingItem *)shoppingItem to:(int)newPosition 
{
    if(shoppingItem == nil ||
       shoppingItem.managedObjectContext == nil)
    {
        return;
    }

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kShoppingItemEntityName];
    NSError *error;
    
    if(shoppingItem.listPosition < newPosition) { //Move downward
        NSPredicate *beginPredicate = [NSPredicate predicateWithFormat:@"%K > %d", kAttrListPosition, shoppingItem.listPosition];
        NSPredicate *endPredicate = [NSPredicate predicateWithFormat:@"%K <= %d", kAttrListPosition, newPosition];
        request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:beginPredicate, endPredicate, nil]];
        
        NSArray *queryResult = [shoppingItem.managedObjectContext executeFetchRequest:request error:&error];
        if(queryResult == nil) {
            NSLog(@"Fail to get shoppingItem between (%d %d]", shoppingItem.listPosition, newPosition);
        }
        
        for(DBShoppingItem *midShoppingItem in queryResult) {
            midShoppingItem.listPosition--;
        }
    } else {                                        //Move upward
        NSPredicate *beginPredicate = [NSPredicate predicateWithFormat:@"%K >= %d", kAttrListPosition, newPosition];
        NSPredicate *endPredicate = [NSPredicate predicateWithFormat:@"%K < %d", kAttrListPosition, shoppingItem.listPosition];
        request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:beginPredicate, endPredicate, nil]];
        
        NSArray *queryResult = [shoppingItem.managedObjectContext executeFetchRequest:request error:&error];
        if(queryResult == nil) {
            NSLog(@"Fail to get shoppingItem between [%d %d)", newPosition, shoppingItem.listPosition);
        }
        
        for(DBShoppingItem *midShoppingItem in queryResult) {
            midShoppingItem.listPosition++;
        }
    }
    
    shoppingItem.listPosition = newPosition;
}
//--------------------------------------------------------------
//  [END] ShoppingItem Operation APIs
//==============================================================

//==============================================================
//  [BEGIN] NotifyDate APIs
#pragma mark - NotifyDate APIs
//--------------------------------------------------------------
+ (DBNotifyDate *)obtainNotifyDate
{
    return [self obtainNotifyDateInContext:_mainMOC];
}

+ (DBNotifyDate *)obtainNotifyDateInContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return nil;
    }
    
    return [NSEntityDescription insertNewObjectForEntityForName:kNotifyDateEntityName
                                         inManagedObjectContext:context];
}

+ (DBNotifyDate *)obtainTempNotifyDate
{
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:kNotifyDateEntityName inManagedObjectContext:_mainMOC];
    return (DBNotifyDate *)[[NSManagedObject alloc] initWithEntity:entityDescription insertIntoManagedObjectContext:nil];
}

+ (DBNotifyDate *)getNotifyDateOfDate:(NSDate *)date
{
    return [self getNotifyDateOfDate:date inContext:_mainMOC];
}

+ (DBNotifyDate *)getNotifyDateOfDate:(NSDate *)date inContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return nil;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kNotifyDateEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrDate, date];
    request.fetchLimit = 1;
    
    NSError *error;
    NSArray *queryResults = [context executeFetchRequest:request error:&error];
    if(queryResults == nil) {
        NSLog(@"Fail to get notify date @ %@", date);
        return nil;
    }
    
    if([queryResults count] == 0) {
//        NSLog(@"No matched folder @ (%d, %d)", page, number);
        return nil;
    }
    
    return (DBNotifyDate *)[queryResults objectAtIndex:0];
}

+ (void)removeNotifyDate:(DBNotifyDate *)notifyDate
{
    if(notifyDate.managedObjectContext) {
        [notifyDate.managedObjectContext deleteObject:notifyDate];
    }
}

+ (void)removeEmptyDatesInContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kNotifyDateEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K.@count == 0 AND %K.@count == 0",
                         kAttrExpireItems, kAttrNearExpireItems];
    request.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:kAttrDate ascending:YES]];
    
    NSError *error;
    NSArray *queryResults = [context executeFetchRequest:request error:&error];
    if(queryResults == nil) {
        NSLog(@"Fail to get notify dates");
        return;
    }
    
    for(DBNotifyDate *date in queryResults) {
        [self removeNotifyDate:date];
    }
}

//--------------------------------------------------------------
//  [END] NotifyDate APIs
//==============================================================

//==============================================================
//  [BEGIN] Count related query
#pragma mark - Count related query
//--------------------------------------------------------------
+ (int)totalPages
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderEntityName];
    request.fetchLimit = 1;
    request.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:kAttrPage ascending:NO]];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = [NSArray arrayWithObject:kAttrPage];

    NSError *error;
    NSArray *queryResult = [_mainMOC executeFetchRequest:request error:&error];
    if(queryResult == nil) {
        NSLog(@"Fail to get any folder");
    }
    
    if([queryResult count] > 0) {
        NSNumber *result = [[queryResult objectAtIndex:0] objectForKey:kAttrPage];
        return ([result intValue]+1);
    }
    
    return 1;   //if no folder, there will be at least one page
}

+ (int)totalItems
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    NSError *error;
    int count = [_mainMOC countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        NSLog(@"Cannot find any folderItem");
        return 0;
    }
    
    return count;
}

+ (int)totalItemsInFolder:(DBFolder *)folder 
{
    if(folder == nil ||
       folder.managedObjectContext == nil)
    {
        return 0;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrFolder, folder];

    NSError *error;
    int count = [folder.managedObjectContext countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        NSLog(@"Cannot find any folderItem in folder %@", folder.name);
        return 0;
    }
    
    return count;
}

+ (int)totalExpiredItemsSince:(NSDate *)date
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    NSPredicate *timePredicate = [NSPredicate predicateWithFormat:@"%K.%K > %@ AND %K.%K >= %@",
                                  kAttrExpiryDate, kAttrDate, [NSDate dateWithTimeIntervalSinceReferenceDate:0],
                                  kAttrExpiryDate, kAttrDate, date];
    NSPredicate *unarchivedPredicate = [NSPredicate predicateWithFormat:@"%K == 0", kAttrIsArchived];
    NSPredicate *countPredicate = [NSPredicate predicateWithFormat:@"%K > 0", kAttrCount];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                         [NSArray arrayWithObjects:timePredicate, unarchivedPredicate, countPredicate, nil]];
    
    NSError *error;
    int count = [_mainMOC countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        NSLog(@"Cannot find any expired folderItem since %@", date);
        return 0;
    }
    
    return count;
}

+ (int)totalExpiredItemsOnDate:(NSDate *)date
{
    return [self totalExpiredItemsOnDate:date inContext:_mainMOC];
}

+ (int)totalExpiredItemsOnDate:(NSDate *)date inContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return -1;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    NSPredicate *timePredicate = [NSPredicate predicateWithFormat:@"%K.%K == %@", kAttrExpiryDate, kAttrDate, date];
    NSPredicate *unarchivedPredicate = [NSPredicate predicateWithFormat:@"%K == 0", kAttrIsArchived];
    NSPredicate *countPredicate = [NSPredicate predicateWithFormat:@"%K > 0", kAttrCount];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                         [NSArray arrayWithObjects:timePredicate, unarchivedPredicate, countPredicate, nil]];
    
    NSError *error;
    int count = [context countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        NSLog(@"Cannot find any expired folderItem since %@", date);
        return 0;
    }
    
    return count;
}

+ (int)totalExpiredItemsBeforeAndIncludeDate:(NSDate *)date
{
    return [self totalExpiredItemsBeforeAndIncludeDate:date inContext:_mainMOC];
}

+ (int)totalExpiredItemsBeforeAndIncludeDate:(NSDate *)date inContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return -1;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    NSPredicate *timePredicate = [NSPredicate predicateWithFormat:@"%K.%K > %@ AND %K.%K <= %@",
                                  kAttrExpiryDate, kAttrDate, [NSDate dateWithTimeIntervalSinceReferenceDate:0],
                                  kAttrExpiryDate, kAttrDate, date];
    NSPredicate *unarchivedPredicate = [NSPredicate predicateWithFormat:@"%K == 0", kAttrIsArchived];
    NSPredicate *countPredicate = [NSPredicate predicateWithFormat:@"%K > 0", kAttrCount];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                         [NSArray arrayWithObjects:timePredicate, unarchivedPredicate, countPredicate, nil]];
    
    NSError *error;
    int count = [context countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        NSLog(@"Cannot find any expired folderItem since %@", date);
        return 0;
    }
    
    return count;
}

+ (int)totalExpiredItemsInFolder:(DBFolder *)folder within:(int)days  //For showing expired count in badge of a Folder
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    NSPredicate *folderPredicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrFolder, folder];
    NSPredicate *timePredicate = [NSPredicate predicateWithFormat:@"%K.%K > %@ AND %K.%K <= %@",
                                  kAttrExpiryDate, kAttrDate, [NSDate dateWithTimeIntervalSinceReferenceDate:0],
                                  kAttrExpiryDate, kAttrDate, [TimeUtil dateFromToday:days]];
    NSPredicate *unarchivedPredicate = [NSPredicate predicateWithFormat:@"%K == 0", kAttrIsArchived];
    NSPredicate *countPredicate = [NSPredicate predicateWithFormat:@"%K > 0", kAttrCount];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                         [NSArray arrayWithObjects:folderPredicate, timePredicate, unarchivedPredicate, countPredicate, nil]];
    
    NSError *error;
    int count = [_mainMOC countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        NSLog(@"Cannot find any expired folderItem in folder %@", folder.name);
        return 0;
    }
    
    return count;
}

+ (int)totalNearExpiredItemsInFolder:(DBFolder *)folder  //For showing near-expired count in badge of a Folder
{
    if(folder == nil) {
        return 0;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    NSPredicate *folderPredicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrFolder, folder];
    NSPredicate *timePredicate = [NSPredicate predicateWithFormat:@"%K.%K > %@", kAttrExpiryDate, kAttrDate, [TimeUtil today]];
    NSPredicate *nearExpiryPredicate = [NSPredicate predicateWithFormat:@"%K.@count > 0", kAttrNearExpiryDates];
    NSPredicate *unarchivedPredicate = [NSPredicate predicateWithFormat:@"%K == 0", kAttrIsArchived];
    NSPredicate *countPredicate = [NSPredicate predicateWithFormat:@"%K > 0", kAttrCount];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                         [NSArray arrayWithObjects:folderPredicate, timePredicate, nearExpiryPredicate, unarchivedPredicate, countPredicate, nil]];
    
    NSError *error;
    NSArray *candidateFolderItems = [_mainMOC executeFetchRequest:request error:&error];
    
    int nNearExpiredCount = 0;
    for(DBFolderItem *folderItem in candidateFolderItems) {
        if([folderItem isNearExpired]) {
            nNearExpiredCount++;
        }
    }
    
    return nNearExpiredCount;
}

//For showing expired count in list
+ (int)totalExpiredItemsOfBasicInfo:(DBItemBasicInfo *)basicInfo inFolder:(DBFolder *)folder
{
    if(basicInfo == nil ||
       basicInfo.managedObjectContext == nil ||
       folder == nil ||
       folder.objectID == nil)
    {
        return 0;
    }
    
    if(![basicInfo.managedObjectContext isEqual:folder.managedObjectContext]) {
        folder = (DBFolder *)[self getObjectByID:folder.objectID inContext:basicInfo.managedObjectContext];
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    NSPredicate *folderPredicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrFolder, folder];
    NSPredicate *basicInfoPredicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrBasicInfo, basicInfo];
    NSPredicate *timePredicate = [NSPredicate predicateWithFormat:@"%K.%K > %@ AND %K.%K <= %@",
                                  kAttrExpiryDate, kAttrDate, [NSDate dateWithTimeIntervalSinceReferenceDate:0],
                                  kAttrExpiryDate, kAttrDate, [TimeUtil today]];
    NSPredicate *unarchivedPredicate = [NSPredicate predicateWithFormat:@"%K == 0", kAttrIsArchived];
    NSPredicate *countPredicate = [NSPredicate predicateWithFormat:@"%K > 0", kAttrCount];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                         @[folderPredicate, basicInfoPredicate, timePredicate, unarchivedPredicate, countPredicate]];
    
    NSError *error;
    int count = [basicInfo.managedObjectContext countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        NSLog(@"Cannot find any expired folderItem in folder %@", folder.name);
        return 0;
    }
    
    return count;
}

//For showing near-expired count in list
+ (int)totalNearExpiredOfBasicInfo:(DBItemBasicInfo *)basicInfo inFolder:(DBFolder *)folder
{
    if(basicInfo == nil ||
       basicInfo.managedObjectContext == nil ||
       folder == nil ||
       folder.objectID == nil)
    {
        return 0;
    }
    
    if(![basicInfo.managedObjectContext isEqual:folder.managedObjectContext]) {
        folder = (DBFolder *)[self getObjectByID:folder.objectID inContext:basicInfo.managedObjectContext];
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    NSPredicate *folderPredicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrFolder, folder];
    NSPredicate *basicInfoPredicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrBasicInfo, basicInfo];
    NSPredicate *timePredicate = [NSPredicate predicateWithFormat:@"%K.%K > %@ AND %K.%K <= %@",
                                  kAttrExpiryDate, kAttrDate, [TimeUtil today],
                                  kAttrExpiryDate, kAttrDate, [TimeUtil dateFromToday:90]];
    NSPredicate *nearExpiryPredicate = [NSPredicate predicateWithFormat:@"%K.@count > 0", kAttrNearExpiryDates];
    NSPredicate *unarchivedPredicate = [NSPredicate predicateWithFormat:@"%K == 0", kAttrIsArchived];
    NSPredicate *countPredicate = [NSPredicate predicateWithFormat:@"%K > 0", kAttrCount];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                         @[folderPredicate, basicInfoPredicate, timePredicate, nearExpiryPredicate, unarchivedPredicate, countPredicate]];
    
    NSError *error;
    NSArray *candidateFolderItems = [basicInfo.managedObjectContext executeFetchRequest:request error:&error];
    
    int nNearExpiredCount = 0;
    for(DBFolderItem *folderItem in candidateFolderItems) {
        if([folderItem isNearExpired]) {
            nNearExpiredCount++;
        }
    }
    
    return nNearExpiredCount;
}

+ (int)totalExpiredItemsOfBasicInfo:(DBItemBasicInfo *)basicInfo
{
    if(basicInfo == nil ||
       basicInfo.managedObjectContext == nil)
    {
        return 0;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    NSPredicate *basicInfoPredicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrBasicInfo, basicInfo];
    NSPredicate *timePredicate = [NSPredicate predicateWithFormat:@"%K.%K > %@ AND %K.%K <= %@",
                                  kAttrExpiryDate, kAttrDate, [NSDate dateWithTimeIntervalSinceReferenceDate:0],
                                  kAttrExpiryDate, kAttrDate, [TimeUtil today]];
    NSPredicate *unarchivedPredicate = [NSPredicate predicateWithFormat:@"%K == 0", kAttrIsArchived];
    NSPredicate *countPredicate = [NSPredicate predicateWithFormat:@"%K > 0", kAttrCount];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                         @[basicInfoPredicate, timePredicate, unarchivedPredicate, countPredicate]];
    
    NSError *error;
    int count = [basicInfo.managedObjectContext countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        NSLog(@"Cannot find any expired folderItem of basicInfo %@", basicInfo.objectID.URIRepresentation);
        return 0;
    }
    
    return count;
}

//For showing near-expired count in list
+ (int)totalNearExpiredOfBasicInfo:(DBItemBasicInfo *)basicInfo
{
    if(basicInfo == nil ||
       basicInfo.managedObjectContext == nil)
    {
        return 0;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    NSPredicate *basicInfoPredicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrBasicInfo, basicInfo];
    NSPredicate *timePredicate = [NSPredicate predicateWithFormat:@"%K.%K > %@", kAttrExpiryDate, kAttrDate, [TimeUtil today]];
    NSPredicate *nearExpiryPredicate = [NSPredicate predicateWithFormat:@"%K.@count > 0", kAttrNearExpiryDates];
    NSPredicate *unarchivedPredicate = [NSPredicate predicateWithFormat:@"%K == 0", kAttrIsArchived];
    NSPredicate *countPredicate = [NSPredicate predicateWithFormat:@"%K > 0", kAttrCount];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                         @[basicInfoPredicate, timePredicate, nearExpiryPredicate, unarchivedPredicate, countPredicate]];
    
    NSError *error;
    NSArray *candidateFolderItems = [basicInfo.managedObjectContext executeFetchRequest:request error:&error];
    
    int nNearExpiredCount = 0;
    for(DBFolderItem *folderItem in candidateFolderItems) {
        if([folderItem isNearExpired]) {
            nNearExpiredCount++;
        }
    }
    
    return nNearExpiredCount;
}

+ (int)totalLocations
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kLocationEntityName];
    
    NSError *error;
    int count = [_mainMOC countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        NSLog(@"No location exists.");
        return 0;
    }
    
    return count;
}

+ (int)totalShoppingItems
{
    return [self totalShoppingItemsInContext:_mainMOC];
}

+ (int)totalShoppingItemsInContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return 0;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kShoppingItemEntityName];
    
    NSError *error;
    int count = [context countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        NSLog(@"No location exists.");
        return 0;
    }
    
    return count;
}

+ (int)numberOfItemsFromShoppingItem:(DBShoppingItem *)shoppingItem     //For updating chart image
{
    if(shoppingItem == nil ||
       shoppingItem.basicInfo == nil)
    {
        return 0;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrBasicInfo, shoppingItem.basicInfo];
    
    NSError *error;
    int count = [_mainMOC countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        NSLog(@"No folderItem has the same basicInfo with shoppingItem %@", shoppingItem.basicInfo);
        return 0;
    }
    
    return count;
}

+ (int)stockOfBasicInfo:(DBItemBasicInfo *)basicInfo inFolder:(DBFolder *)folder
{
    if(basicInfo == nil ||
       basicInfo.managedObjectContext == nil ||
       folder == nil ||
       folder.objectID == nil)
    {
        return 0;
    }
    
    if(![basicInfo.managedObjectContext isEqual:folder.managedObjectContext]) {
        folder = (DBFolder *)[self getObjectByID:folder.objectID inContext:basicInfo.managedObjectContext];
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K != 0 AND %K == 0 AND %K == %@ AND %K == %@",
                         kAttrCount, kAttrIsArchived, kAttrBasicInfo, basicInfo, kAttrFolder, folder];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = [NSArray arrayWithObject:kAttrCount];
    
    NSError *error;
    NSArray *queryResults = [basicInfo.managedObjectContext executeFetchRequest:request error:&error];
    int stock = 0;
    for(NSDictionary *result in queryResults) {
        stock += [[result objectForKey:kAttrCount] intValue];
    }
    
    return stock;
}

+ (int)stockOfBasicInfo:(DBItemBasicInfo *)basicInfo
{
    if(basicInfo == nil ||
       basicInfo.managedObjectContext == nil)
    {
        return 0;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K != 0 AND %K == 0 AND %K == %@",
                         kAttrCount, kAttrIsArchived, kAttrBasicInfo, basicInfo];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = [NSArray arrayWithObject:kAttrCount];
    
    NSError *error;
    NSArray *queryResults = [basicInfo.managedObjectContext executeFetchRequest:request error:&error];
    int stock = 0;
    for(NSDictionary *result in queryResults) {
        stock += [[result objectForKey:kAttrCount] intValue];
    }
    
    return stock;
}

+ (int)totalFavorites
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kItemBasicInfoEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == 1", kAttrIsFavorite];
    
    NSError *error;
    int count = [_mainMOC countForFetchRequest:request error:&error];
    if(count == NSNotFound) {
        return 0;
    }
    
    return count;
}
//--------------------------------------------------------------
//  [END] Count related query
//==============================================================

//==============================================================
//  [BEGIN] List related query
#pragma mark - List related query
//--------------------------------------------------------------
+ (NSMutableArray *)getItemsByName:(NSString *)name 
{
    if([name length] == 0) {
        return nil;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K.%K == %@", kAttrBasicInfo, kAttrName, name];
    
    NSError *error;
    NSArray *folderItems = [_mainMOC executeFetchRequest:request error:&error];
    if(folderItems == nil) {
        NSLog(@"Fail to get DBFolderItem by name \"%@\"", name);
        return nil;
    }
    
    if([folderItems count] == 0) {
//        NSLog(@"No matched DBFolder by name \"%@\"", name);
        return nil;
    }
    
    return [NSMutableArray arrayWithArray:folderItems];
}

+ (NSMutableArray *)getItemsContainsName:(NSString *)name 
{
    if([name length] == 0) {
        return nil;
    }
    
//    NSString *searchString = [name stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
//    searchString = [searchString stringByReplacingOccurrencesOfString:@"%" withString:@"\\%"];
//    searchString = [searchString stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"];
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
//    request.predicate = [NSPredicate predicateWithFormat:@"name LIKE LOWER('%%%@%%') ESCAPE '\\'", searchString];
    request.predicate = [NSPredicate predicateWithFormat:@"ANY %K.%K CONTAINS[c] %@", kAttrBasicInfo, kAttrName, name];
    
    NSError *error;
    NSArray *queryResults = [_mainMOC executeFetchRequest:request error:&error];
    if(queryResults == nil) {
        NSLog(@"Fail to get folderItem contains name \"%@\". Error %d %@", name, error.code, error);
        return nil;
    }
    
    return [NSMutableArray arrayWithArray:queryResults];
}

+ (NSArray *)getItemBasicInfosContainsName:(NSString *)name
{
    if([name length] == 0) {
        return nil;
    }
    
//    NSString *searchString = [name stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
//    searchString = [searchString stringByReplacingOccurrencesOfString:@"%" withString:@"\\%"];
//    searchString = [searchString stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"];
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
//    request.predicate = [NSPredicate predicateWithFormat:@"name LIKE LOWER('%%%@%%') ESCAPE '\\'", searchString];
    request.predicate = [NSPredicate predicateWithFormat:@"ANY %K.%K CONTAINS[c] %@ AND %K.%K == nil",
                         kAttrBasicInfo, kAttrName, name, kAttrFolder, kAttrPassword];
    
    NSString *expiryKey = [NSString stringWithFormat:@"%@.%@", kAttrExpiryDate, kAttrDate];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:expiryKey ascending:NO]];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = @[kAttrBasicInfo, expiryKey, kAttrCount, kAttrIsArchived, kAttrLastUpdateTime];
    
    NSError *error;
    NSArray *queryResults = [_mainMOC executeFetchRequest:request error:&error];
    
    NSMutableOrderedSet *basicInfos = [NSMutableOrderedSet orderedSet];
    NSDate *expiryDate = nil;
    NSNumber *count;
    NSNumber *isArchived;
    NSMutableSet *restResults = [NSMutableSet set];
    
    //Collect items which are expired or has expiry date(count > 0 && !isArchived)
    for(NSDictionary *result in queryResults) {
        expiryDate = (NSDate *)[result objectForKey:expiryKey];
        count = (NSNumber *)[result objectForKey:kAttrCount];
        isArchived = (NSNumber *)[result objectForKey:kAttrIsArchived];
        
        if([expiryDate timeIntervalSinceReferenceDate] > 0 &&
           [count intValue] > 0 && [isArchived boolValue] == NO)
        {
            [basicInfos insertObject:[result objectForKey:kAttrBasicInfo] atIndex:0];
            [restResults removeObject:result];
        } else {
            [restResults addObject:result];
        }
    }
    
    //Collect rest result according to lastUpdateTime
    NSArray *sortedResults = [restResults sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:kAttrLastUpdateTime ascending:NO]]];
    for(NSDictionary *result in sortedResults) {
        [basicInfos addObject:[result objectForKey:kAttrBasicInfo]];
    }
    
    return [basicInfos array];
}

+ (NSMutableArray *)getItemsByBarcode:(Barcode *)barcode
{
    if([barcode.barcodeData length] == 0) {
        return nil;
    }
    
    DBItemBasicInfo *basicInfo =  [self getItemBasicInfoByBarcode:barcode];
    if([basicInfo.folderItems count] == 0) {
        return nil;
    }
    
    return [NSMutableArray arrayWithArray:[basicInfo.folderItems allObjects]];
}

+ (NSMutableArray *)getItemsInFolder:(DBFolder *)folder sortBy:(NSString *)columnName ascending:(BOOL)isAscending 
{
    if(folder == nil ||
       folder.items == nil)
    {
        return nil;
    }
    
    NSArray *sortedItems = [folder.items allObjects];
    NSSortDescriptor *sorting = nil;
    if(columnName != nil) {
        sorting =  [NSSortDescriptor sortDescriptorWithKey:columnName
                                                 ascending:isAscending];
        sortedItems = [folder.items sortedArrayUsingDescriptors:[NSArray arrayWithObject:sorting]];
    }
    
    return [NSMutableArray arrayWithArray:sortedItems];
}

+ (NSMutableArray *)getItemsHaveExpiredDayIncludeArchived:(BOOL)includeArchived 
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    request.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:
                                                        [NSString stringWithFormat:@"%@.%@", kAttrExpiryDate, kAttrDate]
                                                                                     ascending:YES]];
    
    if(includeArchived) {
        request.predicate = [NSPredicate predicateWithFormat:@"%K.%K > %@ AND %K > 0",
                             kAttrExpiryDate, kAttrDate, [NSDate dateWithTimeIntervalSinceReferenceDate:0], kAttrCount];
    } else {
        request.predicate = [NSPredicate predicateWithFormat:@"%K.%K > %@ AND %K > 0 AND %K == 0",
                             kAttrExpiryDate, kAttrDate, [NSDate dateWithTimeIntervalSinceReferenceDate:0], kAttrCount, kAttrIsArchived];
    }
    
    NSError *error;
    NSArray *queryResults = [_mainMOC executeFetchRequest:request error:&error];
    if(queryResults == nil) {
        NSLog(@"Fail to get items which have expiryDate");
        return nil;
    }
    
    return [NSMutableArray arrayWithArray:queryResults];
}

+ (NSMutableArray *)getAllLocations
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kLocationEntityName];
    request.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:kAttrListPosition ascending:YES]];
    
    NSError *error;
    NSArray *queryResults = [_mainMOC executeFetchRequest:request error:&error];
    if(queryResults == nil) {
        NSLog(@"Fail to get locations");
        return nil;
    }
    
    return [NSMutableArray arrayWithArray:queryResults];
}

+ (NSArray *)getFoldersContainsItemBarcode:(Barcode *)barcode
{
    if([barcode.barcodeData length] == 0) {
        return nil;
    }
    
    //This implementation is a little bit slower but saves a lot of memory after scanning different barcodes
    //1. Get folder items first
    DBItemBasicInfo *basicInfo =  [self getItemBasicInfoByBarcode:barcode];
    NSFetchRequest *itemRequest = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    itemRequest.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrBasicInfo, basicInfo];
    
    NSError *error;
    NSArray *folderItems = [_mainMOC executeFetchRequest:itemRequest error:&error];
    
    //2. Get folders from items
    NSString *keyPath = [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", kAttrFolder];
    NSArray *folderIDs = [folderItems valueForKeyPath:keyPath];
    
    NSFetchRequest *folderRequest = [NSFetchRequest fetchRequestWithEntityName:kFolderEntityName];
    folderRequest.predicate = [NSPredicate predicateWithFormat:@"(SELF in %@) AND (%K == nil)", folderIDs, kAttrPassword];
    NSArray *fetchedFolders = [_mainMOC executeFetchRequest:folderRequest error:&error];
    
    if([fetchedFolders count] == 0) {
        return nil;
    }
    
    return fetchedFolders;
    
//    //This implementation uses more memory but much faster for the second time to scan the barcode
//    DBItemBasicInfo *basicInfo =  [self getItemBasicInfoByBarcode:barcode];
//    if([basicInfo.folderItems count] == 0) {
//        return nil;
//    }
//    
//    NSMutableSet *folderSet = [NSMutableSet set];
//    for(DBFolderItem *folderItem in basicInfo.folderItems) {
//        [folderSet addObject:folderItem.folder];
//    }
//    
//    if([folderSet count] == 0) {
//        NSLog(@"Error: No item is in folder");
//        return nil;
//    }
//    
//    return [NSMutableArray arrayWithArray:[folderSet allObjects]];
}

+ (NSArray *)getFoldersContainsItemName:(NSString *)name
{
    if([name length] == 0) {
        return nil;
    }
    
    NSMutableArray *folderItems = [self getItemsContainsName:name];

    //We have considered about time and memory usage, this implementation may use a little bit more meory,
    //but it's 2x faster than fetch folders by IDs since there won't be too many folders.
    NSMutableSet *folders = [NSMutableSet set];
    for(DBFolderItem *folderItem in folderItems) {
        if(folderItem.folder != nil &&
           [folderItem.folder.password length] == 0)
        {
            [folders addObject:folderItem.folder];
        }
    }
    
    if([folders count] == 0) {
        return nil;
    }
    
    return [folders allObjects];
}

+ (NSArray *)getFoldersContainsBasicInfo:(DBItemBasicInfo *)basicInfo
{
    if(basicInfo == nil) {
        return nil;
    }
    
    NSMutableSet *folders = [NSMutableSet set];
    NSSet *folderItems = [NSSet setWithSet:basicInfo.folderItems];
    for(DBFolderItem *folderItem in folderItems) {
        if(folderItem.folder != nil &&
           [folderItem.folder.password length] == 0)
        {
            [folders addObject:folderItem.folder];
        }
    }
    
    if([folders count] == 0) {
        return nil;
    }
    
    return [folders allObjects];
}

+ (NSMutableArray *)getShoppingList
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kShoppingItemEntityName];
    request.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:kAttrListPosition ascending:YES]];
    
    NSError *error;
    NSArray *queryResults = [_mainMOC executeFetchRequest:request error:&error];
    if(queryResults == nil) {
        NSLog(@"Fail to get shoppingItems");
        return nil;
    }
    
    return [NSMutableArray arrayWithArray:queryResults];
}

+ (NSMutableArray *)getItemsFromShoppingItem:(DBShoppingItem *)shoppingItem 
{
    if(shoppingItem == nil ||
       shoppingItem.basicInfo == nil)
    {
        return 0;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrBasicInfo, shoppingItem.basicInfo];
    
    NSError *error;
    NSArray *folderItems = [_mainMOC executeFetchRequest:request error:&error];
    if(folderItems == nil) {
        NSLog(@"Fail to get folderItem from shoppingItem %@", shoppingItem);
        return nil;
    }
    
    return [NSMutableArray arrayWithArray:folderItems];
}

+ (NSMutableArray *)getFoldersContainsItemsRelatedToShoppingItem:(DBShoppingItem *)shoppingItem 
{
    NSMutableArray *folderItems = [self getItemsFromShoppingItem:shoppingItem];
    
    NSMutableSet *folders = [NSMutableSet set];
    for(DBFolderItem *item in folderItems) {
        if(item.folder != nil &&
           [item.folder.password length] == 0)
        {
            [folders addObject:item.folder];
        }
    }
    
    return [NSMutableArray arrayWithArray:[folders allObjects]];
}

//For using images of expired items as folder cover
+ (NSArray *)getImagesOfExpiredItemsInFolder:(DBFolder *)folder
{
    if(folder == nil ||
       folder.managedObjectContext == nil)
    {
        return nil;
    }
    
    //1. Get expired folder items
    NSError *error;
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@ AND %K.%K <= %@ AND %K == 0 AND %K > 0 AND %K.%K != nil",
                         kAttrFolder, folder,
                         kAttrExpiryDate, kAttrDate, [TimeUtil today],
                         kAttrIsArchived,
                         kAttrCount,
                         kAttrBasicInfo, kAttrImageRawData];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = [NSArray arrayWithObject:kAttrBasicInfo];
    
    NSArray *folerItems = [folder.managedObjectContext executeFetchRequest:request error:&error];
    
    //2. Get images from basicInfo of folderItems
    NSString *keyPath = [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", kAttrBasicInfo];
    return [folerItems valueForKeyPath:keyPath];
}

+ (NSArray *)getBasicInfosInFolder:(DBFolder *)folder
{
    if(folder == nil) {
        return nil;
    }
    
    //If we use folder.items, it will be slow at the first time.
    //But it'll very fast at the second time since all data has been loaded into memory.
    //It waste a lot of memory, so we do not use that solution.
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    
//    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrFolder, folder];
//    request.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:kAttrLastUpdateTime ascending:NO]];
//    request.resultType = NSDictionaryResultType;
//    request.propertiesToFetch = [NSArray arrayWithObject:kAttrBasicInfo];
//    
//    NSError *error;
//    NSArray *queryResults = [_mainMOC executeFetchRequest:request error:&error];
//    NSMutableOrderedSet *basicInfos = [NSMutableOrderedSet orderedSet];
//    for(NSDictionary *result in queryResults) {
//        [basicInfos addObject:[result objectForKey:kAttrBasicInfo]];
//    }
    
    //Expired basicInfo will list on top
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", kAttrFolder, folder];
    
    NSString *expiryKey = [NSString stringWithFormat:@"%@.%@", kAttrExpiryDate, kAttrDate];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:expiryKey ascending:NO]];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = @[kAttrBasicInfo, expiryKey, kAttrCount, kAttrIsArchived, kAttrLastUpdateTime];
    
    NSError *error;
    NSArray *queryResults = [_mainMOC executeFetchRequest:request error:&error];
    
    NSMutableOrderedSet *basicInfos = [NSMutableOrderedSet orderedSet];
    NSDate *expiryDate = nil;
    NSNumber *count;
    NSNumber *isArchived;
    NSMutableSet *restResults = [NSMutableSet set];
    
    //Collect items which are expired or has expiry date(count > 0 && !isArchived)
    for(NSDictionary *result in queryResults) {
        expiryDate = (NSDate *)[result objectForKey:expiryKey];
        count = (NSNumber *)[result objectForKey:kAttrCount];
        isArchived = (NSNumber *)[result objectForKey:kAttrIsArchived];
        
        if([expiryDate timeIntervalSinceReferenceDate] > 0 &&
           [count intValue] > 0 && [isArchived boolValue] == NO)
        {
            [basicInfos insertObject:[result objectForKey:kAttrBasicInfo] atIndex:0];
            [restResults removeObject:result];
        } else {
            [restResults addObject:result];
        }
    }

    //Collect rest result according to lastUpdateTime
    NSArray *sortedResults = [restResults sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:kAttrLastUpdateTime ascending:NO]]];
    for(NSDictionary *result in sortedResults) {
        [basicInfos addObject:[result objectForKey:kAttrBasicInfo]];
    }
    
    return [basicInfos array];
}

+ (NSArray *)getBasicInfoIDsWithImageInFolder:(DBFolder *)folder
{
    if(folder == nil ||
       folder.managedObjectContext == nil)
    {
        return nil;
    }
    
    //1. Get folder items
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@ AND %K.%K != nil",
                         kAttrFolder, folder, kAttrBasicInfo, kAttrImageRawData];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = [NSArray arrayWithObject:kAttrBasicInfo];
    
    NSError *error;
    NSArray *fetchedFolderItems = [folder.managedObjectContext executeFetchRequest:request error:&error];
    
    //2. Get distinct basicInfos
    NSString *keyPath = [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", kAttrBasicInfo];
    return [fetchedFolderItems valueForKeyPath:keyPath];
}

+ (NSArray *)getFolderItemsWithBasicInfo:(DBItemBasicInfo *)basicInfo inFolder:(DBFolder *)folder
{
    if(basicInfo == nil ||
       basicInfo.managedObjectContext == nil ||
       folder == nil ||
       folder.objectID == nil)
    {
        return nil;
    }
    
    if(![basicInfo.managedObjectContext isEqual:folder.managedObjectContext]) {
        folder = (DBFolder *)[CoreDataDatabase getObjectByID:folder.objectID inContext:basicInfo.managedObjectContext];
    }

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == %@ AND %K == %@", kAttrFolder, folder, kAttrBasicInfo, basicInfo];
    NSError *error;
    NSArray *folderItems = [basicInfo.managedObjectContext executeFetchRequest:request error:&error];

    if([folderItems count] > 0) {
        return folderItems;
    }

    return nil;
}

+ (NSMutableArray *)getNotifyDatesWithinDaysFromToday:(int)days
{
    return [self getNotifyDatesWithinDaysFromToday:days inContext:_mainMOC];
}

+ (NSMutableArray *)getNotifyDatesWithinDaysFromToday:(int)days inContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return nil;
    }
    
    NSDate *maxDate = [TimeUtil dateFromToday:days];
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kNotifyDateEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K >= %@ AND %K <= %@",
                         kAttrDate, [TimeUtil today], kAttrDate, maxDate];
    request.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:kAttrDate ascending:YES]];
    
    NSError *error;
    NSArray *queryResults = [context executeFetchRequest:request error:&error];
    if(queryResults == nil) {
        NSLog(@"Fail to get notify dates");
        return nil;
    }
    
    return [NSMutableArray arrayWithArray:queryResults];
}

+ (NSMutableArray *)getExpiredItemsBeforeToday
{
    return [self getExpiredItemsBeforeTodayInContext:_mainMOC];
}

+ (NSMutableArray *)getExpiredItemsBeforeTodayInContext:(NSManagedObjectContext *)context
{
    if(context == nil) {
        return nil;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kFolderItemEntityName];
    NSPredicate *timePredicate = [NSPredicate predicateWithFormat:@"%K.%K > %@ AND %K.%K < %@",
                                  kAttrExpiryDate, kAttrDate, [NSDate dateWithTimeIntervalSinceReferenceDate:0],
                                  kAttrExpiryDate, kAttrDate, [TimeUtil today]];
    NSPredicate *unarchivedPredicate = [NSPredicate predicateWithFormat:@"%K == 0", kAttrIsArchived];
    NSPredicate *countPredicate = [NSPredicate predicateWithFormat:@"%K > 0", kAttrCount];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                         [NSArray arrayWithObjects:timePredicate, unarchivedPredicate, countPredicate, nil]];
    
    NSError *error;
    NSArray *queryResults = [context executeFetchRequest:request error:&error];
    if(queryResults == nil) {
        NSLog(@"Fail to get expired items");
        return nil;
    }
    
    return [NSMutableArray arrayWithArray:queryResults];
}

+ (NSArray *)getFavoriteList
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kItemBasicInfoEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"%K == 1", kAttrIsFavorite];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:kAttrLastUpdateTime ascending:NO]];
    request.resultType = NSDictionaryResultType;
    
    NSExpressionDescription* objectIdDesc = [NSExpressionDescription new];
    objectIdDesc.name = @"objectID";
    objectIdDesc.expression = [NSExpression expressionForEvaluatedObject];
    objectIdDesc.expressionResultType = NSObjectIDAttributeType;
    request.propertiesToFetch = @[objectIdDesc];
    
    NSError *error;
    NSArray *queryResults = [_mainMOC executeFetchRequest:request error:&error];
    
    return [queryResults valueForKeyPath:@"objectID"];
}
//--------------------------------------------------------------
//  [END] List related query
//==============================================================
@end
