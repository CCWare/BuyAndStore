//
//  CoreDataDatabase.h
//  ShopFolder
//
//  Created by Michael on 2012/09/15.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DBFolder.h"
#import "DBLocation.h"
#import "DBItemBasicInfo.h"
#import "DBFolderItem.h"
#import "DBShoppingItem.h"
#import "Barcode.h"
#import "DBNotifyDate.h"
#import "PriceStatistics.h"

#define kDatabaseName       @"Store"
#define kDataBaseFileName   ([NSString stringWithFormat:@"%@.sqlite", kDatabaseName])   //needed by backup/restore
#define kDatabaseExtStorage ([NSString stringWithFormat:@".%@_SUPPORT", kDatabaseName]) //Store blobs

//DBFolder attribute names
#define kAttrPage               @"page"
#define kAttrNumber             @"number"
#define kAttrPassword           @"password"

//DBItemBasicInfo attribute names
#define kAttrName               @"name"
#define kAttrBarcodeData        @"barcodeData"
#define kAttrImageRawData       @"imageRawData"
#define kAttrFolderItems        @"folderItems"
#define kAttrShoppingItem       @"shoppingItem"
#define kAttrIsFavorite         @"isFavorite"

//DBFolderItem attribute names
#define kAttrBasicInfo          @"basicInfo"        //shared with DBShoppingItem
#define kAttrIsArchived         @"isArchived"
#define kAttrCount              @"count"            //shared with DBShoppingItem
#define kAttrCreateTime         @"createTime"
#define kAttrExpiryDate         @"expiryDate"
#define kAttrNearExpiryDates    @"nearExpiryDates"
#define kAttrPrice              @"price"
#define kAttrFolder             @"folder"
#define kAttrLocation           @"location"
#define kAttrNote               @"note"
#define kAttrLastUpdateTime     @"lastUpdateTime"
#define kAttrIsUserCreated      @"isUserCreated"

//DBLocation attribute names
#define kAttrListPosition       @"listPosition"     //shared with DBShoppingItem

//DBNotifyDate attribute names
#define kAttrDate               @"date"
#define kAttrExpireItems        @"expireItems"
#define kAttrNearExpireItems    @"nearExpireItems"

@interface CoreDataDatabase : NSObject

+ (NSURL *)databaseURL;
+ (NSURL *)externalBlobURL;
+ (NSManagedObjectContext *)getContextForCurrentThread;
+ (NSManagedObjectContext *)mainMOC;
+ (void)renewMainMOC;

+ (BOOL)needToUpgradeDatabase;
+ (BOOL)upgradeDatabase;

+ (void)resetDatabase;

/**
 *  Commit all unsaved changes into database file.
 *
 *  @param context Managed Context to save, must not be nil
 *  @param error Error reference, nil is OK.
 *  @return TRUE if success, otherwise you should check the error.
 *  @see cancelUnsavedChanges
 */
+ (BOOL)commitChanges:(NSError **)error;
+ (BOOL)commitChanges:(NSError **)error inContext:(NSManagedObjectContext *)context;

/**
 *  Cancel all unsaved changes and rollback.
 * @see commitChanges:
 */
+ (void)cancelUnsavedChanges;
+ (void)cancelUnsavedChangesInContext:(NSManagedObjectContext *)context;

+ (NSManagedObject *)getObjectByID:(NSManagedObjectID *)objectID;
+ (NSManagedObject *)getObjectByID:(NSManagedObjectID *)objectID inContext:(NSManagedObjectContext *)context;

//========= Folder Operation APIs ==========
+ (DBFolder *)obtainFolder;
+ (DBFolder *)obtainFolderInContext:(NSManagedObjectContext *)context;
+ (DBFolder *)obtainTempFolder;
+ (DBFolder *)getFolderInPage:(int)page withNumber:(int)number;
+ (DBFolder *)getFolderInPage:(int)page withNumber:(int)number inContext:(NSManagedObjectContext *)context;
+ (DBFolder *)getFolderByName:(NSString *)name;
+ (DBFolder *)getFolderByName:(NSString *)name inContext:(NSManagedObjectContext *)context;
+ (void)removeFolderAndClearItems:(DBFolder *)folder;
+ (BOOL)isEmptyPage:(int)pageNumber;

