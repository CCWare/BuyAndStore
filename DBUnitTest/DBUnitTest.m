//
//  DBUnitTest.m
//  DBUnitTest
//
//  Created by Michael on 2012/09/20.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBUnitTest.h"
#import "CoreDataDatabase.h"
#import "DBFolder+Validate.h"
#import "DBFolderItem+Validate.h"
#import "TimeUtil.h"

#define kFolder1Page    0
#define kFolder1Number  2

@interface DBUnitTest ()
- (void)_clearDatabase;
@end

@implementation DBUnitTest

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)_clearDatabase
{
    [CoreDataDatabase resetDatabase];
    STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[[CoreDataDatabase databaseURL] path]], @"Database doestn't exists");
}

- (void)_createFolderWithTwoItems
{
    [self _clearDatabase];
    NSError *error;
    
    //Create folder "SampleFolder", Position (0, 2)
    DBFolder *newFolder = [CoreDataDatabase obtainFolder];
    STAssertNotNil(newFolder, @"Fail to obtain a new folder");
    newFolder.name = @"SampleFolder";
    newFolder.page = kFolder1Page;
    newFolder.number = kFolder1Number;
    STAssertTrue([newFolder canSave], @"New folder is unable to save");
    STAssertTrue([CoreDataDatabase commitChanges:&error], @"Fail to write new folder into database");
    
    //Create item "SampleItem", count:3
    DBFolderItem *item = [CoreDataDatabase obtainFolderItem];
    STAssertNotNil(item, @"Fail to obtain a new folder item");
    
    DBItemBasicInfo *basicInfo = [CoreDataDatabase obtainItemBasicInfo];
    STAssertNotNil(basicInfo, @"Fail to obtain a new basicInfo for a new folder item");
    basicInfo.name = @"SampleItem";
    
    item.basicInfo = basicInfo;
    item.count = 3;
    item.folder = newFolder;
    item.createTime = [[TimeUtil today] timeIntervalSinceReferenceDate];
    STAssertTrue([item canSave], @"New folder item is unable to save");
    STAssertTrue([CoreDataDatabase commitChanges:&error], @"Fail to write a new folder item into database");

    //Create item with same basicInfo, count: 6
    item = [CoreDataDatabase obtainFolderItem];
    STAssertNotNil(item, @"Fail to obtain a new folder item");
    item.basicInfo = basicInfo;
    item.folder = newFolder;
    item.count = 6;
    item.createTime = [[TimeUtil yesterday] timeIntervalSinceReferenceDate];
    STAssertTrue([CoreDataDatabase commitChanges:&error], @"Fail to write a new folder item into database");
}

- (void)_testFolderAndItemCreation
{
    [self _createFolderWithTwoItems];
    
    STAssertTrue([CoreDataDatabase totalPages]==1, @"Incorrect pages");
    STAssertTrue([CoreDataDatabase totalItems]==2, @"Incorrect item count");
    
    //Positive case
    DBFolder *newFolder = [CoreDataDatabase getFolderByName:@"SampleFolder"];
    STAssertTrue([CoreDataDatabase totalItemsInFolder:newFolder]==2, @"Incorrect item count in folder");
    STAssertTrue(newFolder.page==kFolder1Page, @"Incorrect folder page");
    STAssertTrue(newFolder.number==kFolder1Number, @"Incorrect folder number");
    
    //Negative case
    DBFolder *folder = [CoreDataDatabase getFolderByName:@"SampleFolder_28949192"];
    STAssertNil(folder, @"Should not get folder with strange name");
    NSLog(@"[PASS] Create folder and item.");
}

- (void)_testFolderQuery
{
    //=== Query by page and number ===
    //Positive case
    DBFolder *folder = [CoreDataDatabase getFolderInPage:kFolder1Page withNumber:kFolder1Number];
    STAssertNotNil(folder, @"Folder not found");
    
    //Negative case
    folder = [CoreDataDatabase getFolderInPage:kFolder1Page withNumber:6];
    STAssertNil(folder, @"Should not found this folder");
    
    //=== Query by name ===
    //Positive case
    folder = [CoreDataDatabase getFolderByName:@"SampleFolder"];
    STAssertNotNil(folder, @"Folder not found");
    
    //Negative case
    folder = [CoreDataDatabase getFolderByName:@"Folder"];
    STAssertNil(folder, @"Should not found this folder");
    
    NSLog(@"[PASS] Query folder by page/number and name");
}

