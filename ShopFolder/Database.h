//
//  Database.h
//  ShopFolder
//
//  Created by Michael on 2011/09/29.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import "Folder.h"
#import "FolderItem.h"
#import "Barcode.h"
#import "Location.h"
#import "ShoppingItem.h"
#import "DatabaseConverter.h"

//#define kNewestDBVersion @"1.1"   //Add Location and Notes
//#define kNewestDBVersion @"1.2"   //Add individual notifications of each item
//#define kNewestDBVersion @"1.3"   //Add shopping list
#define kNewestDBVersion @"1.4"     //Migrate to CoreData

#define kDBName                     @".BuyRecord.sqlite"
#define kItemImagePrefix            @".Items"
#define kFolderImagePrefix          @".Folders"

#define kImpotedLocationKey         @"ImportedLocations"  //Same as in Defaults.plist
#define kDaySeperator               @","

#define kTableDBInfo                @"DatabaseInformation"
#define kDBInfoColumnVersion        @"Version"      //text

//========== Folder table definitions ===========
#define kTableFolder                @"Folders"
#define kFolderColumnID             @"_ID"          //int
#define kFolderColumnName           @"Name"         //text
#define kFolderColumnPage           @"Page"         //int
#define kFolderColumnNumber         @"Number"       //int
#define kFolderColumnColor          @"Color"        //blob
#define kFolderColumnImagePath      @"ImagePath"    //text(path to image)
#define kFolderColumnLockPhrase     @"LockPhrase"   //text

//========== Item table definitions ===========
#define kTableItem                  @"Items"
#define kItemColumnID               @"_ID"                  //int
#define kItemColumnName             @"Name"                 //text
#define kItemColumnBarcodeID        @"BarcodeID"            //int
#define kItemColumnImagePath        @"ImagePath"            //text(path to image)
#define kItemColumnCount            @"Count"                //int
#define kItemColumnCreateTime       @"CreateTime"           //int
#define kItemColumnExpireTime       @"ExpireTime"           //int
#define kItemColumnPrice            @"Price"                //real
#define kItemColumnFolderID         @"FolderID"             //int
#define kItemColumnLocationID       @"LocationID"           //int       //v1.1
#define kItemColumnNote             @"Note"                 //text      //v1.1
#define kItemColumnArchived         @"Archived"             //BOOL      //v1.1 (not used now)
#define kItemColumnNearExpiredDays  @"NearExpiredDays"      //text      //v1.2, days are seperated by comma, e.g."1,7,30"
//#define kItemColumnSafetyStock      @"SafeStock"          //int

//========== Item barcode definitions ===========
#define kTableBarcode               @"Barcodes"
#define kBarcodeColumnID            @"_ID"              //int
#define kBarcodeColumnBarcodeType   @"BarcodeType"      //text
#define kBarcodeColumnBarcodeData   @"BarcodeData"      //text
#define kBarcodeColumnItemName      @"ItemName"         //text
#define kBarcodeColumnItemImagePath @"ItemImagePath"    //text
#define kBarcodeColumnFolderID      @"FolderID"         //int

//========= Location table definitions (v1.1) ==========
#define kTableLocation                      @"Locations"
#define kLocationColumnID                   @"_ID"                  //int
#define kLocationColumnName                 @"Name"                 //text
#define kLocationColumnLatitude             @"Latitude"             //real
#define kLocationColumnLongitude            @"Longitude"            //real
#define kLocationColumnAltitude             @"Altitude"             //real, in Meter
#define kLocationColumnHorizontalAccuracy   @"HorizontalAccuracy"   //real, in Meter
#define kLocationColumnVerticalAccuracy     @"VerticalAccuracy"     //real, in Meter, related to altitude
#define kLocationColumnAddress              @"Address"              //text
#define kLocationColumnListPosition         @"ListPosition"         //int

//========= Shopping list definitions (v1.3) ==========
//Consider that user may delete item before shopping and future extension,
//we decide to record some of item's information
#define kTableShoppingList                  @"ShoppingList"
#define kShoppingListColumnID               @"_ID"                  //int
#define kShoppingListColumnItemName         @"ItemName"             //text
#define kShoppingListColumnItemImagePath    @"ItemImagePath"        //text
#define kShoppingListColumnOriginFolderID   @"OriginFolderID"       //int
#define kShoppingListColumnCount            @"Count"                //int
#define kShoppingListColumnListPosition     @"ListPosition"         //int, start from 0
#define kShoppingListColumnHasBought        @"HasBought"            //int
#define kShoppingListColumnPrice            @"Price"                //real