//========= Item Operation APIs ==========
+ (DBItemBasicInfo *)obtainItemBasicInfo;
+ (DBItemBasicInfo *)obtainItemBasicInfoInContext:(NSManagedObjectContext *)context;
+ (DBItemBasicInfo *)obtainTempItemBasicInfo;
+ (void)removeItemBasicInfo:(DBItemBasicInfo *)basicInfo;
+ (void)removeItemBasicInfo:(DBItemBasicInfo *)basicInfo inContext:(NSManagedObjectContext *)context;
+ (DBFolderItem *)obtainFolderItem;
+ (DBFolderItem *)obtainFolderItemInContext:(NSManagedObjectContext *)context;
+ (DBFolderItem *)obtainTempFolderItem;

+ (DBFolderItem *)obtainFolderItemFromShoppingItem:(DBShoppingItem *)shoppingItem;
+ (DBFolderItem *)obtainTempFolderItemFromShoppingItem:(DBShoppingItem *)shoppingItem;
+ (void)removeItem:(DBFolderItem *)item;
+ (void)removeItem:(DBFolderItem *)item inContext:(NSManagedObjectContext *)context;
+ (void)removeItems: (NSMutableArray *)items;

+ (DBFolderItem *)duplicateItem:(DBFolderItem *)item;
+ (void)moveItem:(DBFolderItem *)item toFolder:(DBFolder *)folder withCount:(int)count;
+ (DBItemBasicInfo *)getItemBasicInfoByName:(NSString *)name shouldExcludeBarcode:(BOOL)excludeBarcode;
+ (DBItemBasicInfo *)getItemBasicInfoByName:(NSString *)name shouldExcludeBarcode:(BOOL)excludeBarcode inContext:(NSManagedObjectContext *)context;
+ (DBItemBasicInfo *)getItemBasicInfoByBarcode:(Barcode *)barcode;
+ (DBItemBasicInfo *)getItemBasicInfoByBarcode:(Barcode *)barcode inContext:(NSManagedObjectContext *)context;
+ (PriceStatistics *)getPriceStatisticsOfBasicInfo:(DBItemBasicInfo *)basicInfo;
+ (NSDate *)getNextExpiryDateOfBasicInfo:(DBItemBasicInfo *)basicInfo;
+ (void)removeImageOnlyItemBasicInfo;

//========= Location Operation APIs ==========
+ (DBLocation *)obtainLocation;
+ (DBLocation *)obtainLocationInContext:(NSManagedObjectContext *)context;
+ (DBLocation *)obtainTempLocation;
+ (void)removeLocation:(DBLocation *)location;
+ (BOOL)isLocationExistWithName:(NSString *)name;
+ (void)moveLocation:(DBLocation *)location to:(int)newPosition;
+ (BOOL)shouldImportLocationsForCountry:(NSString *)countryCode;
+ (void)importLocationsInCountry:(NSString *)countryCode;

//========= ShoppingItem Operation APIs ==========
+ (DBShoppingItem *)obtainShoppingItem;
+ (DBShoppingItem *)obtainShoppingItemInContext:(NSManagedObjectContext *)context;
+ (DBShoppingItem *)obtainTempShoppingItem;
+ (DBShoppingItem *)getShoppingItemFromFolderItem:(DBFolderItem *)item;
+ (BOOL)isShoppingItemExisted:(DBShoppingItem *)shoppingItem;
+ (BOOL)isItemInShoppingList:(DBFolderItem *)item;
+ (void)addItemToShoppingList:(DBFolderItem *)item;
+ (void)removeShoppingItem:(DBShoppingItem *)shoppingItem updatePositionOfRestItems:(BOOL)update;
+ (void)moveShoppingItem:(DBShoppingItem *)shoppingItem to:(int)newPosition;

//========= NotifyDate APIs =========
+ (DBNotifyDate *)obtainNotifyDate;
+ (DBNotifyDate *)obtainNotifyDateInContext:(NSManagedObjectContext *)context;
+ (DBNotifyDate *)obtainTempNotifyDate;
+ (DBNotifyDate *)getNotifyDateOfDate:(NSDate *)date;
+ (DBNotifyDate *)getNotifyDateOfDate:(NSDate *)date inContext:(NSManagedObjectContext *)context;
+ (void)removeNotifyDate:(DBNotifyDate *)notifyDate;
+ (void)removeEmptyDatesInContext:(NSManagedObjectContext *)context;

//========= Query APIs ==========
+ (int)totalPages;
+ (int)totalItems;
+ (int)totalItemsInFolder:(DBFolder *)folder;