- (void)_testItemQuery
{
    //=== Query by getItemsByName: ===
    //Positive case
    NSMutableArray *items = [CoreDataDatabase getItemsByName:@"SampleItem"];
    if([items count] != 2) {
        STFail(@"Cannot get folder item with name SampleItem");
    }
    
    //Negative case, this method is case-sensitive
    items = [CoreDataDatabase getItemsByName:@"sampleItem"];
    if([items count] != 0) {
        STFail(@"Should not get any item with incorrect name");
    }
    
    //=== Query by getItemsContainsName:
    //Positive case
    items = [CoreDataDatabase getItemsContainsName:@"SAMPLE"];  //case insensitive test
    if([items count] != 2) {
        STFail(@"Cannot get folder item contains name SAMPLE");
    }
    
    items = [CoreDataDatabase getItemsContainsName:@"Sample"];  //Case sensitive test
    if([items count] != 2) {
        STFail(@"Cannot get folder item contains name Sample");
    }
    
    //Negative case
    items = [CoreDataDatabase getItemsByName:@"SampelItem"];    //Incorrect spelling
    if([items count] != 0) {
        STFail(@"Should not get any item with incorrect name");
    }
    
    NSLog(@"[PASS] Query items by name");
}

- (void)_testCancelUnsavedChanges
{
    [self _createFolderWithTwoItems];  //one folder and two items
    
    DBFolderItem *item = [CoreDataDatabase obtainFolderItem];
    STAssertNotNil(item, @"Fail to obtain a new folder item");
    item.basicInfo = [CoreDataDatabase getItemBasicInfoByName:@"SampleItem" shouldExcludeBarcode:NO];
    STAssertNotNil(item.basicInfo, @"Fail to obtain a common item");
    
    item.folder = [CoreDataDatabase getFolderByName:@"SampleFolder"];
    item.count = 9;
    item.createTime = [[TimeUtil yesterday] timeIntervalSinceReferenceDate];
    [CoreDataDatabase cancelUnsavedChanges];
    
    if([CoreDataDatabase totalItems] != 2) {
        STFail(@"Fail to cancelUnsavedChanges");
    }
    
    NSLog(@"[PASS] Cancel unsaved changes");
}

- (void)_testShoppingItemCreation
{
    NSError *error;
    //Create with new basicInfo
    DBShoppingItem *newShoppingItem = [CoreDataDatabase obtainShoppingItem];
    STAssertNotNil(newShoppingItem, @"Fail to obtain ShoppingItem");
    DBItemBasicInfo *newBasicInfo = [CoreDataDatabase obtainItemBasicInfo];
    STAssertNotNil(newBasicInfo, @"Fail to obtain basicInfo");
    newBasicInfo.name = @"basicInfo1";
    newShoppingItem.basicInfo = newBasicInfo;
    [CoreDataDatabase commitChanges:&error];
    STAssertTrue([CoreDataDatabase totalShoppingItems]==1, @"Fail to save new shopping item.");
    
    //Create with existed common item
    DBShoppingItem *newShoppingItem2 = [CoreDataDatabase obtainShoppingItem];
    STAssertNotNil(newShoppingItem, @"Fail to obtain ShoppingItem");
    newShoppingItem2.basicInfo = newBasicInfo;
    [CoreDataDatabase commitChanges:&error];
    STAssertTrue([CoreDataDatabase totalShoppingItems]==2, @"Fail to save new shopping item.");
    
    NSLog(@"[PASS] Shopping item creation");
}

- (void)_testItemRemove
{
    [self _createFolderWithTwoItems];
    NSMutableArray *items = [CoreDataDatabase getItemsContainsName:@"Item"];
    [CoreDataDatabase removeItems:items];
    [CoreDataDatabase commitChanges:nil];
    STAssertTrue([CoreDataDatabase totalItems]==0, @"There are items which is not removed");
    
    [self _createFolderWithTwoItems];
    DBFolder *folder = [CoreDataDatabase getFolderByName:@"SampleFolder"];
    STAssertNotNil(folder, @"Cannot get folder \"SampleFolder\"");
    [CoreDataDatabase removeFolderAndClearItems:folder];
    STAssertTrue([CoreDataDatabase totalItems]==0, @"There are items which is not removed");
    STAssertNil([CoreDataDatabase getFolderByName:@"SampleFolder"], @"Folder is not deleted");
    
    NSLog(@"[PASS] Item remove");
}

- (void)testDatabase
{
    [self _testFolderAndItemCreation];
    [self _testFolderQuery];
    [self _testItemQuery];
    [self _testCancelUnsavedChanges];
    [self _testShoppingItemCreation];
    [self _testItemRemove];
}

@end