enum SortOrder_E {SortAscending, SortDecending};
@interface SortOption : NSObject {
    NSString *column;
    enum SortOrder_E order;
}

@property (nonatomic, strong) NSString *column;
@property (nonatomic, assign) enum SortOrder_E order;
@end

@interface Database : NSObject {
    //Put less thing here since this is a singleton
    NSString *__unsafe_unretained errMsg;
@private
}

@property (nonatomic, unsafe_unretained) NSString *errMsg;

+ (Database *) sharedSingleton;
- (BOOL)needToUpgradeDatabase;
- (BOOL)upgradeDatabase;
- (NSString *)currentDatabaseVersion;

//Helper APIs
- (sqlite3 *)openDB;
- (FolderItem *)getItemFromQueryResult:(sqlite3_stmt *)statement skipColumn:(NSString *)column;
- (Folder *)getFolderFromQueryResult:(sqlite3_stmt *)statement skipColumn:(NSString *)column;
- (ShoppingItem *)getShoppingItemFromQueryResult:(sqlite3_stmt *)statement skipColumn:(NSString *)skipColumnName;

//===== Folder related =====
- (BOOL) addFolder: (Folder *)folder;
- (Folder *) getFolderInPage: (int)page withNumber:(int)number;
- (Folder *) getFolderByID:(int) folderID;
- (BOOL) removeEmptyFolder: (Folder *)folder;
- (BOOL) removeFolderAndClearItems: (Folder *)folder;
- (BOOL) updateFolder:(Folder *)folder;
- (BOOL) moveFolder:(Folder *)folder toPage: (int)page withNumber:(int)number;
- (BOOL) isFolderExistInPage: (int)page withNumber:(int)number;
- (BOOL) isFolder:(Folder *)folder existedWithName: (NSString *)name;
- (BOOL) addNewPage: (int)page;
- (BOOL) removePage: (int)page;
- (BOOL) isEmptyPage: (int)page;

//===== Count related =====
- (int) totalPages;
- (int) maxPageIndex;
- (int) minPageIndex;
- (int) totalItems;
- (int) totalItemsInFolder: (Folder *)folder;
- (int) totalExpiredItemsFromToday: (int)days;    //For showing badge in springboard
- (int) totalExpiredItemsSince:(NSDate *)date;
- (int) totalExpiredItemsBefore:(NSDate *)date;
- (int) totalExpiredItemsInFolder:(Folder *)folder within:(int)days; //For showing expired count in badge of a Folder
- (int) totalNearExpiredItemsInFolder:(Folder *)folder; //For showing near-expired count in badge of a Folder
- (int) totalItemsWithImagePath: (NSString *)imagePath;
- (int) totalBarcodesWithImagePath: (NSString *)imagePath;
- (int) totalShoppingItemsWithImagePath: (NSString *)imagePath;
- (int) totalLocations;
- (int) totalShoppingItems;
- (int)numberOfItemsContainName:(NSString *)name;
- (int)numberOfItemsWithBarcode:(Barcode *)barcode;
- (int)numberOfItemsFromShoppingItem:(ShoppingItem *)shoppingItem;

//===== Item related =====
- (BOOL) addItem: (FolderItem *)item intoFolder:(Folder *)folder;
- (BOOL) removeItem: (FolderItem *)item;
- (int) removeItems: (NSMutableArray *)items;
- (BOOL) updateItem: (FolderItem *)item;
- (BOOL)updateItem: (FolderItem *)item archive:(BOOL)archived;
- (BOOL)updateItem: (FolderItem *)item count:(int)newCount;
- (BOOL)updateItem: (FolderItem *)item folderID:(int)newFolderID;
- (FolderItem *)duplicateItem:(FolderItem *)item;
- (BOOL)moveItem:(FolderItem *)item toFolder:(Folder *)folder withCount:(int)count;
- (void)deleteItemImage:(NSString *)imagePath;
- (FolderItem *)getItemByName:(NSString *)name;
- (FolderItem *)getItemByID:(int)ID;