+ (int)totalExpiredItemsSince:(NSDate *)date;
+ (int)totalExpiredItemsOnDate:(NSDate *)date;
+ (int)totalExpiredItemsOnDate:(NSDate *)date inContext:(NSManagedObjectContext *)context;
+ (int)totalExpiredItemsBeforeAndIncludeDate:(NSDate *)date;
+ (int)totalExpiredItemsBeforeAndIncludeDate:(NSDate *)date inContext:(NSManagedObjectContext *)context;
+ (int)totalExpiredItemsInFolder:(DBFolder *)folder within:(int)days; //For showing expired count in badge of a Folder
+ (int)totalNearExpiredItemsInFolder:(DBFolder *)folder; //For showing near-expired count in badge of a Folder
+ (int)totalExpiredItemsOfBasicInfo:(DBItemBasicInfo *)basicInfo inFolder:(DBFolder *)folder; //For showing expired count in list
+ (int)totalNearExpiredOfBasicInfo:(DBItemBasicInfo *)basicInfo inFolder:(DBFolder *)folder; //For showing near-expired count in list
+ (int)totalExpiredItemsOfBasicInfo:(DBItemBasicInfo *)basicInfo; //For showing expired count in list
+ (int)totalNearExpiredOfBasicInfo:(DBItemBasicInfo *)basicInfo; //For showing near-expired count in list

+ (int)totalLocations;

+ (int)totalShoppingItems;
+ (int)totalShoppingItemsInContext:(NSManagedObjectContext *)context;
+ (int)numberOfItemsFromShoppingItem:(DBShoppingItem *)shoppingItem;    //For updating chart image
+ (int)numberOfFoldersWithName:(NSString *)name;
+ (int)numberOfFolderItemWithBasicInfo:(DBItemBasicInfo *)basicInfo;
+ (int)stockOfBasicInfo:(DBItemBasicInfo *)basicInfo inFolder:(DBFolder *)folder;
+ (int)stockOfBasicInfo:(DBItemBasicInfo *)basicInfo;
+ (int)totalFavorites;

// List related query
+ (NSMutableArray *)getItemsByName:(NSString *)name;
+ (NSMutableArray *)getItemsContainsName:(NSString *)name;
+ (NSArray *)getItemBasicInfosContainsName:(NSString *)name;
+ (NSMutableArray *)getItemsByBarcode:(Barcode *)barcode;
+ (NSMutableArray *)getItemsInFolder:(DBFolder *)folder sortBy:(NSString *)columnName ascending:(BOOL)isAscending;
+ (NSMutableArray *)getItemsHaveExpiredDayIncludeArchived:(BOOL)includeArchived;
+ (NSMutableArray *)getAllLocations;
+ (NSArray *)getFoldersContainsItemBarcode:(Barcode *)barcode;
+ (NSArray *)getFoldersContainsItemName:(NSString *)name;
+ (NSArray *)getFoldersContainsBasicInfo:(DBItemBasicInfo *)basicInfo;
+ (NSMutableArray *)getShoppingList;
+ (NSMutableArray *)getItemsFromShoppingItem:(DBShoppingItem *)shoppingItem;
+ (NSMutableArray *)getFoldersContainsItemsRelatedToShoppingItem:(DBShoppingItem *)shoppingItem;
+ (NSArray *)getImagesOfExpiredItemsInFolder:(DBFolder *)folder; //returns objectIDs of basicInfo of expired items
+ (NSArray *)getBasicInfosInFolder:(DBFolder *)folder;
+ (NSArray *)getBasicInfoIDsWithImageInFolder:(DBFolder *)folder;   //Returns objectIDs of DBItemBasicInfo
+ (NSArray *)getFolderItemsWithBasicInfo:(DBItemBasicInfo *)basicInfo inFolder:(DBFolder *)folder;

+ (NSMutableArray *)getNotifyDatesWithinDaysFromToday:(int)days;
+ (NSMutableArray *)getNotifyDatesWithinDaysFromToday:(int)days inContext:(NSManagedObjectContext *)context;

+ (NSMutableArray *)getExpiredItemsBeforeToday;
+ (NSMutableArray *)getExpiredItemsBeforeTodayInContext:(NSManagedObjectContext *)context;

+ (NSArray *)getFavoriteList;    //returns objectIDs of basicInfo which are favorite
@end