//===== Barcode related =====
- (BOOL)isBarcodeExist:(Barcode *)barcode;
- (BOOL)addBarcode:(Barcode *)barcode;
- (BOOL)addBarcode:(Barcode *)barcode withItem:(FolderItem *)item;
- (BOOL)addBarcode:(Barcode *)barcode withFolder:(Folder *)folder;
- (Barcode *)getBarcodeOfType:(NSString *)type andData:(NSString *)data;
- (Barcode *)getBarcodeByID:(int)barcodeID;
- (int)getBarcodeIDOfType:(NSString *)type andData:(NSString *)data;
- (NSString *)getItemNameByBarcode:(Barcode *)barcode;
- (NSString *)getItemImagePathOfBarcode:(Barcode *)barcode;
- (int)getFolderIDByBarcode:(Barcode *)barcode;
- (BOOL)updateBarcode:(Barcode *)barcode withItem:(FolderItem *)item;
- (BOOL)updateBarcode:(Barcode *)barcode withFolder:(Folder *)folder;
- (Barcode *)getBarcodeOfShoppingItem:(ShoppingItem *)shoppingItem;

//===== Location related =====
- (BOOL)addLocation:(Location *)location;
- (BOOL)removeLocation:(Location *)location;
- (BOOL)removeLocationFromItem:(FolderItem *)item;
- (Location *)getLocationByName:(NSString *)name;
- (Location *)getLocationByID:(int)ID;
- (BOOL)isLocationExistWithName:(NSString *)name;
- (BOOL)isLocationExistWithID:(int)ID;
- (void)moveLocation:(Location *)location to:(int)newPosition;
- (BOOL)updateLocation:(Location *)location;
- (NSString *)getLocationNameById:(int)ID;
- (BOOL)shouldImportLocationsForCountry:(NSString *)countryCode;
- (BOOL)importLocationsInCountry:(NSString *)countryCode;

//===== Note related =====
- (BOOL)removeNoteFromItem:(FolderItem *)item;

//===== Shopping List related =====
- (ShoppingItem *)getShoppingItemFromFolderItem:(FolderItem *)item;
- (BOOL)isShoppingItemExisted:(ShoppingItem *)shoppingItem;
- (BOOL)isItemInShoppingList:(FolderItem *)item;
- (ShoppingItem *)addItemToShoppingList:(FolderItem *)item;
- (BOOL)addNewShoppingItem:(ShoppingItem *)item;
- (ShoppingItem *)getShoppintItemByID:(int)ID;
- (BOOL)removeShoppingListItem:(ShoppingItem *)shoppingItem;
- (BOOL)removeFolderItemFromShoppingList:(FolderItem *)item;
- (BOOL)updateShoppingItem:(ShoppingItem *)shoppingItem;
- (BOOL)updateShoppingItemPosition:(ShoppingItem *)shoppingItem;
- (BOOL)moveShoppingItem:(ShoppingItem *)shoppingItem to:(int)newPosition;

//===== Query lists =====
- (NSMutableArray *)getItemsByName: (NSString *)name;
- (NSMutableArray *)getItemsContainsName: (NSString *)name;
- (NSMutableArray *)getItemsHasPrefixName: (NSString *)name;
- (NSMutableArray *)getItemsByBarcode: (Barcode *)barcode;
- (NSMutableArray *)getItemsInFolder: (Folder *)folder withSortOption:(SortOption *)sortOption;
- (NSMutableArray *)getExpiredItemsInFolder: (Folder *)folder within:(int)days;
- (NSMutableArray *)getAllExpireDatesSince:(NSDate *)date isDistinct:(BOOL)distinct;
- (NSMutableArray *)getItemsHaveExpiredDayIncludeArchived:(BOOL)includeArchived;
- (NSMutableArray *)getAllLocations;
- (NSMutableArray *)getFoldersContainsItemBarcode:(Barcode *)barcode;
- (NSMutableArray *)getFoldersContainsItemName:(NSString *)name;
- (NSMutableArray *)getImagesInFolder:(Folder *)folder;
- (NSMutableArray *)getShoppingList;
- (NSMutableArray *)getItemsFromShoppingItem:(ShoppingItem *)shoppingItem;
- (NSMutableArray *)getFoldersContainsItemsRelatedToShoppingItem:(ShoppingItem *)shoppingItem;
@end
