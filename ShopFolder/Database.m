//
//  Database.m
//  ShopFolder
//
//  Created by Michael on 2011/09/29.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import "Database.h"
#import "TimeUtil.h"
#import "StringUtil.h"
#import "VersionCompare.h"
#import "NotificationConstant.h"
#import "PreferenceConstant.h"

@interface Database ()
- (id) init;
- (int) _getFolderIdByName: (NSString *)name;
@end

@implementation SortOption
@synthesize column;
@synthesize order;

@end

@implementation Database
@synthesize errMsg;

static Database *gInstance = nil;
static NSString *gDatabasePath = nil;

+ (Database *) sharedSingleton
{
    //gInstance has been initialized in initialize: with thread safe manner and once.
    return gInstance;
}

+ (void) initialize
{
    if(self == [Database class]) {
        if(!gInstance ) {
            gInstance = [[Database alloc] init];
        }
    }
}

- (sqlite3 *)openDB
{
    sqlite3 *db = NULL;
    if(sqlite3_open([gDatabasePath UTF8String], &db) != SQLITE_OK) {
        sqlite3_close(db);
        db = NULL;
        errMsg = [NSString stringWithFormat:@"Fail to open database: %@", gDatabasePath];
        NSLog(@"%@", errMsg);
    }
    
    return db;
}

- (id) init
{
    if((self = [super init])) {
        if(!gDatabasePath) {
            //If old DB exists, move it to new one
            NSError *error = nil;
            NSString *oldPath = [StringUtil fullPathInDocument:@"ShopFolder.sqlite"];
            NSString *newPath = [StringUtil fullPathInDocument:kDBName];
            if([[NSFileManager defaultManager] fileExistsAtPath:oldPath] &&
               ![[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&error])
            {
                NSLog(@">> Error(1) << %@", [error localizedDescription]);
            }
            
            //Move folders
            oldPath = [StringUtil fullPathInDocument:@"Items"];
            newPath = [StringUtil fullPathInDocument:kItemImagePrefix];
            if([[NSFileManager defaultManager] fileExistsAtPath:oldPath]) {
                if(![[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&error]) {
                    NSLog(@">> Error(2) << %@", [error localizedDescription]);
                }
            } else {
                [[NSFileManager defaultManager] createDirectoryAtPath:[StringUtil fullPathInDocument:kItemImagePrefix]
                                          withIntermediateDirectories:YES attributes:nil error:NULL];
            }
            
            oldPath = [StringUtil fullPathInDocument:@"Folders"];
            newPath = [StringUtil fullPathInDocument:kFolderImagePrefix];
            if([[NSFileManager defaultManager] fileExistsAtPath:oldPath]) {
                if(![[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&error]) {
                    NSLog(@">> Error(3) << %@", [error localizedDescription]);
                }
            } else {
                [[NSFileManager defaultManager] createDirectoryAtPath:[StringUtil fullPathInDocument:kFolderImagePrefix]
                                          withIntermediateDirectories:YES attributes:nil error:NULL];
            }

            gDatabasePath = [StringUtil fullPathInDocument:kDBName];
        }

        sqlite3 *db = [self openDB];
        if(db) {
            char *strErrMsg;
            NSString *command = nil;
            
            //Create Folder table
            command = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT, %@ TEXT UNIQUE, %@ INT, %@ INT, %@ BLOB, %@ TEXT, %@ TEXT);", kTableFolder, kFolderColumnID, kFolderColumnName, kFolderColumnPage, kFolderColumnNumber, kFolderColumnColor, kFolderColumnImagePath, kFolderColumnLockPhrase];

            if(sqlite3_exec(db, [command UTF8String], NULL, NULL, &strErrMsg) != SQLITE_OK) {
                NSLog(@"Fail to create Folder table: %s", strErrMsg);
            }
            
            //Create Item table
            command = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT, %@ TEXT, %@ INT, %@ TEXT, %@ INT, %@ REAL, %@ REAL, %@ REAL, %@ INT, %@ INT, %@ TEXT, %@ INT, %@ TEXT);", kTableItem, kItemColumnID, kItemColumnName, kItemColumnBarcodeID, kItemColumnImagePath, kItemColumnCount, kItemColumnCreateTime, kItemColumnExpireTime, kItemColumnPrice, kItemColumnFolderID, kItemColumnLocationID, kItemColumnNote, kItemColumnArchived, kItemColumnNearExpiredDays];

            if(sqlite3_exec(db, [command UTF8String], NULL, NULL, &strErrMsg) != SQLITE_OK) {
                NSLog(@"Fail to create Item table: %s", strErrMsg);
            }
            
            //Create Barcode table
            command = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT, %@ TEXT, %@ TEXT, %@ TEXT,  %@ TEXT, %@ INT);", kTableBarcode, kBarcodeColumnID, kBarcodeColumnBarcodeType, kBarcodeColumnBarcodeData, kBarcodeColumnItemName, kBarcodeColumnItemImagePath, kBarcodeColumnFolderID];
            
            if(sqlite3_exec(db, [command UTF8String], NULL, NULL, &strErrMsg) != SQLITE_OK) {
                NSLog(@"Fail to create Barcode table: %s", strErrMsg);
            }
            
            //Create Location table
            command = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT, %@ TEXT, %@ REAL, %@ REAL, %@ REAL, %@ REAL, %@ REAL, %@ TEXT, %@ INT);", kTableLocation, kLocationColumnID, kLocationColumnName, kLocationColumnLatitude, kLocationColumnLongitude, kLocationColumnAltitude, kLocationColumnHorizontalAccuracy, kLocationColumnVerticalAccuracy, kLocationColumnAddress, kLocationColumnListPosition];

            if(sqlite3_exec(db, [command UTF8String], NULL, NULL, &strErrMsg) != SQLITE_OK) {
                NSLog(@"Fail to create Location table: %s", strErrMsg);
            }

            //Create DBInfo table
            command = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@ TEXT UNIQUE);", kTableDBInfo, kDBInfoColumnVersion];
            if(sqlite3_exec(db, [command UTF8String], NULL, NULL, &strErrMsg) != SQLITE_OK) {
                NSLog(@"Fail to create DBInfo table: %s", strErrMsg);
            }
            
            //Create Shopping List table
            command = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT, %@ TEXT, %@ TEXT, %@ INT, %@ INT, %@ INT, %@ INT, %@ REAL);", kTableShoppingList, kShoppingListColumnID, kShoppingListColumnItemName, kShoppingListColumnItemImagePath, kShoppingListColumnOriginFolderID, kShoppingListColumnCount, kShoppingListColumnListPosition, kShoppingListColumnHasBought, kShoppingListColumnPrice];
            
            if(sqlite3_exec(db, [command UTF8String], NULL, NULL, &strErrMsg) != SQLITE_OK) {
                NSLog(@"Fail to create ShoppingList table: %s", strErrMsg);
            }
            
            sqlite3_close(db);
        }
    }

    return self;
}

- (NSString *)currentDatabaseVersion
{
    @synchronized(self) {
        NSString *currentVersion = nil;
        sqlite3 *db = [self openDB];
        if(db) {
            sqlite3_stmt *statement = NULL;
            NSString *command = [NSString stringWithFormat:@"SELECT %@ FROM %@;", kDBInfoColumnVersion, kTableDBInfo];
            
            if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                char *strVer = NULL;
                while(sqlite3_step(statement) == SQLITE_ROW) {
                    strVer = (char *)sqlite3_column_text(statement, 0);
                    break;
                }
                
                if(strVer != NULL) {
                    currentVersion = [NSString stringWithCString:strVer encoding:NSUTF8StringEncoding];
                    sqlite3_finalize(statement);
                } else {
                    sqlite3_finalize(statement);
                    
                    //Check if DB is 1.3
                    if(!currentVersion) {
                        command = [NSString stringWithFormat:@"SELECT %@ FROM %@", kShoppingListColumnID, kTableShoppingList];
                        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                            currentVersion = @"1.3";
                            sqlite3_finalize(statement);
                        }
                    }
                    
                    //Check if DB is 1.2
                    if(!currentVersion) {
                        command = [NSString stringWithFormat:@"SELECT %@ FROM %@", kItemColumnNearExpiredDays, kTableItem];
                        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                            currentVersion = @"1.2";
                            sqlite3_finalize(statement);
                        }
                    }
                    
                    //Check if DB is 1.1
                    if(!currentVersion) {
                        command = [NSString stringWithFormat:@"SELECT %@ FROM %@", kItemColumnLocationID, kTableItem];
                        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                            currentVersion = @"1.1";
                            sqlite3_finalize(statement);
                        }
                    }
                    
                    if(!currentVersion) {
                        currentVersion = @"1.0";
                    }
                    
                    command = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (?);", kTableDBInfo, kDBInfoColumnVersion];
                    if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                        sqlite3_bind_text(statement, 1, [currentVersion UTF8String], -1, NULL);
                        if(sqlite3_step(statement) != SQLITE_DONE) {
                            NSLog(@"Fail to set database version to %@", currentVersion);
                        }
                        sqlite3_finalize(statement);
                    }
                }
            }
        }
        
        return currentVersion;
    }
}

- (BOOL)needToUpgradeDatabase
{
    @synchronized(self) {
        NSString *currentVersion = [self currentDatabaseVersion];
        if([VersionCompare compareVersion:currentVersion toVersion:kNewestDBVersion] == NSOrderedAscending) {
            return YES;
        }
        
        return NO;
    }
}

- (BOOL)upgradeDatabase
{
    NSString *currentVersion = [self currentDatabaseVersion];
    
    if([VersionCompare compareVersion:currentVersion toVersion:kNewestDBVersion] != NSOrderedAscending) {
        return YES;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        BOOL isSuccess = YES;
        if(db) {
            char *strErrMsg;
            sqlite3_stmt *statement = NULL;
            NSString *command = nil;

            //Upgrade to 1.1
            if([VersionCompare compareVersion:currentVersion toVersion:@"1.1"] == NSOrderedAscending) {
                //Add location Table & add Location and Note column to item table
                
                //1. Add location table
                command = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT, %@ TEXT, %@ REAL, %@ REAL, %@ REAL, %@ REAL, %@ REAL, %@ TEXT);", kTableLocation, kLocationColumnID, kLocationColumnName, kLocationColumnLatitude, kLocationColumnLongitude, kLocationColumnAltitude, kLocationColumnHorizontalAccuracy, kLocationColumnVerticalAccuracy, kLocationColumnAddress];
                
                if(sqlite3_exec(db, [command UTF8String], NULL, NULL, &strErrMsg) != SQLITE_OK) {
                    NSLog(@"Fail to create Location table: %s", strErrMsg);
                }
                
                //2. Add location column to item table
                command = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ INT;", kTableItem, kItemColumnLocationID];
                if(sqlite3_exec(db, [command UTF8String], NULL, NULL, &strErrMsg) != SQLITE_OK) {
                    NSLog(@"Fail to add column %@ to table %@, error: %s", kItemColumnLocationID, kTableItem, strErrMsg);
                }
                
                //3. Add Note column to item table
                command = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT;", kTableItem, kItemColumnNote];
                if(sqlite3_exec(db, [command UTF8String], NULL, NULL, &strErrMsg) != SQLITE_OK) {
                    NSLog(@"Fail to add column %@ to table %@, error: %s", kItemColumnNote, kTableItem, strErrMsg);
                }
                
                //4. Add Archived column to item table
                command = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ BOOL;", kTableItem, kItemColumnArchived];
                if(sqlite3_exec(db, [command UTF8String], NULL, NULL, &strErrMsg) != SQLITE_OK) {
                    NSLog(@"Fail to add column %@ to table %@, error: %s", kItemColumnArchived, kTableItem, strErrMsg);
                }
            }
            
            //Upgrade to 1.2
            if([VersionCompare compareVersion:currentVersion toVersion:@"1.2"] == NSOrderedAscending) {
                //1. Add near-expired days to item table
                command = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT;", kTableItem, kItemColumnNearExpiredDays];
                if(sqlite3_exec(db, [command UTF8String], NULL, NULL, &strErrMsg) != SQLITE_OK) {
                    NSLog(@"Fail to add column %@ to table %@, error: %s", kItemColumnNearExpiredDays, kTableItem, strErrMsg);
                }
                
                //2. Init near expired days
                const int NEAR_EXPIRE_DAYS = [[NSUserDefaults standardUserDefaults] integerForKey:kSettingNearExpiredDays];
                NSMutableArray *expItems = [self getItemsHaveExpiredDayIncludeArchived:YES];
                for(FolderItem *item in expItems) {
                    item.nearExpiredDays = [NSMutableArray arrayWithObject:[NSNumber numberWithInt:NEAR_EXPIRE_DAYS]];
                    command = [NSString stringWithFormat:@"UPDATE %@ SET %@=%d WHERE %@>0", kTableItem, kItemColumnNearExpiredDays, 
                               NEAR_EXPIRE_DAYS, kItemColumnExpireTime];
                    if(sqlite3_exec(db, [command UTF8String], NULL, NULL, &strErrMsg) != SQLITE_OK) {
                        NSLog(@"Fail to update item table: %s", strErrMsg);
                    }
                }
                
                //3. Update image paths
                //3.1 Remove /Items/ from imagePath of items
                sqlite3_stmt *updateStatement = NULL;
                char *strTextResult;
                int nID = 0;
                NSString *imagePath;
                NSUInteger oldFolderLength = [@"/Items/" length];
                
                command = [NSString stringWithFormat:@"SELECT %@,%@ FROM %@ WHERE %@ NOT NULL;",
                           kItemColumnID, kItemColumnImagePath, kTableItem, kItemColumnImagePath];
                if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                    while(sqlite3_step(statement) == SQLITE_ROW) {
                        for(int column = sqlite3_column_count(statement) - 1; column >= 0; column--) {
                            NSString *columnName = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, column)];
                            if([columnName isEqualToString: kItemColumnID]) {
                                nID = sqlite3_column_int(statement, column);
                            } else if([columnName isEqualToString: kItemColumnImagePath]) {
                                strTextResult = (char *)sqlite3_column_text(statement, column);
                                if(strTextResult) {
                                    imagePath = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
                                }
                            }
                        }
                        
                        if([imagePath length] > 0) {
                            if([imagePath hasPrefix:@"/Items/"]) {
                                imagePath = [imagePath substringFromIndex:oldFolderLength];
                                
                                command = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?",
                                           kTableItem, kItemColumnImagePath, kItemColumnID];
                                if(sqlite3_prepare_v2(db, [command UTF8String], -1, &updateStatement, nil) == SQLITE_OK) {
                                    sqlite3_bind_text(updateStatement, 1, [imagePath UTF8String], -1, NULL);
                                    sqlite3_bind_int(updateStatement, 2, nID);
                                    
                                    if(sqlite3_step(updateStatement) != SQLITE_DONE) {
                                        NSLog(@"Fail to rename image path for ID %d", nID);
                                    }
                                    sqlite3_finalize(updateStatement);
                                }
                            }
                        } else {
                            NSLog(@">>Error<< Get empty item image path");
                        }
                    }
                    sqlite3_finalize(statement);
                }
                
                //3.2 Remove /Folders/ from imagePath of folders
                oldFolderLength = [@"/Folders/" length];
                command = [NSString stringWithFormat:@"SELECT %@,%@ FROM %@ WHERE %@ NOT NULL;",
                           kFolderColumnID, kFolderColumnImagePath, kTableFolder, kFolderColumnImagePath];
                if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                    while(sqlite3_step(statement) == SQLITE_ROW) {
                        for(int column = sqlite3_column_count(statement) - 1; column >= 0; column--) {
                            NSString *columnName = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, column)];
                            if([columnName isEqualToString: kFolderColumnID]) {
                                nID = sqlite3_column_int(statement, column);
                            } else if([columnName isEqualToString: kFolderColumnImagePath]) {
                                strTextResult = (char *)sqlite3_column_text(statement, column);
                                if(strTextResult) {
                                    imagePath = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
                                }
                            }
                        }
                        
                        if([imagePath length] > 0) {
                            if([imagePath hasPrefix:@"/Folders/"]) {
                                imagePath = [imagePath substringFromIndex:oldFolderLength];
                                
                                command = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?",
                                           kTableFolder, kFolderColumnImagePath, kFolderColumnID];
                                if(sqlite3_prepare_v2(db, [command UTF8String], -1, &updateStatement, nil) == SQLITE_OK) {
                                    sqlite3_bind_text(updateStatement, 1, [imagePath UTF8String], -1, NULL);
                                    sqlite3_bind_int(updateStatement, 2, nID);
                                    
                                    if(sqlite3_step(updateStatement) != SQLITE_DONE) {
                                        NSLog(@"Fail to rename image path of folder ID %d", nID);
                                    }
                                    sqlite3_finalize(updateStatement);
                                }
                            }
                        } else {
                            NSLog(@">>Error<< Get empty folder image path");
                        }
                    }
                    sqlite3_finalize(statement);
                }
                
                //3.3 Remove /Items/ from imagePath of barcodes
                oldFolderLength = [@"/Items/" length];
                command = [NSString stringWithFormat:@"SELECT %@,%@ FROM %@ WHERE %@ NOT NULL;",
                           kBarcodeColumnID, kBarcodeColumnItemImagePath, kTableBarcode, kBarcodeColumnItemImagePath];
                if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                    while(sqlite3_step(statement) == SQLITE_ROW) {
                        for(int column = sqlite3_column_count(statement) - 1; column >= 0; column--) {
                            NSString *columnName = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, column)];
                            if([columnName isEqualToString: kBarcodeColumnID]) {
                                nID = sqlite3_column_int(statement, column);
                            } else if([columnName isEqualToString: kBarcodeColumnItemImagePath]) {
                                strTextResult = (char *)sqlite3_column_text(statement, column);
                                if(strTextResult) {
                                    imagePath = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
                                }
                            }
                        }
                        
                        if([imagePath length] > 0) {
                            if([imagePath hasPrefix:@"/Items/"]) {
                                imagePath = [imagePath substringFromIndex:oldFolderLength];
                                
                                command = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?",
                                           kTableBarcode, kBarcodeColumnItemImagePath, kBarcodeColumnID];
                                if(sqlite3_prepare_v2(db, [command UTF8String], -1, &updateStatement, nil) == SQLITE_OK) {
                                    sqlite3_bind_text(updateStatement, 1, [imagePath UTF8String], -1, NULL);
                                    sqlite3_bind_int(updateStatement, 2, nID);
                                    
                                    if(sqlite3_step(updateStatement) != SQLITE_DONE) {
                                        NSLog(@"Fail to rename image path of barcode ID %d", nID);
                                    }
                                    sqlite3_finalize(updateStatement);
                                }
                            }
                        } else {
                            NSLog(@">>Error<< Get empty barcode image path");
                        }
                    }
                    sqlite3_finalize(statement);
                }
            }
            
            //Upgrade to 1.3
            if([VersionCompare compareVersion:currentVersion toVersion:@"1.3"] == NSOrderedAscending) {
                command = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT, %@ TEXT, %@ TEXT, %@ INT, %@ INT, %@ INT, %@ INT, %@ REAL);", kTableShoppingList, kShoppingListColumnID, kShoppingListColumnItemName, kShoppingListColumnItemImagePath, kShoppingListColumnOriginFolderID, kShoppingListColumnCount, kShoppingListColumnListPosition, kShoppingListColumnHasBought, kShoppingListColumnPrice];
                
                if(sqlite3_exec(db, [command UTF8String], NULL, NULL, &strErrMsg) != SQLITE_OK) {
                    NSLog(@"Fail to create ShoppingList table: %s", strErrMsg);
                }
            }
            
            //Update database version
            //No longer needed since we'll move database to tmp if upgrading is successful
//            command = [NSString stringWithFormat:@"UPDATE %@ SET %@=?;", kTableDBInfo, kDBInfoColumnVersion];
//            if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
//                sqlite3_bind_text(statement, 1, [kNewestDBVersion UTF8String], -1, NULL);
//                if(sqlite3_step(statement) == SQLITE_DONE) {
//                    NSLog(@"Success to update database from %@ to %@", currentVersion, kNewestDBVersion);
//                } else {
//                    NSLog(@"Fail to update database from %@ to %@", currentVersion, kNewestDBVersion);
//                    isSuccess = NO;
//                }
//                sqlite3_finalize(statement);
//            }
            
            sqlite3_close(db);
            
            //Upgrade to 1.4, using Core Data
            //Close Database before upgrading to 1.4, otherwise it will create the DB file
            if([VersionCompare compareVersion:currentVersion toVersion:@"1.4"] == NSOrderedAscending) {
                DatabaseConverter *converer = [DatabaseConverter new];
                isSuccess = [converer convertDatabase];
            }
        }
        
        return isSuccess;
    }
}

- (void)deleteItemImage:(NSString *)imagePath
{
    if([imagePath length] > 0) {
        if([self totalItemsWithImagePath:imagePath] > 0) {
//            NSLog(@"Skip to delete item image: still used by other items");
        } else if([self totalBarcodesWithImagePath:imagePath] > 0) {
//            NSLog(@"Skip to delete item image: still used by barcode");
        } else if([self totalShoppingItemsWithImagePath:imagePath] > 0) {
            
        } else {
            if([[NSFileManager defaultManager] removeItemAtPath:[StringUtil fullPathOfItemImage:imagePath] error:NULL]) {
//                NSLog(@"Delete unsed item image %@", item.imagePath);
            } else {
                NSLog(@"Fail to delete item image: %@", imagePath);
            }
        }
    }
}

- (FolderItem *)getItemByName:(NSString *)name
{
    if([name length] == 0) {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        FolderItem *item = nil;
        
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=? LIMIT 1;", kTableItem, kItemColumnName];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [name UTF8String], -1, NULL);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                item = [self getItemFromQueryResult:statement skipColumn:kItemColumnName];
                item.name = name;
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        //Caller must retain or copy this
        return item;
    }
}

- (FolderItem *)getItemByID:(int)ID
{
    if(ID <= 0) {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        FolderItem *item = nil;
        
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=? LIMIT 1;", kTableItem, kItemColumnID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, ID);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                item = [self getItemFromQueryResult:statement skipColumn:kItemColumnID];
                item.ID = ID;
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        //Caller must retain or copy this
        return item;
    }
}

//===========================================================
//  Folder Operatoins
#pragma mark -
#pragma mark Folder Operatoins
//===========================================================
- (int) _getFolderIdByName: (NSString *)name
{
    int folderID = -1;
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return folderID;
        }

        sqlite3_stmt *statement = NULL;
        NSString *command = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@=?;", kFolderColumnID, kTableFolder, kFolderColumnName];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [name UTF8String], -1, NULL);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                folderID = sqlite3_column_int(statement, 0);
            }
        }
        
        sqlite3_finalize(statement);
        sqlite3_close(db);
        
        return folderID;
    }
}

- (Folder *)getFolderFromQueryResult:(sqlite3_stmt *)statement skipColumn:(NSString *)skipColumnName
{
    if(statement == NULL) {
        return nil;
    }
    
    
    Folder *folder = [[Folder alloc] init];
    
    char *strTextResult = NULL;
    for(int column = sqlite3_column_count(statement) - 1; column >= 0; column--) {
        if(sqlite3_column_bytes(statement, column) == 0) {
//            NSLog(@"Skip empty column: %s", sqlite3_column_name(statement, column));
            continue;
        }
        
        NSString *columnName = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, column)];
        if([columnName isEqualToString:skipColumnName]) {
            continue;
        }
        
        if([columnName isEqualToString: kFolderColumnID]) {
            folder.ID = sqlite3_column_int(statement, column);
        } else if([columnName isEqualToString: kFolderColumnName]) {
            strTextResult = (char *)sqlite3_column_text(statement, column);
            if(strTextResult) {
                folder.name = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
            }
        } else if([columnName isEqualToString: kFolderColumnPage]) {
            folder.page = sqlite3_column_int(statement, column);
        } else if([columnName isEqualToString: kFolderColumnNumber]) {
            folder.number = sqlite3_column_int(statement, column);
        } else if([columnName isEqualToString: kFolderColumnColor]) {
            NSData *colorData = [[NSData alloc] initWithBytes:sqlite3_column_blob(statement, column)
                                                       length:sqlite3_column_bytes(statement, column)];
            folder.color = [NSKeyedUnarchiver unarchiveObjectWithData:colorData];
        } else if([columnName isEqualToString: kFolderColumnImagePath]) {
            strTextResult = (char *)sqlite3_column_text(statement, column);
            if(strTextResult) {
                folder.imagePath = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
            }
            
            if(folder.imagePath) {
                folder.image = [UIImage imageWithContentsOfFile:folder.imagePath];
            }
        } else if([columnName isEqualToString: kFolderColumnLockPhrase]) {
            strTextResult = (char *)sqlite3_column_text(statement, column);
            if(strTextResult) {
                folder.lockPhrease = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
            }
        }

    }
    
    return folder;
}

- (BOOL) addFolder: (Folder *)folder
{
    if(!folder) {
        return NO;
    }
    
    if([self isFolderExistInPage:folder.page withNumber:folder.number]) {
        errMsg = [NSString stringWithFormat:@"Fail to add folder: folder exists in (%d, %d)", folder.page, folder.number];
        NSLog(@"%@", errMsg);
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }

        sqlite3_stmt *statement = NULL;
        NSString *command = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@, %@, %@, %@) VALUES (?, ?, ?, ?, ?, ?);",
                   kTableFolder, kFolderColumnName, kFolderColumnPage, kFolderColumnNumber, kFolderColumnColor, kFolderColumnImagePath, kFolderColumnLockPhrase];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [folder.name UTF8String], -1, NULL);
            sqlite3_bind_int(statement, 2, folder.page);
            sqlite3_bind_int(statement, 3, folder.number);
            
            NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:folder.color];
            if([colorData length] > 0) {
                sqlite3_bind_blob(statement, 4, [colorData bytes], [colorData length], NULL);
            } else {
                sqlite3_bind_blob(statement, 4, nil, -1, NULL);
            }

            sqlite3_bind_text(statement, 5, [folder.imagePath UTF8String], -1, NULL);
            sqlite3_bind_text(statement, 6, [folder.lockPhrease UTF8String], -1, NULL);
        }
        
        BOOL success = NO;
        if(sqlite3_step(statement) == SQLITE_DONE) {
            success = YES;
            folder.ID = sqlite3_last_insert_rowid(db);
        } else {
            errMsg = [NSString stringWithFormat:@"Fail to add new folder: %s", sqlite3_errmsg(db)];
            NSLog(@"%@", errMsg);
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);
        
        return success;
    }
}

- (Folder *) getFolderInPage: (int)page withNumber:(int)number
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }

        sqlite3_stmt *statement = NULL;
        Folder *folder = nil;
        
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=? AND %@=?;",
                             kTableFolder, kFolderColumnPage,  kFolderColumnNumber];

        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, page);
            sqlite3_bind_int(statement, 2, number);

            while(sqlite3_step(statement) == SQLITE_ROW) {
                folder = [self getFolderFromQueryResult:statement skipColumn:nil];
                folder.page = page;
                folder.number = number;
            }

            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        //Caller must retain or copy this
        return folder;
    }
}

- (Folder *) getFolderByID:(int) folderID
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        Folder *folder = nil;
        
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=?;", kTableFolder,  kFolderColumnID];
        
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, folderID);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                folder = [self getFolderFromQueryResult:statement skipColumn:nil];
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        //Caller must retain or copy this
        return folder;
    }
}

- (BOOL) removeEmptyFolder: (Folder *)folder
{
    if(!folder) {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }

        BOOL success = NO;
        sqlite3_stmt *statement = NULL;
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=?;", kTableItem, kItemColumnFolderID];
        BOOL folderIsEmpty = NO;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, folder.ID);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                folderIsEmpty = (sqlite3_column_int(statement, 0) == 0) ? YES : NO;
            }
            sqlite3_finalize(statement);
        }
        
        if(!folderIsEmpty) {
            errMsg = @"Fail to remove empty folder: folder is not empty";
            NSLog(@"%@", errMsg);
        } else {
            command = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=?;", kTableFolder, kFolderColumnID];
            if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                sqlite3_bind_int(statement, 1, folder.ID);
                
                if(sqlite3_step(statement) == SQLITE_DONE) {
                    success = YES;
                } else {
                    errMsg = [NSString stringWithFormat:@"Fail to remove empty folder: %s", sqlite3_errmsg(db)];
                    NSLog(@"%@", errMsg);
                }
                
                sqlite3_finalize(statement);
            }
        }

        sqlite3_close(db);
        return success;
    }
}

- (BOOL) removeFolderAndClearItems: (Folder *)folder
{
    if(!folder) {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }

        BOOL success = NO;
        sqlite3_stmt *statement = NULL;
        
        NSMutableArray *itemList = [self getItemsInFolder:folder withSortOption:nil];
        
        //1. Remove all items in the folder
        NSString *command = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=?;", kTableItem, kItemColumnFolderID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, folder.ID);
           
            if(sqlite3_step(statement) == SQLITE_DONE) {
#ifdef DEBUG
                NSLog(@"Remove %d items in folder %@", sqlite3_total_changes(db), folder.name);
#endif
                success = YES;
            }
            
            sqlite3_finalize(statement);
        }
        
        //2. If items are deleted, continue to delete the folder
        if(success) {
            for(FolderItem *item in itemList) {
                //Delete unused(item or barcode) image
                [self deleteItemImage:item.imagePath];
            }

            command = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=?;", kTableFolder, kFolderColumnID];
            if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                sqlite3_bind_int(statement, 1, folder.ID);

                if(sqlite3_step(statement) == SQLITE_ERROR) {
                    success = NO;
                    errMsg = [NSString stringWithFormat:@"Fail to clear folder: %s", sqlite3_errmsg(db)];
                }

                sqlite3_finalize(statement);
            }
            
            //Delete unused folder image
            if([folder.imagePath length] > 0) {
                if([[NSFileManager defaultManager] removeItemAtPath:[StringUtil fullPathOfFolderImage:folder.imagePath] error:NULL]) {
                    NSLog(@"Delete unsed folder image %@", folder.imagePath);
                } else {
                    NSLog(@"Fail to delete folder image: %@", folder.imagePath);
                }
            }
        }
        
        return success;
    }
}

- (BOOL) updateFolder:(Folder *)folder
{
    if(!folder) {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }

        sqlite3_stmt *statement = NULL;
        
        BOOL success = NO;
        int nBindColumn = 1;
        NSString *command = [NSString stringWithFormat:@"UPDATE %@ SET %@=?, %@=?, %@=?, %@=?, %@=?, %@=? WHERE %@=?;",
                             kTableFolder, kFolderColumnName, kFolderColumnPage, kFolderColumnNumber, kFolderColumnColor, kFolderColumnImagePath, kFolderColumnLockPhrase, kFolderColumnID];
        
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, nBindColumn++, [folder.name UTF8String], -1, NULL);
            sqlite3_bind_int(statement, nBindColumn++, folder.page);
            sqlite3_bind_int(statement, nBindColumn++, folder.number);
            
            NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:folder.color];
            if([colorData length] > 0) {
                sqlite3_bind_blob(statement, nBindColumn++, [colorData bytes], [colorData length], NULL);
            } else {
                sqlite3_bind_blob(statement, nBindColumn++, nil, -1, NULL);
            }
            
            sqlite3_bind_text(statement, nBindColumn++, [folder.imagePath UTF8String], -1, NULL);
            sqlite3_bind_text(statement, nBindColumn++, [folder.lockPhrease UTF8String], -1, NULL);
            
            sqlite3_bind_int(statement, nBindColumn++, folder.ID);
            
            int nLastChanges = 0;
            if(sqlite3_step(statement) == SQLITE_DONE &&
               (nLastChanges = sqlite3_total_changes(db)) == 1)
            {
                success = YES;
            } else {
                if(nLastChanges != 1) {
                    errMsg = [NSString stringWithFormat:@"Fail to update folder: %d changes", nLastChanges];
                } else {
                    errMsg = [NSString stringWithFormat:@"Fail to update folder: %s", sqlite3_errmsg(db)];
                }
                
                NSLog(@"%@", errMsg);
            }
            sqlite3_finalize(statement);
        }

        sqlite3_close(db);
        
        return success;
    }
}

- (BOOL) moveFolder:(Folder *)folder toPage: (int)page withNumber:(int)number
{
    if(!folder) {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }

        sqlite3_stmt *statement = NULL;
        
        BOOL success = NO;
        NSString *command = [NSString stringWithFormat:@"UPDATE %@ SET %@=?, %@=? WHERE %@=?;", kTableFolder, kFolderColumnPage, kFolderColumnNumber, kFolderColumnID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, page);
            sqlite3_bind_int(statement, 2, number);
            sqlite3_bind_int(statement, 3, folder.ID);

            int nLastChanges = 0;
            if(sqlite3_step(statement) == SQLITE_DONE &&
               (nLastChanges = sqlite3_total_changes(db)) == 1)
            {
                success = YES;
                folder.page = page;
                folder.number = number;
            } else {
                if(nLastChanges != 1) {
                    errMsg = [NSString stringWithFormat:@"Fail to update folder: %d changes", nLastChanges];
                } else {
                    errMsg = [NSString stringWithFormat:@"Fail to update folder: %s", sqlite3_errmsg(db)];
                }
                
                NSLog(@"%@", errMsg);
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        return success;
    }
}

- (BOOL) removePage: (int)page
{
    if(page < 0) {
        return NO;
    }
    
    if(![self isEmptyPage:page]) {
        NSLog(@"Cannot remove non-empty page");
        return NO;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        
        BOOL success = NO;
        NSString *command = [NSString stringWithFormat:@"UPDATE %@ SET %@=%@-1 WHERE %@>=?;", kTableFolder, kFolderColumnPage, kFolderColumnPage, kFolderColumnPage];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, page);
            
            if(sqlite3_step(statement) == SQLITE_DONE) {
                success = YES;
//                int changes = sqlite3_total_changes(db);
//                if(changes > 0) {
//                    NSLog(@"%d folders update page index", changes);
//                }
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return success;
    }
}

- (BOOL) addNewPage: (int)page
{
    if(page < 0) {
        return NO;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        
        BOOL success = NO;
        NSString *command = [NSString stringWithFormat:@"UPDATE %@ SET %@=%@+1 WHERE %@>=?;", kTableFolder, kFolderColumnPage, kFolderColumnPage, kFolderColumnPage];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, page);
            
            if(sqlite3_step(statement) == SQLITE_DONE) {
                success = YES;
//                NSLog(@"%d folders update page index", sqlite3_total_changes(db));
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return success;
    }
}

- (BOOL) isEmptyPage: (int)page
{
    if(page < 0) {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        BOOL isEmpty = NO;
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=?;", kTableFolder, kFolderColumnPage];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, page);

            while(sqlite3_step(statement) == SQLITE_ROW) {
                if(sqlite3_column_int(statement, 0) == 0) {
                    isEmpty = YES;
                }
            }

            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return isEmpty;
    }
}

- (BOOL) isFolderExistInPage: (int)page withNumber:(int)number
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        BOOL isFolderExists = NO;
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=? AND %@=?;", kTableFolder, kFolderColumnPage, kFolderColumnNumber];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, page);
            sqlite3_bind_int(statement, 2, number);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                if(sqlite3_column_int(statement, 0) > 0) {
                    isFolderExists = YES;
                }
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return isFolderExists;
    }
}

- (BOOL) isFolder:(Folder *)folder existedWithName: (NSString *)name
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        BOOL isFolderExists = NO;
        int nID = folder.ID;
        
        NSString *command = nil;
        if(nID > 0) {
            command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=? AND %@!=?;", kTableFolder, kFolderColumnName, kFolderColumnID];
        } else {
            command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=?;", kTableFolder, kFolderColumnName];
        }

        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [name UTF8String], -1, NULL);
            if(nID > 0) {
                sqlite3_bind_int(statement, 2, nID);
            }
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                if(sqlite3_column_int(statement, 0) > 0) {
                    isFolderExists = YES;
                }
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return isFolderExists;
    }
}

- (NSMutableArray *)getFoldersContainsItemBarcode:(Barcode *)barcode
{
    if([barcode.barcodeData length] == 0) {
        return nil;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        NSMutableArray *folders = [NSMutableArray array];
        Folder *folder;
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ IN (SELECT DISTINCT %@ FROM %@ WHERE %@ IN (SELECT %@ FROM %@ WHERE %@=?));", kTableFolder, kFolderColumnID, kItemColumnFolderID, kTableItem, kItemColumnBarcodeID, kBarcodeColumnID, kTableBarcode, kBarcodeColumnBarcodeData];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [barcode.barcodeData UTF8String], -1, NULL);

            while(sqlite3_step(statement) == SQLITE_ROW) {
                folder = [self getFolderFromQueryResult:statement skipColumn:nil];
                if([[folder lockPhrease] length] == 0) {
                    [folders addObject:folder];
                }
            }
            
            sqlite3_finalize(statement);
        }

        sqlite3_close(db);
        
        return folders;
    }
}

- (NSMutableArray *)getFoldersContainsItemName:(NSString *)name
{
    if([name length] == 0) {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        NSMutableArray *folders = [NSMutableArray array];
        Folder *folder;
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ IN (SELECT DISTINCT %@ FROM %@ WHERE %@ LIKE LOWER('%%%@%%') ESCAPE '\\');", kTableFolder, kFolderColumnID, kItemColumnFolderID, kTableItem, kItemColumnName, name];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                folder = [self getFolderFromQueryResult:statement skipColumn:nil];
                if([[folder lockPhrease] length] == 0) {
                    [folders addObject:folder];
                }
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        return folders;
    }
}

//===========================================================
//  Item Operatoins
#pragma mark -
#pragma mark Item Operatoins
//===========================================================
- (BOOL) addItem: (FolderItem *)item intoFolder:(Folder *)folder
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }

        sqlite3_stmt *statement = NULL;
        
        if(item.barcode != nil) {
            if(item.barcode.ID == 0) {
                item.barcode.ID = [self getBarcodeIDOfType:item.barcode.barcodeType andData:item.barcode.barcodeData];
            }

            if(item.barcode.ID == 0) {
                [self addBarcode:item.barcode];
            } else {
                [self updateBarcode:item.barcode withItem:item];
            }
        }
        
        NSString *command = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@, %@, %@, %@, %@, %@, %@, %@, %@, %@) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", kTableItem, kItemColumnName, kItemColumnBarcodeID, kItemColumnImagePath, kItemColumnCount, kItemColumnCreateTime, kItemColumnExpireTime, kItemColumnPrice, kItemColumnFolderID, kItemColumnLocationID, kItemColumnNote, kItemColumnArchived,  kItemColumnNearExpiredDays];

        int field = 1;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, field++, [item.name UTF8String], -1, NULL);
            sqlite3_bind_int(statement,  field++, item.barcode.ID);
            sqlite3_bind_text(statement, field++, [item.imagePath UTF8String], -1, NULL);
            sqlite3_bind_int(statement, field++, item.count);
            sqlite3_bind_double(statement, field++, [item.createTime timeIntervalSince1970]);
            sqlite3_bind_double(statement, field++, [item.expireTime timeIntervalSince1970]);
            sqlite3_bind_double(statement, field++, item.price);
            sqlite3_bind_int(statement, field++, folder.ID);
            sqlite3_bind_int(statement, field++, item.location.ID);
            sqlite3_bind_text(statement, field++, [item.note UTF8String], -1, NULL);
            sqlite3_bind_int(statement, field++, item.isArchived);
            NSMutableString *dayString = [NSMutableString string];
            for(NSNumber *day in item.nearExpiredDays) {
                if(day != [item.nearExpiredDays lastObject]) {
                    [dayString appendString:[NSString stringWithFormat:@"%d%@", [day intValue], kDaySeperator]];
                } else {
                    [dayString appendString:[NSString stringWithFormat:@"%d", [day intValue]]];
                }
            }
            sqlite3_bind_text(statement, field++, [dayString UTF8String], -1, NULL);
        }
        
        BOOL success = NO;
        if(sqlite3_step(statement) == SQLITE_DONE) {
            success = YES;
            item.ID = sqlite3_last_insert_rowid(db);
            item.folderID = folder.ID;
        } else {
            errMsg = [NSString stringWithFormat:@"Fail to add item: %s", sqlite3_errmsg(db)];
            NSLog(@"%@", errMsg);
        }
        sqlite3_finalize(statement);

        sqlite3_close(db);

        return success;
    }
}

- (BOOL) removeItem: (FolderItem *)item
{
    BOOL success = NO;
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }

        sqlite3_stmt *statement = NULL;
        int nTotalChanges = 0;

        NSString *command = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=?;", kTableItem, kItemColumnID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, item.ID);
            
            if(sqlite3_step(statement) == SQLITE_DONE &&
               (nTotalChanges = sqlite3_total_changes(db)) == 1)
            {
                success = YES;
                
                //Delete unused(item or barcode) image
                [self deleteItemImage:item.imagePath];
            } else {
                if(nTotalChanges != 1) {
                    errMsg = [NSString stringWithFormat:@"Fail to remove item %d: total changes %d", item.ID, nTotalChanges];
                } else {
                    errMsg = [NSString stringWithFormat:@"Fail to remove item %d: %s", item.ID, sqlite3_errmsg(db)];
                }
                NSLog(@"%@", errMsg);
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);

        return success;
    }
}

- (int) removeItems: (NSMutableArray *)items
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }

        sqlite3_stmt *statement = NULL;
        NSString *command = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=?;", kTableItem, kItemColumnID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            for(FolderItem *item in items) {
                sqlite3_bind_int(statement, 1, item.ID);

                if(sqlite3_step(statement) != SQLITE_DONE) {
                    NSLog(@"Fail to remove item %d", item.ID);
                }
                sqlite3_reset(statement);
            }
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);
        
        const int ITEM_COUNT = [items count];
        int nRemovedItemCount = sqlite3_total_changes(db);
        if(nRemovedItemCount != ITEM_COUNT) {
            errMsg = [NSString stringWithFormat:@"Fail to remove %d of %d items", ITEM_COUNT-nRemovedItemCount, ITEM_COUNT];
            NSLog(@"%@", errMsg);
        }
        
        return nRemovedItemCount;
    }
}

- (BOOL) updateItem: (FolderItem *)item
{
    if(!item) {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        
        if(item.barcode != nil) {
            if(item.barcode.ID == 0) {
                item.barcode.ID = [self getBarcodeIDOfType:item.barcode.barcodeType andData:item.barcode.barcodeData];
            }

            if(item.barcode.ID == 0) {
                [self addBarcode:item.barcode withItem:item];
            } else {
                [self updateBarcode:item.barcode withItem:item];
            }
        }

        sqlite3_stmt *statement = NULL;

        NSString *command = [NSString stringWithFormat:@"UPDATE %@ SET %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=? WHERE %@=?;", kTableItem, kItemColumnName, kItemColumnBarcodeID, kItemColumnImagePath, kItemColumnCount, kItemColumnCreateTime, kItemColumnExpireTime, kItemColumnPrice, kItemColumnFolderID, kItemColumnLocationID, kItemColumnNote, kItemColumnArchived,  kItemColumnNearExpiredDays, kItemColumnID];

        BOOL success = NO;
        int field = 1;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement,    field++, [item.name UTF8String], -1, NULL);
            sqlite3_bind_int(statement,     field++, item.barcode.ID);
            sqlite3_bind_text(statement,    field++, [item.imagePath UTF8String], -1, NULL);
            sqlite3_bind_int(statement,     field++, item.count);
            sqlite3_bind_double(statement,  field++, [item.createTime timeIntervalSince1970]);
            sqlite3_bind_double(statement,  field++, [item.expireTime timeIntervalSince1970]);
            sqlite3_bind_double(statement,  field++, item.price);
            sqlite3_bind_int(statement,     field++, item.folderID);
            sqlite3_bind_int(statement,     field++, item.location.ID);
            sqlite3_bind_text(statement,    field++, [item.note UTF8String], -1, NULL);
            sqlite3_bind_int(statement,     field++, item.isArchived);
            NSMutableString *dayString = [NSMutableString string];
            for(NSNumber *day in item.nearExpiredDays) {
                if(day != [item.nearExpiredDays lastObject]) {
                    [dayString appendString:[NSString stringWithFormat:@"%d%@", [day intValue], kDaySeperator]];
                } else {
                    [dayString appendString:[NSString stringWithFormat:@"%d", [day intValue]]];
                }
            }
            sqlite3_bind_text(statement,    field++, [dayString UTF8String], -1, NULL);

            sqlite3_bind_int(statement,     field++, item.ID);
        }

        if(sqlite3_step(statement) == SQLITE_DONE) {
            success = YES;
        } else {
            errMsg = [NSString stringWithFormat:@"Fail to update item: %s", sqlite3_errmsg(db)];
            NSLog(@"%@", errMsg);
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);

        return success;
    }
}

- (BOOL)updateItem: (FolderItem *)item archive:(BOOL)archived
{
    if(!item ||
       item.ID <= 0)
    {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        
        NSString *command = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?;", kTableItem, kItemColumnArchived, kItemColumnID];
        BOOL success = NO;
        int field = 1;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement,     field++, archived);
            sqlite3_bind_int(statement,     field++, item.ID);
        }

        if(sqlite3_step(statement) == SQLITE_DONE) {
            success = YES;
            item.isArchived = archived;
        } else {
            errMsg = [NSString stringWithFormat:@"Fail to update item's archive: %s", sqlite3_errmsg(db)];
            NSLog(@"%@", errMsg);
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);

        return success;
    }
}

- (BOOL)updateItem:(FolderItem *)item count:(int)newCount
{
    if(!item ||
       item.ID <= 0)
    {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        
        NSString *command = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?;",
                             kTableItem, kItemColumnCount, kItemColumnID];
        BOOL success = NO;
        int field = 1;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement,     field++, newCount);
            sqlite3_bind_int(statement,     field++, item.ID);
        }
        
        if(sqlite3_step(statement) == SQLITE_DONE) {
            success = YES;
            item.count = newCount;
        } else {
            errMsg = [NSString stringWithFormat:@"Fail to update item's count: %s", sqlite3_errmsg(db)];
            NSLog(@"%@", errMsg);
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);
        
        return success;
    }
}

- (BOOL)updateItem:(FolderItem *)item folderID:(int)newFolderID
{
    if(!item ||
       item.ID <= 0)
    {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        
        NSString *command = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?;",
                             kTableItem, kItemColumnFolderID, kItemColumnID];
        BOOL success = NO;
        int field = 1;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement,     field++, newFolderID);
            sqlite3_bind_int(statement,     field++, item.ID);
        }
        
        if(sqlite3_step(statement) == SQLITE_DONE) {
            success = YES;
            item.folderID = newFolderID;
        } else {
            errMsg = [NSString stringWithFormat:@"Fail to update item's folder ID: %s", sqlite3_errmsg(db)];
            NSLog(@"%@", errMsg);
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);
        
        return success;
    }
}

- (FolderItem *)duplicateItem:(FolderItem *)item
{
    if(!item ||
       item.ID <= 0)
    {
        return nil;
    }
    
    FolderItem *newItem = [item copy];
    newItem.ID = 0;
    newItem.createTime = [TimeUtil today];
    
    Folder *folder = [Folder new];
    folder.ID = newItem.folderID;
    if([self addItem:newItem intoFolder:folder]) {
        return newItem;
    }
    
    return nil;
}

- (BOOL)moveItem:(FolderItem *)item toFolder:(Folder *)folder withCount:(int)count
{
    if(item == nil ||
       item.ID <= 0 ||
       folder == nil ||
       folder.ID <= 0)
    {
        return NO;
    }
    
    if(item.folderID == folder.ID) {
        return YES;
    }
    
    //Move to new folder
    if(folder.ID == 0) {
        [self addFolder:folder];
    }

    BOOL success = NO;
    if(count < item.count) {
        //1. Add new item to new folder
        FolderItem *newItem = [item copy];
        newItem.ID = 0;
        newItem.count = count;
        success = [self addItem:newItem intoFolder:folder];
        
        //2. Update original item count
        if(success) {
            if(count > 0) {
                item.count -= count;
                success = [self updateItem:item count:item.count];
            }
        }
    } else {
        //Update folder ID would be ok
        [self updateItem:item folderID:folder.ID];
    }
    
    return success;
}

- (FolderItem *)getItemFromQueryResult:(sqlite3_stmt *)statement skipColumn:(NSString *)skipColumnName
{
    if(statement == NULL) {
        return nil;
    }
    

    FolderItem *item = [[FolderItem alloc] init];

    char *strTextResult = NULL;
    for(int column = sqlite3_column_count(statement) - 1; column >= 0; column--) {
        if(sqlite3_column_bytes(statement, column) == 0) {
//            NSLog(@"Skip empty column: %s", sqlite3_column_name(statement, column));
            continue;
        }
        
        NSString *columnName = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, column)];
        if([columnName isEqualToString:skipColumnName]) {
            continue;
        }

        if([columnName isEqualToString: kItemColumnID]) {
            item.ID = sqlite3_column_int(statement, column);
        } else if([columnName isEqualToString: kItemColumnName]) {
            strTextResult = (char *)sqlite3_column_text(statement, column);
            if(strTextResult) {
                item.name = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
            }
        } else if([columnName isEqualToString: kItemColumnBarcodeID]) {
            int nBarcodeID = sqlite3_column_int(statement, column);
            item.barcode = [self getBarcodeByID:nBarcodeID];
        } else if([columnName isEqualToString: kItemColumnImagePath]) {
            strTextResult = (char *)sqlite3_column_text(statement, column);
            if(strTextResult) {
                item.imagePath = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
            }
        } else if([columnName isEqualToString: kItemColumnCount]) {
            item.count = sqlite3_column_int(statement, column);
        } else if([columnName isEqualToString: kItemColumnCreateTime]) {
            item.createTime = [NSDate dateWithTimeIntervalSince1970:sqlite3_column_double(statement, column)];
        } else if([columnName isEqualToString: kItemColumnExpireTime]) {
            item.expireTime = [NSDate dateWithTimeIntervalSince1970:sqlite3_column_double(statement, column)];
        } else if([columnName isEqualToString: kItemColumnPrice]) {
            item.price = sqlite3_column_double(statement, column);
        } else if([columnName isEqualToString: kItemColumnFolderID]) {
            item.folderID = sqlite3_column_int(statement, column);
        } else if([columnName isEqualToString: kItemColumnLocationID]) {
            int nLocationID = sqlite3_column_int(statement, column);
            item.location = [self getLocationByID:nLocationID];
        } else if([columnName isEqualToString: kItemColumnNote]) {
            strTextResult = (char *)sqlite3_column_text(statement, column);
            if(strTextResult) {
                item.note = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
            }
        } else if([columnName isEqualToString: kItemColumnArchived]) {
            item.isArchived = sqlite3_column_int(statement, column);
        } else if([columnName isEqualToString: kItemColumnNearExpiredDays]) {
            strTextResult = (char *)sqlite3_column_text(statement, column);
            if(strTextResult) {
                NSString *dayString = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
                NSArray *days = [dayString componentsSeparatedByString:kDaySeperator];
                if([days count] > 0) {
                    item.nearExpiredDays = [NSMutableArray array];
                    for(NSString *day in days) {
                        [item.nearExpiredDays addObject:[NSNumber numberWithInt:[day intValue]]];
                    }

                    [item.nearExpiredDays sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                        return [(NSNumber *)obj1 compare:(NSNumber *)obj2];
                    }];
                }
            }
        }
    }
    
    item.isInShoppingList = [[Database sharedSingleton] isItemInShoppingList:item];
    
    return item;
}

- (NSMutableArray *)getItemsByName: (NSString *)name
{
    if([name length] == 0) {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        NSMutableArray *itemList = [NSMutableArray array];
        FolderItem *item = nil;
        
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=?;", kTableItem, kItemColumnName];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [name UTF8String], -1, NULL);

            while(sqlite3_step(statement) == SQLITE_ROW) {
                item = [self getItemFromQueryResult:statement skipColumn:kItemColumnName];
                item.name = name;
                [itemList addObject:item];
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        //Caller must retain or copy this
        return itemList;
    }
}

- (NSMutableArray *)getItemsContainsName: (NSString *)name
{
    if([name length] == 0) {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        NSMutableArray *itemList = [NSMutableArray array];
        FolderItem *item = nil;

        NSString *searchString = [name stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        searchString = [searchString stringByReplacingOccurrencesOfString:@"%" withString:@"\\%"];
        searchString = [searchString stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"];

        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ LIKE LOWER('%%%@%%') ESCAPE '\\';",
                             kTableItem, kItemColumnName, searchString];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                item = [self getItemFromQueryResult:statement skipColumn:nil];
                [itemList addObject:item];
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        //Caller must retain or copy this
        return itemList;
    }
}

- (NSMutableArray *)getItemsHasPrefixName: (NSString *)name
{
    if([name length] == 0) {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        NSMutableArray *itemList = [NSMutableArray array];
        FolderItem *item = nil;

        NSString *searchString = [name stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        searchString = [searchString stringByReplacingOccurrencesOfString:@"%" withString:@"\\%"];
        searchString = [searchString stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"];
        
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ LIKE LOWER('%@%%') ESCAPE '\\';",
                             kTableItem, kItemColumnName, searchString];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                item = [self getItemFromQueryResult:statement skipColumn:nil];
                [itemList addObject:item];
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        //Caller must retain or copy this
        return itemList;
    }
}

- (NSMutableArray *)getItemsByBarcode: (Barcode *)barcode
{
    if(!barcode) {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        NSMutableArray *itemList = [NSMutableArray array];
        FolderItem *item = nil;
        
        if(barcode.ID == 0) {
            Barcode *newBarcode = [self getBarcodeOfType:barcode.barcodeType andData:barcode.barcodeData];
            
            if(newBarcode.ID == 0) {
                return nil;
            } else {
                barcode.ID = newBarcode.ID;
            }
        }
        
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=?;", kTableItem, kItemColumnBarcodeID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, barcode.ID);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                item = [self getItemFromQueryResult:statement skipColumn:nil];
                [itemList addObject:item];
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        //Caller must retain or copy this
        return itemList;
    }
}

- (BOOL)removeLocationFromItem:(FolderItem *)item
{
    if(item.ID <= 0) {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        BOOL success = YES;
        sqlite3_stmt *statement = NULL;
        NSString *command = [NSString stringWithFormat:@"UPDATE %@ SET %@='' WHERE %@=?", kTableItem, kItemColumnLocationID, kItemColumnID];
        
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, item.ID);
            if(sqlite3_step(statement) != SQLITE_DONE) {
                NSLog(@"Fail to remove location from item %d", item.ID);
                success = NO;
            }
            sqlite3_finalize(statement);
        }
        sqlite3_close(db);
        
        return success;
    }
}

- (BOOL)removeNoteFromItem:(FolderItem *)item
{
    if(item.ID <= 0) {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        BOOL success = YES;
        sqlite3_stmt *statement = NULL;
        NSString *command = [NSString stringWithFormat:@"UPDATE %@ SET %@='' WHERE %@=?", kTableItem, kItemColumnNote, kItemColumnID];
        
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, item.ID);
            if(sqlite3_step(statement) != SQLITE_DONE) {
                NSLog(@"Fail to remove note from item %d", item.ID);
                success = NO;
            }
            sqlite3_finalize(statement);
        }
        sqlite3_close(db);
        
        return success;
    }
}

- (NSMutableArray *)getItemsInFolder: (Folder *)folder withSortOption:(SortOption *)sortOption
{
    if(!folder) {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        

        sqlite3_stmt *statement = NULL;
        const NSString *kDefaultSortColumn = kItemColumnCreateTime;
        NSMutableArray *itemList = [NSMutableArray array];
        
        //Prepare query command
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=? ORDER BY ", kTableItem, kItemColumnFolderID];
        if(sortOption == nil) {
            command = [command stringByAppendingFormat:@" %@", kDefaultSortColumn];
        } else {
            command = [command stringByAppendingFormat:@" %@", (sortOption.column)?sortOption.column:kDefaultSortColumn];
            
            if(sortOption.order == SortDecending){
                command = [command stringByAppendingString:@" DESC"];
            }
        }
        
        command = [command stringByAppendingString:@";"];
        
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, folder.ID);
            
            FolderItem *item = nil;
            while(sqlite3_step(statement) == SQLITE_ROW) {
                item = [self getItemFromQueryResult:statement skipColumn:nil];
                [itemList addObject:item];
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        return itemList;
    }
}

- (NSMutableArray *) getExpiredItemsInFolder: (Folder *)folder within:(int)days
{
    if(!folder) {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }

        sqlite3_stmt *statement = NULL;
        NSMutableArray *expiredList = [NSMutableArray array];
        int expireTime = [[TimeUtil dateFromToday:days] timeIntervalSince1970];
        
        //1. Not archived
        //2. Count > 0
        //3.Time > 0 and < days from today
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=? AND %@ IS NOT 1 AND %@ > 0 AND %@>0 AND %@<?;",
                             kTableItem, kItemColumnFolderID, kItemColumnArchived, kItemColumnCount, kItemColumnExpireTime, kItemColumnExpireTime];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, folder.ID);
            sqlite3_bind_int(statement, 2, expireTime);
            
            FolderItem *item = nil;
            while(sqlite3_step(statement) == SQLITE_ROW) {
                item = [self getItemFromQueryResult:statement skipColumn:nil];
                [expiredList addObject:item];
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return expiredList;
    }
}

#pragma mark -
#pragma mark Get count from database
- (int) totalPages
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 1;
        }

        sqlite3_stmt *statement = NULL;
        int pageCount = 1;

        NSString *command = [NSString stringWithFormat:@"SELECT MAX(DISTINCT %@) FROM %@;", kFolderColumnPage, kTableFolder];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                pageCount = sqlite3_column_int(statement, 0) + 1;
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        if(pageCount < 1) {
            pageCount = 1;
        }
        return pageCount;
    }
}

- (int) maxPageIndex
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        int result = 0;
        
        NSString *command = [NSString stringWithFormat:@"SELECT MAX(%@) FROM %@;", kFolderColumnPage, kTableFolder];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                result = sqlite3_column_int(statement, 0);
            }
            sqlite3_finalize(statement);
        }

        sqlite3_close(db);
        return result;
    }
}

- (int) minPageIndex
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        int result = 0;
        
        NSString *command = [NSString stringWithFormat:@"SELECT MIN(%@) FROM %@;", kFolderColumnPage, kTableFolder];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                result = sqlite3_column_int(statement, 0);
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return result;
    }
}

- (int) totalItems
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        int result = 0;
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@;", kTableItem];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                result = sqlite3_column_int(statement, 0);
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return result;
    }
}
//================================
//  totalItemsInFolder[Async]
//================================
- (int) totalItemsInFolder: (Folder *)folder;
{
    if(!folder) {
        return 0;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }

        sqlite3_stmt *statement = NULL;
        int itemCount = 0;
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=?;", kTableItem, kItemColumnFolderID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, folder.ID);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                itemCount = sqlite3_column_int(statement, 0);
                break;
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return itemCount;
    }
}

//=======================================
//  totalExpiredItemsInPeriod[Async]
//  For showing badge in springboard
//=======================================
- (int) totalExpiredItemsFromToday: (int)days
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }

        sqlite3_stmt *statement = NULL;
        int expiredItemCount = 0;
        int expireTime = [[TimeUtil dateFromToday:days] timeIntervalSince1970];

        //1. Not archived
        //2. Count > 0
        //3.Time > 0 and < days from today
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@ IS NOT 1 AND %@ > 0 AND %@>0 AND %@<?;",
                             kTableItem, kItemColumnArchived, kItemColumnCount, kItemColumnExpireTime, kItemColumnExpireTime];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, expireTime);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                expiredItemCount = sqlite3_column_int(statement, 0);
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return expiredItemCount;
    }
}

- (int) totalExpiredItemsSince:(NSDate *)date
{
    @synchronized(self) {
        if([date timeIntervalSince1970] <= 0) {
            return [self totalExpiredItemsFromToday:0];
        }

        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        int expiredItemCount = 0;
        int expireTime = [date timeIntervalSince1970];
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@ IS NOT 1 AND %@ > 0 AND %@>0 AND %@>=?;",
                             kTableItem, kItemColumnArchived, kItemColumnCount, kItemColumnExpireTime, kItemColumnExpireTime];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, expireTime);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                expiredItemCount = sqlite3_column_int(statement, 0);
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return expiredItemCount;
    }
}

- (int) totalExpiredItemsBefore:(NSDate *)date
{
    @synchronized(self) {
        if([date timeIntervalSince1970] <= 0) {
            return [self totalExpiredItemsFromToday:0];
        }
        
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        int expiredItemCount = 0;
        int expireTime = [date timeIntervalSince1970];
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@ IS NOT 1 AND %@ > 0 AND %@>0 AND %@<?;",
                             kTableItem, kItemColumnArchived, kItemColumnCount, kItemColumnExpireTime, kItemColumnExpireTime];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, expireTime);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                expiredItemCount = sqlite3_column_int(statement, 0);
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return expiredItemCount;
    }
}

//For showing badge in up-right corner of a Folder
- (int) totalExpiredItemsInFolder:(Folder *)folder within:(int)days
{
    if(folder == nil ||
       folder.ID == 0)
    {
        return 0;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        sqlite3_stmt *statement = NULL;
        int expiredItemCount = 0;
        int expireTime = [[TimeUtil dateFromToday:days] timeIntervalSince1970];
        
        //1. Not archived
        //2. Count > 0
        //3.Time > 0 and < days from today
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=? AND %@ IS NOT 1 AND %@ > 0 AND %@>0 AND %@<?;",
                             kTableItem, kItemColumnFolderID, kItemColumnArchived, kItemColumnCount, kItemColumnExpireTime, kItemColumnExpireTime];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, folder.ID);
            sqlite3_bind_int(statement, 2, expireTime);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                expiredItemCount = sqlite3_column_int(statement, 0);
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return expiredItemCount;
    }
}

//For showing badge in up-right corner of a Folder
- (int) totalNearExpiredItemsInFolder:(Folder *)folder
{
    if(folder == nil ||
       folder.ID == 0)
    {
        return 0;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        sqlite3_stmt *statement = NULL;
        int nearExpiredItemCount = 0;
        int timeIntervalOfToday = [[TimeUtil today] timeIntervalSince1970];
        FolderItem *item;
        
        //1. Not archived
        //2. Count > 0
        //3.Time > days from today
        NSString *command = [NSString stringWithFormat:@"SELECT %@,%@ FROM %@ WHERE %@=? AND %@ IS NOT 1 AND %@ > 0 AND %@>=?;",
                             kItemColumnExpireTime, kItemColumnNearExpiredDays, kTableItem, kItemColumnFolderID, kItemColumnArchived, kItemColumnCount, kItemColumnExpireTime];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, folder.ID);
            sqlite3_bind_int(statement, 2, timeIntervalOfToday);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                item = [self getItemFromQueryResult:statement skipColumn:nil];
                item.count = 1; //for checking in isNearExpired
                if([item isNearExpired]) {
                    nearExpiredItemCount++;
                }
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return nearExpiredItemCount;
    }
}

- (int) totalItemsWithImagePath: (NSString *)imagePath
{
    if([imagePath length] == 0) {
        return 0;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        sqlite3_stmt *statement = NULL;
        int itemCount = 0;
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=?;", kTableItem, kItemColumnImagePath];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [imagePath UTF8String], -1, NULL);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                itemCount = sqlite3_column_int(statement, 0);
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return itemCount;
    }
}

- (int) totalBarcodesWithImagePath: (NSString *)imagePath
{
    if([imagePath length] == 0) {
        return 0;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }

        sqlite3_stmt *statement = NULL;
        int count = 0;

        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=?;", kTableBarcode, kBarcodeColumnItemImagePath];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [imagePath UTF8String], -1, NULL);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                count = sqlite3_column_int(statement, 0);
            }
            sqlite3_finalize(statement);
        }

        sqlite3_close(db);
        return count;
    }
}

- (int) totalShoppingItemsWithImagePath: (NSString *)imagePath
{
    if([imagePath length] == 0) {
        return 0;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        int count = 0;
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=?;", kTableShoppingList, kShoppingListColumnItemImagePath];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [imagePath UTF8String], -1, NULL);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                count = sqlite3_column_int(statement, 0);
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return count;
    }
}

- (int)totalLocations
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        int result = 0;
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@;", kTableLocation];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                result = sqlite3_column_int(statement, 0);
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return result;
    }
}

- (int)numberOfItemsContainName:(NSString *)name
{
    if([name length] == 0) {
        return 0;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        int itemCount = 0;
        
        NSString *searchString = [name stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        searchString = [searchString stringByReplacingOccurrencesOfString:@"%" withString:@"\\%"];
        searchString = [searchString stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"];
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@ LIKE LOWER('%%%@%%') ESCAPE '\\';",
                             kTableItem, kItemColumnName, searchString];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                itemCount = sqlite3_column_int(statement, 0);
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        return itemCount;
    }
}

- (int)numberOfItemsWithBarcode:(Barcode *)barcode
{
    if(!barcode) {
        return 0;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        int itemCount = 0;
        
        if(barcode.ID == 0) {
            int barcodeID = [self getBarcodeIDOfType:barcode.barcodeType andData:barcode.barcodeData];
            if(barcodeID == 0) {
                return 0;
            } else {
                barcode.ID = barcodeID;
            }
        }
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=?;", kTableItem, kItemColumnBarcodeID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, barcode.ID);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                itemCount = sqlite3_column_int(statement, 0);
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        //Caller must retain or copy this
        return itemCount;
    }
}

- (int)numberOfItemsFromShoppingItem:(ShoppingItem *)shoppingItem
{
    BOOL hasName = ([shoppingItem.itemName length] > 0) ? YES : NO;
    BOOL hasImage = ([shoppingItem.itemImagePath length] > 0) ? YES : NO;
    
    if(shoppingItem == nil ||
       (!hasName && !hasImage))
    {
        return 0;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        NSString *command = nil;
        if(hasName) {
            if(hasImage) {
                command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=? AND %@=?;",
                           kTableItem, kItemColumnName, kItemColumnImagePath];
            } else {
                //Name only
                command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=? AND (%@='' OR %@ IS NULL);",
                           kTableItem, kItemColumnName, kItemColumnImagePath, kItemColumnImagePath];
            }
        } else {
            //Image Only
            command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE (%@='' OR %@ IS NULL) AND %@=?;",
                       kTableItem, kItemColumnName, kItemColumnName, kItemColumnImagePath];
        }
        
        int column = 1;
        int result = 0;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            if(hasName) {
                if(hasImage) {
                    sqlite3_bind_text(statement, column++, [shoppingItem.itemName UTF8String], -1, NULL);
                    sqlite3_bind_text(statement, column++, [shoppingItem.itemImagePath UTF8String], -1, NULL);
                } else {
                    //Name only
                    sqlite3_bind_text(statement, column++, [shoppingItem.itemName UTF8String], -1, NULL);
                }
            } else {
                //Image Only
                sqlite3_bind_text(statement, column++, [shoppingItem.itemImagePath UTF8String], -1, NULL);
            }
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                result = sqlite3_column_int(statement, 0);
                break;
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        //Caller must retain or copy this
        return result;
    }
}

//==============================================================
//  [BEGIN] Barcode related
#pragma mark - Barcode related
//--------------------------------------------------------------
- (BOOL)isBarcodeExist:(Barcode *)barcode
{
    if(barcode.ID > 0) {
        return YES;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        int count = 0;
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=?;", kTableBarcode, kBarcodeColumnBarcodeData];

        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [barcode.barcodeData UTF8String], -1, NULL);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                count = sqlite3_column_int(statement, 0);
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return (count > 0);
    }
}

- (BOOL)addBarcode:(Barcode *)barcode
{
    if([self isBarcodeExist:barcode]) {
        NSLog(@"Update existed barcode instead of adding it again");
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        NSString *command = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@) VALUES (?, ?);",
                             kTableBarcode, kBarcodeColumnBarcodeType, kBarcodeColumnBarcodeData];
        
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [barcode.barcodeType UTF8String], -1, NULL);
            sqlite3_bind_text(statement, 2, [barcode.barcodeData UTF8String], -1, NULL);
        }
        
        BOOL success = NO;
        if(sqlite3_step(statement) == SQLITE_DONE) {
            success = YES;
            barcode.ID = sqlite3_last_insert_rowid(db);
        } else {
            errMsg = [NSString stringWithFormat:@"Fail to add barcode: %s", sqlite3_errmsg(db)];
            NSLog(@"%@", errMsg);
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);
        
        return success;
    }
}

- (BOOL)addBarcode:(Barcode *)barcode withItem:(FolderItem *)item
{
    if([self isBarcodeExist:barcode]) {
        NSLog(@"Update existed barcode instead of adding it again");
        return NO;
    }

    if([item.name length] == 0 &&
       [item.imagePath length] == 0)
    {
        NSLog(@"Skip to add item data with barcode");
        return [self addBarcode:barcode];
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        NSString *command = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@, %@) VALUES (?, ?, ?, ?);",
                             kTableBarcode, kBarcodeColumnBarcodeType, kBarcodeColumnBarcodeData,
                             kBarcodeColumnItemName, kBarcodeColumnItemImagePath];

        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [barcode.barcodeType UTF8String], -1, NULL);
            sqlite3_bind_text(statement, 2, [barcode.barcodeData UTF8String], -1, NULL);
            sqlite3_bind_text(statement, 3, [item.name UTF8String], -1, NULL);
            sqlite3_bind_text(statement, 4, [item.imagePath UTF8String], -1, NULL);
        }
        
        BOOL success = NO;
        if(sqlite3_step(statement) == SQLITE_DONE) {
            success = YES;
            barcode.ID = sqlite3_last_insert_rowid(db);
        } else {
            errMsg = [NSString stringWithFormat:@"Fail to add barcode: %s", sqlite3_errmsg(db)];
            NSLog(@"%@", errMsg);
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);

        return success;
    }
}

- (BOOL)addBarcode:(Barcode *)barcode withFolder:(Folder *)folder
{
    if([self isBarcodeExist:barcode]) {
        NSLog(@"Update existed barcode instead of adding it again");
        return NO;
    }

    if(folder.ID <= 0) {
        NSLog(@"Ignore to add folder ID with barcode");
        return [self addBarcode:barcode];
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        NSString *command = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@) VALUES (?, ?, ?);",
                             kTableBarcode, kBarcodeColumnBarcodeType, kBarcodeColumnBarcodeData,
                             kBarcodeColumnFolderID];
        
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [barcode.barcodeType UTF8String], -1, NULL);
            sqlite3_bind_text(statement, 2, [barcode.barcodeData UTF8String], -1, NULL);
            sqlite3_bind_int(statement, 3, folder.ID);
        }
        
        BOOL success = NO;
        if(sqlite3_step(statement) == SQLITE_DONE) {
            success = YES;
            barcode.ID = sqlite3_last_insert_rowid(db);
        } else {
            errMsg = [NSString stringWithFormat:@"Fail to add barcode: %s", sqlite3_errmsg(db)];
            NSLog(@"%@", errMsg);
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);
        
        return success;
    }
}

- (Barcode *)getBarcodeOfType:(NSString *)type andData:(NSString *)data
{
    if([type length] == 0 ||
       [data length] == 0)
    {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        Barcode *barcode = nil;
        
        NSString *command = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@=? AND %@=?;", kBarcodeColumnID, kTableBarcode, kBarcodeColumnBarcodeType, kBarcodeColumnBarcodeData];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [type UTF8String], -1, NULL);
            sqlite3_bind_text(statement, 2, [data UTF8String], -1, NULL);

            while(sqlite3_step(statement) == SQLITE_ROW) {
                barcode = [[Barcode alloc] initWithType:type andData:data];
                barcode.ID = sqlite3_column_int(statement, 0);
                break;
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        return barcode;
    }
}

- (Barcode *)getBarcodeByID:(int)barcodeID
{
    if(barcodeID <= 0) {
        return nil;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        Barcode *barcode = nil;
        char *strTextResult = NULL;
        NSString *command = [NSString stringWithFormat:@"SELECT %@, %@ FROM %@ WHERE %@=?;", kBarcodeColumnBarcodeType, kBarcodeColumnBarcodeData, kTableBarcode, kBarcodeColumnID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, barcodeID);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                barcode = [[Barcode alloc] init];
                barcode.ID = barcodeID;

                NSString *columnName = nil;
                for(int column = sqlite3_column_count(statement) - 1; column >= 0; column--) {
                    columnName = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, column)];
                    if([columnName isEqualToString: kBarcodeColumnBarcodeType]) {
                        strTextResult = (char *)sqlite3_column_text(statement, column);
                        if(strTextResult) {
                            barcode.barcodeType = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
                        }
                    } else if([columnName isEqualToString: kBarcodeColumnBarcodeData]) {
                        strTextResult = (char *)sqlite3_column_text(statement, column);
                        if(strTextResult) {
                            barcode.barcodeData = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
                        }
                    }
                    
                }

                break;
            }

            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return barcode;
    }
}

- (int)getBarcodeIDOfType:(NSString *)type andData:(NSString *)data
{
    return [self getBarcodeOfType:type andData:data].ID;
}

- (NSString *)getItemNameByBarcode:(Barcode *)barcode
{
    if(barcode == nil) {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        NSString *itemName = nil;
        char*strTextResult = NULL;
        NSString *command = command = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@=?;", kBarcodeColumnItemName, kTableBarcode, kBarcodeColumnBarcodeData];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [barcode.barcodeData UTF8String], -1, NULL);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                strTextResult = (char *)sqlite3_column_text(statement, 0);
                if(strTextResult) {
                    itemName = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
                }
                break;
            }
            
            sqlite3_finalize(statement);
        }

        sqlite3_close(db);
        
        return itemName;
    }
}

- (NSString *)getItemImagePathOfBarcode:(Barcode *)barcode
{
    if(barcode == nil) {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        NSString *itemImagePath = nil;
        char *strTextResult = NULL;
        
        if(barcode.ID > 0) {
            NSString *command = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@=?;", kBarcodeColumnItemImagePath, kTableBarcode, kBarcodeColumnID];
            if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                sqlite3_bind_int(statement, 1, barcode.ID);
                
                while(sqlite3_step(statement) == SQLITE_ROW) {
                    strTextResult = (char *)sqlite3_column_text(statement, 0);
                    if(strTextResult) {
                        itemImagePath = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
                    }
                    break;
                }
                
                sqlite3_finalize(statement);
            }
        } else {
            NSString *command = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@=?;", kBarcodeColumnItemImagePath, kTableBarcode,  kBarcodeColumnBarcodeData];
            if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                sqlite3_bind_text(statement, 1, [barcode.barcodeData UTF8String], -1, NULL);
                
                while(sqlite3_step(statement) == SQLITE_ROW) {
                    strTextResult = (char *)sqlite3_column_text(statement, 0);
                    if(strTextResult) {
                        itemImagePath = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
                    }
                    break;
                }
                
                sqlite3_finalize(statement);
            }
        }
        
        sqlite3_close(db);
        
        return itemImagePath;
    }
}

- (int)getFolderIDByBarcode:(Barcode *)barcode
{
    if(barcode == nil) {
        return 0;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        int nFolderID = 0;
        
        NSString *command = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@=?;", kBarcodeColumnFolderID, kTableBarcode, kBarcodeColumnBarcodeData];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [barcode.barcodeData UTF8String], -1, NULL);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                nFolderID = sqlite3_column_int(statement, 0);
                break;
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        return nFolderID;
    }
}

- (BOOL)updateBarcode:(Barcode *)barcode withItem:(FolderItem *)item;
{
    if(barcode.ID <= 0) {
        NSLog(@"Fail to update barcode: add barcode to DB first");
        return NO;
    }
    
    @synchronized(self) {

        NSString *command = nil;
        NSString *oldImagePath = [self getItemImagePathOfBarcode:barcode];
        if([item.imagePath length] > 0) {
            if([item.name length] > 0) {
                //Update name and image path
                command = [NSString stringWithFormat:@"UPDATE %@ SET %@=?, %@=? WHERE %@=?;",
                           kTableBarcode, kBarcodeColumnItemName, kBarcodeColumnItemImagePath, kBarcodeColumnID];
            } else {
                //Update image path only
                command = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?;",
                           kTableBarcode, kBarcodeColumnItemImagePath, kBarcodeColumnID];
            }
        } else {
            if([item.name length] > 0) {
                //Update name only
                command = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?;",
                           kTableBarcode, kBarcodeColumnItemName, kBarcodeColumnID];
            } else {
                NSLog(@"Fail to update barcode: nothing to update");
                return NO;
            }
        }

        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }

        sqlite3_stmt *statement = NULL;
        BOOL success = NO;
        int nBindColumn = 1;

        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            if([item.name length] > 0) {
                sqlite3_bind_text(statement, nBindColumn++, [item.name UTF8String], -1, NULL);
            }
            
            if([item.imagePath length] > 0) {
                sqlite3_bind_text(statement, nBindColumn++, [item.imagePath UTF8String], -1, NULL);
            }

            sqlite3_bind_int(statement, nBindColumn++, barcode.ID);
            
            int nLastChanges = 0;
            if(sqlite3_step(statement) == SQLITE_DONE &&
               (nLastChanges = sqlite3_total_changes(db)) == 1)
            {
                success = YES;
                
                [self deleteItemImage:oldImagePath];    //delete the image if no item, barcode or shopping item use it
            } else {
                if(nLastChanges != 1) {
                    errMsg = [NSString stringWithFormat:@"Fail to update barcode: %d changes", nLastChanges];
                } else {
                    errMsg = [NSString stringWithFormat:@"Fail to update barcode: %s", sqlite3_errmsg(db)];
                }

                NSLog(@"%@", errMsg);
            }
            sqlite3_finalize(statement);
        }
        sqlite3_close(db);
        
        return success;
    }
}

- (BOOL)updateBarcode:(Barcode *)barcode withFolder:(Folder *)folder
{
    if(barcode.ID <= 0) {
        NSLog(@"Fail to update barcode: add barcode to DB first");
        return NO;
    }
    
    if(folder.ID <= 0) {
        NSLog(@"Fail to update barcode: add folder to DB first");
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        
        sqlite3_stmt *statement = NULL;
        BOOL success = NO;
        int nBindColumn = 1;
        NSString *command = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?;",
                             kTableBarcode, kBarcodeColumnFolderID, kBarcodeColumnID];
        
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, nBindColumn++, folder.ID);
            sqlite3_bind_int(statement, nBindColumn++, barcode.ID);
            
            int nLastChanges = 0;
            if(sqlite3_step(statement) == SQLITE_DONE &&
               (nLastChanges = sqlite3_total_changes(db)) == 1)
            {
                success = YES;
            } else {
                if(nLastChanges != 1) {
                    errMsg = [NSString stringWithFormat:@"Fail to update barcode: %d changes", nLastChanges];
                } else {
                    errMsg = [NSString stringWithFormat:@"Fail to update barcode: %s", sqlite3_errmsg(db)];
                }
                
                NSLog(@"%@", errMsg);
            }
            sqlite3_finalize(statement);
        }
        sqlite3_close(db);
        
        return success;
    }
}

- (Barcode *)getBarcodeOfShoppingItem:(ShoppingItem *)shoppingItem
{
    if(shoppingItem == nil) {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        int nBarcodeID = 0;
        
        NSString *command = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@=? AND %@=?;", kItemColumnBarcodeID, kTableItem, kItemColumnName, kItemColumnImagePath];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [shoppingItem.itemName UTF8String], -1, NULL);
            sqlite3_bind_text(statement, 2, [shoppingItem.itemImagePath UTF8String], -1, NULL);

            while(sqlite3_step(statement) == SQLITE_ROW) {
                nBarcodeID = sqlite3_column_int(statement, 0);
                break;
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        Barcode *barcode = nil;
        if(nBarcodeID > 0) {
            barcode = [self getBarcodeByID:nBarcodeID];
        }

        return barcode;
    }
}
//--------------------------------------------------------------
//  [END] Barcode related
//==============================================================

- (NSMutableArray *)getAllExpireDatesSince:(NSDate *)date isDistinct:(BOOL)distinct
{
    if([date timeIntervalSince1970] <= 0) {
        return nil;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        

        sqlite3_stmt *statement = NULL;
        NSMutableArray *dateArray = [NSMutableArray array];
        int time;
        NSString *command = nil;

        //1. Not archived
        //2. Count > 0
        //3.Time > 0 and < days from today
        if(distinct) {
            command = [NSString stringWithFormat:@"SELECT DISTINCT %@ FROM %@ WHERE %@>=? AND %@ IS NOT 1 AND %@ > 0 ORDER BY %@;",
                       kItemColumnExpireTime, kTableItem, kItemColumnExpireTime, kItemColumnArchived, kItemColumnCount, kItemColumnExpireTime];
        } else {
            command = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@>=? AND %@ IS NOT 1 AND %@ > 0 ORDER BY %@;",
                       kItemColumnExpireTime, kTableItem, kItemColumnExpireTime, kItemColumnArchived, kItemColumnCount, kItemColumnExpireTime];
        }

        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            NSTimeInterval expTime = [date timeIntervalSince1970];
            if(expTime == 0) expTime = 1;
            sqlite3_bind_int(statement, 1, expTime);

            while(sqlite3_step(statement) == SQLITE_ROW) {
                time = sqlite3_column_int(statement, 0);
                [dateArray addObject:[NSDate dateWithTimeIntervalSince1970:time]];
            }
            sqlite3_finalize(statement);
        }
        sqlite3_close(db);
        
        return dateArray;
    }
}

- (NSMutableArray *)getItemsHaveExpiredDayIncludeArchived:(BOOL)includeArchived
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        
        sqlite3_stmt *statement = NULL;
        NSMutableArray *itemArray = [NSMutableArray array];
        NSString *command;
        if(includeArchived) {
            command = [NSString stringWithFormat:@"SELECT %@,%@,%@ FROM %@ WHERE %@>0 AND %@ > 0 ORDER BY %@;",
                       kItemColumnID, kItemColumnExpireTime, kItemColumnNearExpiredDays, kTableItem, kItemColumnExpireTime, kItemColumnCount,  kItemColumnExpireTime];
        } else {
            command = [NSString stringWithFormat:@"SELECT %@,%@,%@ FROM %@ WHERE %@>0 AND %@ IS NOT 1 AND %@ > 0 ORDER BY %@;",
                       kItemColumnID, kItemColumnExpireTime, kItemColumnNearExpiredDays, kTableItem, kItemColumnExpireTime, kItemColumnArchived, kItemColumnCount, kItemColumnExpireTime];
        }

        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                [itemArray addObject: [self getItemFromQueryResult:statement skipColumn:nil]];
            }
            sqlite3_finalize(statement);
        }
        sqlite3_close(db);
        
        return itemArray;
    }
}

- (NSMutableArray *)getImagesInFolder:(Folder *)folder
{
    if(folder == nil ||
       folder.ID == 0)
    {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }

        NSMutableArray *imagePaths = [NSMutableArray array];
        sqlite3_stmt *statement = NULL;
        char *strImagePath;
        int nBindColumn = 1;
        NSString *command = [NSString stringWithFormat:@"SELECT DISTINCT %@ FROM %@ WHERE %@=?;",
                             kItemColumnImagePath, kTableItem, kItemColumnFolderID];
        
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, nBindColumn++, folder.ID);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                strImagePath = (char *)sqlite3_column_text(statement, 0);
                if(strImagePath) {
                    [imagePaths addObject: [NSString stringWithCString:strImagePath encoding:NSUTF8StringEncoding]];
                }
            }

            sqlite3_finalize(statement);
        }
        sqlite3_close(db);
        
        return imagePaths;
    }
}
//==============================================================
//  [BEGIN] Location Related APIs
#pragma mark - Location Related APIs
//--------------------------------------------------------------
- (Location *)_getLocationFromQueryResult:(sqlite3_stmt *)statement skipColumn:(NSString *)skipColumnName
{
    if(statement == NULL) {
        return nil;
    }
    

    Location *location = [[Location alloc] init];
    BOOL hasMapData = NO;
    double dLatitude=0, dLongitude=0, dAltitude=0, dHAccuracy=0, dVAccuracy=0;

    char *strTextResult = NULL;
    for(int column = sqlite3_column_count(statement) - 1; column >= 0; column--) {
        if(sqlite3_column_bytes(statement, column) == 0) {
//            NSLog(@"Skip empty column: %s", sqlite3_column_name(statement, column));
            continue;
        }
        
        NSString *columnName = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, column)];
        if([columnName isEqualToString:skipColumnName]) {
            continue;
        }
        
        if([columnName isEqualToString: kItemColumnID]) {
            location.ID = sqlite3_column_int(statement, column);
        } else if([columnName isEqualToString: kItemColumnName]) {
            strTextResult = (char *)sqlite3_column_text(statement, column);
            if(strTextResult) {
                location.name = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
            }
        } else if([columnName isEqualToString:kLocationColumnLatitude]) {
            hasMapData = YES;
            dLatitude = sqlite3_column_double(statement, column);
        } else if([columnName isEqualToString:kLocationColumnLongitude]) {
            hasMapData = YES;
            dLongitude = sqlite3_column_double(statement, column);
        } else if([columnName isEqualToString:kLocationColumnAltitude]) {
            hasMapData = YES;
            dAltitude = sqlite3_column_double(statement, column);
        } else if([columnName isEqualToString:kLocationColumnHorizontalAccuracy]) {
            hasMapData = YES;
            dHAccuracy = sqlite3_column_double(statement, column);
        } else if([columnName isEqualToString:kLocationColumnVerticalAccuracy]) {
            hasMapData = YES;
            dVAccuracy = sqlite3_column_double(statement, column);
        } else if([columnName isEqualToString:kLocationColumnAddress]) {
            strTextResult = (char *)sqlite3_column_text(statement, column);
            if(strTextResult) {
                location.address = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
            }
        } else if([columnName isEqualToString:kLocationColumnListPosition]) {
            location.nListPosition = sqlite3_column_int(statement, column);
        }
    }
    
    if(hasMapData) {
        location.locationData = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(dLatitude, dLongitude)
                                                              altitude:dAltitude
                                                    horizontalAccuracy:dHAccuracy
                                                      verticalAccuracy:dVAccuracy
                                                             timestamp:nil];
    }

    return location;
}

- (BOOL)addLocation:(Location *)location
{
    if(location.nListPosition < 0 ||
       [location.name length] == 0)
    {
        return NO;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        
        //Update list positions of all other 
        NSString * command = [NSString stringWithFormat:@"UPDATE %@ SET %@=%@+1 WHERE %@>=?;", kTableLocation, kLocationColumnListPosition, kLocationColumnListPosition, kLocationColumnListPosition];
        
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, location.nListPosition);
            
            if(sqlite3_step(statement) != SQLITE_DONE) {
                NSLog(@"Fail to update positions");
            }
            
            sqlite3_finalize(statement);
        }
        
        //Add location
        int field = 1;
        if(location.locationData) {
            command = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@, %@, %@, %@, %@, %@) VALUES (?, ?, ?, ?, ?, ?, ?, ?);", kTableLocation, kLocationColumnName, kLocationColumnLatitude, kLocationColumnLongitude, kLocationColumnAltitude, kLocationColumnHorizontalAccuracy, kLocationColumnVerticalAccuracy, kLocationColumnAddress, kLocationColumnListPosition];
            
            if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                sqlite3_bind_text(statement, field++, [location.name UTF8String], -1, NULL);
                sqlite3_bind_double(statement,  field++, location.locationData.coordinate.latitude);
                sqlite3_bind_double(statement,  field++, location.locationData.coordinate.longitude);
                sqlite3_bind_double(statement,  field++, location.locationData.altitude);
                sqlite3_bind_double(statement,  field++, location.locationData.horizontalAccuracy);
                sqlite3_bind_double(statement,  field++, location.locationData.verticalAccuracy);
                sqlite3_bind_text(statement, field++, [location.address UTF8String], -1, NULL);
                sqlite3_bind_int(statement, field++, location.nListPosition);
            }
        } else {
            command = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@) VALUES (?, ?, ?);", kTableLocation, kLocationColumnName,  kLocationColumnAddress, kLocationColumnListPosition];
            
            if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                sqlite3_bind_text(statement, field++, [location.name UTF8String], -1, NULL);
                sqlite3_bind_text(statement, field++, [location.address UTF8String], -1, NULL);
                sqlite3_bind_int(statement, field++, location.nListPosition);
            }
        }
        
        BOOL success = NO;
        if(sqlite3_step(statement) == SQLITE_DONE) {
            success = YES;
            location.ID = sqlite3_last_insert_rowid(db);
        } else {
            errMsg = [NSString stringWithFormat:@"Fail to add location: %s", sqlite3_errmsg(db)];
            NSLog(@"%@", errMsg);
        }
        sqlite3_finalize(statement);
        
        sqlite3_close(db);

        return success;
    }
}

- (BOOL)removeLocation:(Location *)location
{
    if(!location ||
       location.ID <= 0)
    {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        BOOL success = NO;
        sqlite3_stmt *statement = NULL;
        
        //1. Remove items which has the location
        NSString *command = [NSString stringWithFormat:@"UPDATE %@ SET %@='' WHERE %@=?;", kTableItem, kItemColumnLocationID, kItemColumnLocationID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, location.ID);
            
            if(sqlite3_step(statement) == SQLITE_DONE) {
                success = YES;
            }
            
            sqlite3_finalize(statement);
        }
        
        //2. remove the location
        if(success) {
            command = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=?;", kTableLocation, kLocationColumnID];
            if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                sqlite3_bind_int(statement, 1, location.ID);
                
                if(sqlite3_step(statement) == SQLITE_ERROR) {
                    success = NO;
                    errMsg = [NSString stringWithFormat:@"Fail to remove location: %s", sqlite3_errmsg(db)];
                }
                
                sqlite3_finalize(statement);
            }
        }
        
        //3. Adjust list positions of other locations
        if(success) {
            command = [NSString stringWithFormat:@"UPDATE %@ SET %@=%@-1 WHERE %@>=?;", kTableLocation, kLocationColumnListPosition, kLocationColumnListPosition, kLocationColumnListPosition];
            
            if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                sqlite3_bind_int(statement, 1, location.nListPosition);
                
                if(sqlite3_step(statement) != SQLITE_DONE) {
                    NSLog(@"Fail to update list positions");
                }
                
                sqlite3_finalize(statement);
            }
        }
        
        return success;
    }
}

- (Location *)getLocationByName:(NSString *)name
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        Location *location = nil;
        
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=?;", kTableLocation, kLocationColumnName];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [name UTF8String], -1, NULL);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                location = [self _getLocationFromQueryResult:statement skipColumn:kLocationColumnName];
                location.name = name;
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        //Caller must retain or copy this
        return location;
    }
}

- (Location *)getLocationByID:(int)ID
{
    if(ID <= 0) {
        return nil;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        Location *location = nil;
        
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=?;", kTableLocation, kLocationColumnID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, ID);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                location = [self _getLocationFromQueryResult:statement skipColumn:nil];
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        return location;
    }
}

- (BOOL)isLocationExistWithName:(NSString *)name
{
    if([name length] == 0) {
        return NO;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        BOOL isLocationExist = NO;
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=?;", kTableLocation, kLocationColumnName];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [name UTF8String], -1, NULL);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                if(sqlite3_column_int(statement, 0) > 0) {
                    isLocationExist = YES;
                }
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return isLocationExist;
    }
}

- (BOOL)isLocationExistWithID:(int)ID
{
    if(ID <= 0) {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        BOOL isLocationExist = NO;
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=?;", kTableLocation, kLocationColumnID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, ID);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                if(sqlite3_column_int(statement, 0) > 0) {
                    isLocationExist = YES;
                }
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return isLocationExist;
    }
}

- (void)moveLocation:(Location *)location to:(int)newPosition
{
    if(location.nListPosition == newPosition) {
        return;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return;
        }
        
        sqlite3_stmt *statement = NULL;
        NSString *command = nil;
        
        //Update Positions between old and new position
        if(location.nListPosition < newPosition) { //Move downward
            command = [NSString stringWithFormat:@"UPDATE %@ SET %@=%@-1 WHERE %@<=? AND %@>?;", kTableLocation, kLocationColumnListPosition, kLocationColumnListPosition, kLocationColumnListPosition, kLocationColumnListPosition];
        } else {                                   //Move upward
            command = [NSString stringWithFormat:@"UPDATE %@ SET %@=%@+1 WHERE %@>=? AND %@<?;", kTableLocation, kLocationColumnListPosition, kLocationColumnListPosition, kLocationColumnListPosition, kLocationColumnListPosition];
        }

        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, newPosition);
            sqlite3_bind_int(statement, 2, location.nListPosition);
            
            if(sqlite3_step(statement) != SQLITE_DONE) {
                NSLog(@"Fail to update positions");
            }
            
            sqlite3_finalize(statement);
        }
        
        //Update current location
        command = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?;", kTableLocation, kLocationColumnListPosition, kLocationColumnID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, newPosition);
            sqlite3_bind_int(statement, 2, location.ID);

            if(sqlite3_step(statement) != SQLITE_DONE) {
                errMsg = [NSString stringWithFormat:@"Fail to update position of %@: %s", location.name, sqlite3_errmsg(db)];
                NSLog(@"%@", errMsg);
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
    }
}

- (BOOL)updateLocation:(Location *)location
{
    if(!location ||
       location.ID <= 0)
    {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        
        BOOL success = NO;
        int column = 1;
        NSString *command;
        if(location.locationData) {
            command = [NSString stringWithFormat:@"UPDATE %@ SET %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=? WHERE %@=?;",
                                 kTableLocation, kLocationColumnName, kLocationColumnLatitude, kLocationColumnLongitude, kLocationColumnAltitude, kLocationColumnHorizontalAccuracy, kLocationColumnVerticalAccuracy, kLocationColumnAddress, kLocationColumnListPosition, kLocationColumnID];
            
            if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                sqlite3_bind_text(statement,   column++, [location.name UTF8String], -1, NULL);
                sqlite3_bind_double(statement, column++, location.locationData.coordinate.latitude);
                sqlite3_bind_double(statement, column++, location.locationData.coordinate.longitude);
                sqlite3_bind_double(statement, column++, location.locationData.altitude);
                sqlite3_bind_double(statement, column++, location.locationData.horizontalAccuracy);
                sqlite3_bind_double(statement, column++, location.locationData.verticalAccuracy);
                sqlite3_bind_text(statement,   column++, [location.address UTF8String], -1, NULL);
                sqlite3_bind_int(statement,    column++, location.nListPosition);
                sqlite3_bind_int(statement,    column++, location.ID);
                
                int nLastChanges = 0;
                if(sqlite3_step(statement) == SQLITE_DONE &&
                   (nLastChanges = sqlite3_total_changes(db)) == 1)
                {
                    success = YES;
                } else {
                    if(nLastChanges != 1) {
                        errMsg = [NSString stringWithFormat:@"Fail to update location: %d changes", nLastChanges];
                    } else {
                        errMsg = [NSString stringWithFormat:@"Fail to update location: %s", sqlite3_errmsg(db)];
                    }
                    
                    NSLog(@"%@", errMsg);
                }
                sqlite3_finalize(statement);
            }
        } else {
            command = [NSString stringWithFormat:@"UPDATE %@ SET %@=?, %@='', %@='', %@='', %@='', %@='', %@=?, %@=? WHERE %@=?;",
                       kTableLocation, kLocationColumnName, kLocationColumnLatitude, kLocationColumnLongitude, kLocationColumnAltitude, kLocationColumnHorizontalAccuracy, kLocationColumnVerticalAccuracy, kLocationColumnAddress, kLocationColumnListPosition, kLocationColumnID];
            
            if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                sqlite3_bind_text(statement,   column++, [location.name UTF8String], -1, NULL);
                sqlite3_bind_text(statement,   column++, [location.address UTF8String], -1, NULL);
                sqlite3_bind_int(statement,    column++, location.nListPosition);
                sqlite3_bind_int(statement,    column++, location.ID);
                
                int nLastChanges = 0;
                if(sqlite3_step(statement) == SQLITE_DONE &&
                   (nLastChanges = sqlite3_total_changes(db)) == 1)
                {
                    success = YES;
                } else {
                    if(nLastChanges != 1) {
                        errMsg = [NSString stringWithFormat:@"Fail to update location: %d changes", nLastChanges];
                    } else {
                        errMsg = [NSString stringWithFormat:@"Fail to update location: %s", sqlite3_errmsg(db)];
                    }
                    
                    NSLog(@"%@", errMsg);
                }
                sqlite3_finalize(statement);
            }
        }
        
        sqlite3_close(db);
        
        return success;
    }
}

- (NSString *)getLocationNameById:(int)ID
{
    if(ID <= 0) {
        return nil;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        NSString *name = nil;
        
        NSString *command = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@=?;", kLocationColumnName, kTableLocation, kLocationColumnID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, ID);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                char *strResult = (char *)sqlite3_column_text(statement, 1);
                if(strResult) {
                    name = [NSString stringWithCString:strResult encoding:NSUTF8StringEncoding];
                }
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        return name;
    }
}

- (NSMutableArray *)getAllLocations
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        NSMutableArray *locationList = [NSMutableArray array];
        Location *location;
        
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ ORDER BY %@;", kTableLocation, kLocationColumnListPosition];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                location = [self _getLocationFromQueryResult:statement skipColumn:nil];
                [locationList addObject:location];
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return locationList;
    }
}

- (BOOL)shouldImportLocationsForCountry:(NSString *)countryCode
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

- (BOOL)importLocationsInCountry:(NSString *)countryCode
{
    if([countryCode length] == 0) {
        return NO;
    }

    @synchronized(self) {
        BOOL success = YES;
        
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
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
            return YES;
        }
        
        //Get all locaitons
        sqlite3_stmt *statement = NULL;
        NSMutableArray *locationNameList = [NSMutableArray array];
        char *strTextResult;
        NSString *locationName;
        int nListPosition = -1;

        int column;
        NSString *columnName;
        NSString *command = [NSString stringWithFormat:@"SELECT %@, %@ FROM %@ ORDER BY %@;",
                             kLocationColumnName, kLocationColumnListPosition, kTableLocation, kLocationColumnListPosition];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                for(column = sqlite3_column_count(statement) - 1; column >= 0; column--) {
                    columnName = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, column)];

                    if([columnName isEqualToString:kLocationColumnListPosition]) {
                        nListPosition = sqlite3_column_int(statement, column);
                    } else if([columnName isEqualToString:kLocationColumnName]) {
                        strTextResult = (char *)sqlite3_column_text(statement, column);
                        if(strTextResult && strlen(strTextResult) > 0) {
                            locationName = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
                            [locationNameList addObject:locationName];
                        }
                    }
                }
            }
            
            sqlite3_finalize(statement);
        }
        nListPosition++;    //position to add new location
        
        //Import locations
        NSArray *prebuildLocations = nil;
        NSString *prebuildLocation;
        BOOL locationExisted = NO;
        for(NSString *prebuildVersion in prebuildLocationVersions) {
            if([VersionCompare compareVersion:currentVersion toVersion:prebuildVersion] != NSOrderedAscending) {
                continue;
            }

            prebuildLocations = [prebuildVersionToLocationMap objectForKey:prebuildVersion];
            for(prebuildLocation in prebuildLocations) {
                //Find out the location is exited or not
                locationExisted = NO;
                for(locationName in locationNameList) {
                    if([locationName caseInsensitiveCompare:prebuildLocation] == NSOrderedSame) {
                        locationExisted = YES;
                        break;
                    }
                }
                
                if(locationExisted) {
                    continue;
                }
                
                //If not exites, add to database
                command = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@) VALUES (?, ?);",
                           kTableLocation, kLocationColumnName, kLocationColumnListPosition];
                
                if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                    sqlite3_bind_text(statement, 1, [prebuildLocation UTF8String], -1, NULL);
                    sqlite3_bind_int(statement,  2, nListPosition);
                }
                
                if(sqlite3_step(statement) == SQLITE_DONE) {
                    nListPosition++;
                } else {
                    errMsg = [NSString stringWithFormat:@"Fail to add location %@: %s", prebuildLocation, sqlite3_errmsg(db)];
                    NSLog(@"%@", errMsg);
                    success = NO;
                }
                sqlite3_finalize(statement);
            }
            
            currentVersion = prebuildVersion;
        }
        
        [importedLocations setValue:currentVersion forKey:countryCode];
        [[NSUserDefaults standardUserDefaults] setValue:importedLocations forKey:kImpotedLocationKey];
        [[NSUserDefaults standardUserDefaults] synchronize];

        return success;
    }
}
//--------------------------------------------------------------
//  [END] Location Related APIs
//==============================================================

//==============================================================
//  [BEGIN] Shopping List Related APIs
#pragma mark - Shopping List Related APIs
//--------------------------------------------------------------
- (ShoppingItem *)getShoppingItemFromFolderItem:(FolderItem *)item
{
    BOOL hasName = ([item.name length] > 0) ? YES : NO;
    BOOL hasImage = ([item.imagePath length] > 0) ? YES : NO;
    
    if(item == nil ||
       (!hasName && !hasImage)) //barcode is not human readable...
    {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        ShoppingItem *shoppingItem = nil;
        NSString *command = nil;
        
        if(hasName) {
            if(hasImage) {
                command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=? AND %@=? LIMIT 1;",
                           kTableShoppingList, kShoppingListColumnItemName, kShoppingListColumnItemImagePath];
            } else {
                //Name only
                command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=? AND (%@='' OR %@ IS NULL) LIMIT 1;",
                           kTableShoppingList, kShoppingListColumnItemName, kShoppingListColumnItemImagePath, kShoppingListColumnItemImagePath];
            }
        } else {
            //Image Only
            command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE (%@='' OR %@ IS NULL) AND %@=? LIMIT 1;",
                       kTableShoppingList, kShoppingListColumnItemName, kShoppingListColumnItemName, kShoppingListColumnItemImagePath];
        }
        
        int column = 1;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            if(hasName) {
                if(hasImage) {
                    sqlite3_bind_text(statement, column++, [item.name UTF8String], -1, NULL);
                    sqlite3_bind_text(statement, column++, [item.imagePath UTF8String], -1, NULL);
                } else {
                    //Name only
                    sqlite3_bind_text(statement, column++, [item.name UTF8String], -1, NULL);
                }
            } else {
                //Image Only
                sqlite3_bind_text(statement, column++, [item.imagePath UTF8String], -1, NULL);
            }
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                shoppingItem = [self getShoppingItemFromQueryResult:statement skipColumn:nil];
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return shoppingItem;
    }
}

- (BOOL)isShoppingItemExisted:(ShoppingItem *)shoppingItem
{
    BOOL hasName = ([shoppingItem.itemName length] > 0) ? YES : NO;
    BOOL hasImage = ([shoppingItem.itemImagePath length] > 0) ? YES : NO;

    if(shoppingItem == nil ||
       (shoppingItem.itemImage == nil &&
        !hasName &&
        !hasImage))
    {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        BOOL isItemExists = NO;
        NSString *command = nil;
        
        if(hasName) {
            if(hasImage) {
                command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=? AND %@=? LIMIT 1;",
                           kTableShoppingList, kShoppingListColumnItemName, kShoppingListColumnItemImagePath];
            } else {
                //Name only
                command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=? AND (%@='' OR %@ IS NULL) LIMIT 1;",
                           kTableShoppingList, kShoppingListColumnItemName, kShoppingListColumnItemImagePath, kShoppingListColumnItemImagePath];
            }
        } else {
            //Image Only
            command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE (%@='' OR %@ IS NULL) AND %@=? LIMIT 1;",
                       kTableShoppingList, kShoppingListColumnItemName, kShoppingListColumnItemName, kShoppingListColumnItemImagePath];
        }
        
        int column = 1;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            if(hasName) {
                if(hasImage) {
                    sqlite3_bind_text(statement, column++, [shoppingItem.itemName UTF8String], -1, NULL);
                    sqlite3_bind_text(statement, column++, [shoppingItem.itemImagePath UTF8String], -1, NULL);
                } else {
                    //Name only
                    sqlite3_bind_text(statement, column++, [shoppingItem.itemName UTF8String], -1, NULL);
                }
            } else {
                //Image Only
                sqlite3_bind_text(statement, column++, [shoppingItem.itemImagePath UTF8String], -1, NULL);
            }

            while(sqlite3_step(statement) == SQLITE_ROW) {
                if(sqlite3_column_int(statement, 0) > 0) {
                    isItemExists = YES;
                }
                break;
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return isItemExists;
    }
}

- (BOOL)isItemInShoppingList:(FolderItem *)item
{
    BOOL hasName = ([item.name length] > 0) ? YES : NO;
    BOOL hasImage = ([item.imagePath length] > 0) ? YES : NO;

    if(item == nil ||
       (!hasName && !hasImage)) //barcode is not human readable...
    {
        return NO;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        
        sqlite3_stmt *statement = NULL;
        BOOL isItemExists = NO;
        NSString *command = nil;
        
        if(hasName) {
            if(hasImage) {
                command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=? AND %@=? LIMIT 1;",
                           kTableShoppingList, kShoppingListColumnItemName, kShoppingListColumnItemImagePath];
            } else {
                //Name only
                command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=? AND (%@='' OR %@ IS NULL) LIMIT 1;",
                           kTableShoppingList, kShoppingListColumnItemName, kShoppingListColumnItemImagePath, kShoppingListColumnItemImagePath];
            }
        } else {
            //Image Only
            command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE (%@='' OR %@ IS NULL) AND %@=? LIMIT 1;",
                       kTableShoppingList, kShoppingListColumnItemName, kShoppingListColumnItemName, kShoppingListColumnItemImagePath];
        }
        
        int column = 1;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            if(hasName) {
                if(hasImage) {
                    sqlite3_bind_text(statement, column++, [item.name UTF8String], -1, NULL);
                    sqlite3_bind_text(statement, column++, [item.imagePath UTF8String], -1, NULL);
                } else {
                    //Name only
                    sqlite3_bind_text(statement, column++, [item.name UTF8String], -1, NULL);
                }
            } else {
                //Image Only
                sqlite3_bind_text(statement, column++, [item.imagePath UTF8String], -1, NULL);
            }
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                if(sqlite3_column_int(statement, 0) > 0) {
                    isItemExists = YES;
                }
                break;
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return isItemExists;
    }
}

- (ShoppingItem *)addItemToShoppingList:(FolderItem *)item
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        ShoppingItem *shoppingItem = [[ShoppingItem alloc] initFromFolderItem:item];
        
        NSString *command = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@, %@, %@, %@, %@) VALUES (?, ?, ?, ?, ?, ?, ?);", kTableShoppingList, kShoppingListColumnItemName, kShoppingListColumnItemImagePath, kShoppingListColumnOriginFolderID, kShoppingListColumnCount, kShoppingListColumnListPosition, kShoppingListColumnHasBought, kShoppingListColumnPrice];
        
        int field = 1;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, field++, [shoppingItem.itemName UTF8String], -1, NULL);
            sqlite3_bind_text(statement, field++, [shoppingItem.itemImagePath UTF8String], -1, NULL);
            sqlite3_bind_int(statement, field++, shoppingItem.originalFolderID);
            sqlite3_bind_int(statement, field++, shoppingItem.shoppingCount);
            sqlite3_bind_int(statement, field++, shoppingItem.listPosition);
            sqlite3_bind_int(statement, field++, shoppingItem.hasBought);
            sqlite3_bind_double(statement, field++, shoppingItem.price);
        }
        
        if(sqlite3_step(statement) == SQLITE_DONE) {
            item.isInShoppingList = YES;
            shoppingItem.ID = sqlite3_last_insert_rowid(db);
        } else {
            shoppingItem = nil;
            errMsg = [NSString stringWithFormat:@"Fail to add shopping item: %s", sqlite3_errmsg(db)];
            NSLog(@"%@", errMsg);
        }
        sqlite3_finalize(statement);
        
        sqlite3_close(db);
        
        return shoppingItem;
    }
}

- (BOOL)addNewShoppingItem:(ShoppingItem *)shoppingItem
{
    if(shoppingItem.ID != 0 ||
       ([shoppingItem.itemName length] == 0 &&
        [shoppingItem.itemImagePath length] == 0))
    {
        return NO;
    }

    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        
        NSString *command = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@, %@, %@, %@, %@) VALUES (?, ?, ?, ?, ?, ?, ?);", kTableShoppingList, kShoppingListColumnItemName, kShoppingListColumnItemImagePath, kShoppingListColumnOriginFolderID, kShoppingListColumnCount, kShoppingListColumnListPosition, kShoppingListColumnHasBought, kShoppingListColumnPrice];
        
        int field = 1;
        BOOL success = NO;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, field++, [shoppingItem.itemName UTF8String], -1, NULL);
            sqlite3_bind_text(statement, field++, [shoppingItem.itemImagePath UTF8String], -1, NULL);
            sqlite3_bind_int(statement, field++, shoppingItem.originalFolderID);
            sqlite3_bind_int(statement, field++, shoppingItem.shoppingCount);
            sqlite3_bind_int(statement, field++, shoppingItem.listPosition);
            sqlite3_bind_int(statement, field++, shoppingItem.hasBought);
            sqlite3_bind_double(statement, field++, shoppingItem.price);
        }
        
        if(sqlite3_step(statement) == SQLITE_DONE) {
            shoppingItem.ID = sqlite3_last_insert_rowid(db);
            success = YES;
        } else {
            shoppingItem = nil;
            errMsg = [NSString stringWithFormat:@"Fail to add shopping item: %s", sqlite3_errmsg(db)];
            NSLog(@"%@", errMsg);
        }
        sqlite3_finalize(statement);
        
        sqlite3_close(db);
        
        return success;
    }
}

- (ShoppingItem *)getShoppintItemByID:(int)ID
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        ShoppingItem *shoppingItem;
        
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=?;", kTableShoppingList, kShoppingListColumnID];
        
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, ID);
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                shoppingItem = [self getShoppingItemFromQueryResult:statement skipColumn:nil];
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        //Caller must retain or copy this
        return shoppingItem;
    }
}

- (BOOL)removeShoppingListItem:(ShoppingItem *)shoppingItem
{
    BOOL success = NO;
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        int nTotalChanges = 0;
        
        NSString *command = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=?;", kTableShoppingList, kShoppingListColumnID];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, shoppingItem.ID);
            
            if(sqlite3_step(statement) == SQLITE_DONE &&
               (nTotalChanges = sqlite3_total_changes(db)) == 1)
            {
                success = YES;
                
                //Delete unused(item or barcode) image
                [self deleteItemImage:shoppingItem.itemImagePath];
            } else {
                if(nTotalChanges != 1) {
                    errMsg = [NSString stringWithFormat:@"Fail to remove shopping item %d: total changes %d", shoppingItem.ID, nTotalChanges];
                } else {
                    errMsg = [NSString stringWithFormat:@"Fail to remove shopping item %d: %s", shoppingItem.ID, sqlite3_errmsg(db)];
                }
                NSLog(@"%@", errMsg);
            }
            
            sqlite3_finalize(statement);
        }
        
        //3. Adjust list positions of other items
        if(success) {
            command = [NSString stringWithFormat:@"UPDATE %@ SET %@=%@-1 WHERE %@>=?;", kTableShoppingList, kShoppingListColumnListPosition, kShoppingListColumnListPosition, kShoppingListColumnListPosition];
            
            if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                sqlite3_bind_int(statement, 1, shoppingItem.listPosition);
                
                if(sqlite3_step(statement) != SQLITE_DONE) {
                    NSLog(@"Fail to update shopping list positions");
                }
                
                sqlite3_finalize(statement);
            }
        }
        
        sqlite3_close(db);
        
        return success;
    }
}

- (BOOL)removeFolderItemFromShoppingList:(FolderItem *)item
{
    @synchronized(self) {
        ShoppingItem *shoppingItem = [self getShoppingItemFromFolderItem:item];
        if(shoppingItem == nil) {
            NSLog(@"Shopping item not found");
            return YES;
        }
        
        return [self removeShoppingListItem:shoppingItem];
    }
}

- (BOOL)updateShoppingItem:(ShoppingItem *)shoppingItem
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        NSString *command = [NSString stringWithFormat:@"UPDATE %@ SET %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=? WHERE %@=?;", kTableShoppingList, kShoppingListColumnItemName, kShoppingListColumnItemImagePath, kShoppingListColumnOriginFolderID, kShoppingListColumnCount, kShoppingListColumnListPosition, kShoppingListColumnHasBought, kShoppingListColumnPrice, kShoppingListColumnID];
        
        BOOL success = NO;
        int field = 1;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_text(statement, field++, [shoppingItem.itemName UTF8String], -1, NULL);
            sqlite3_bind_text(statement, field++, [shoppingItem.itemImagePath UTF8String], -1, NULL);
            sqlite3_bind_int(statement, field++, shoppingItem.originalFolderID);
            sqlite3_bind_int(statement, field++, shoppingItem.shoppingCount);
            sqlite3_bind_int(statement, field++, shoppingItem.listPosition);
            sqlite3_bind_int(statement, field++, shoppingItem.hasBought);
            sqlite3_bind_int(statement, field++, shoppingItem.price);

            sqlite3_bind_int(statement, field++, shoppingItem.ID);
        }
        
        if(sqlite3_step(statement) == SQLITE_DONE) {
            success = YES;
        } else {
            errMsg = [NSString stringWithFormat:@"Fail to update shopping item: %s", sqlite3_errmsg(db)];
            NSLog(@"%@", errMsg);
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);
        
        return success;
    }
}

- (BOOL)updateShoppingItemPosition:(ShoppingItem *)shoppingItem
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        NSString *command = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?;", kTableShoppingList, kShoppingListColumnListPosition, kShoppingListColumnID];
        
        BOOL success = NO;
        int field = 1;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, field++, shoppingItem.listPosition);

            sqlite3_bind_int(statement, field++, shoppingItem.ID);
        }
        
        if(sqlite3_step(statement) == SQLITE_DONE) {
            success = YES;
        } else {
            errMsg = [NSString stringWithFormat:@"Fail to update shopping item position: %s", sqlite3_errmsg(db)];
            NSLog(@"%@", errMsg);
        }
        sqlite3_finalize(statement);
        sqlite3_close(db);
        
        return success;
    }
}

- (BOOL)moveShoppingItem:(ShoppingItem *)shoppingItem to:(int)newPosition
{
    if(shoppingItem.listPosition == newPosition) {
        return YES;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return NO;
        }
        
        sqlite3_stmt *statement = NULL;
        NSString *command = nil;
        BOOL success = NO;
        
        //Update Positions between old and new position
        if(shoppingItem.listPosition < newPosition) {   //Move downward
            command = [NSString stringWithFormat:@"UPDATE %@ SET %@=%@-1 WHERE %@<=? AND %@>?;", kTableShoppingList, kShoppingListColumnListPosition, kShoppingListColumnListPosition, kShoppingListColumnListPosition, kShoppingListColumnListPosition];
        } else {                                //Move upward
            command = [NSString stringWithFormat:@"UPDATE %@ SET %@=%@+1 WHERE %@>=? AND %@<?;", kTableShoppingList, kShoppingListColumnListPosition, kShoppingListColumnListPosition, kShoppingListColumnListPosition, kShoppingListColumnListPosition];
        }
        
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            sqlite3_bind_int(statement, 1, newPosition);
            sqlite3_bind_int(statement, 2, shoppingItem.listPosition);
            
            if(sqlite3_step(statement) == SQLITE_DONE) {
                success = YES;
            } else {
                NSLog(@"Fail to update positions");
            }
            
            sqlite3_finalize(statement);
        }
        
        //Update current location
        if(success) {
            success = NO;

            command = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?;", kTableShoppingList, kShoppingListColumnListPosition, kShoppingListColumnID];
            if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
                sqlite3_bind_int(statement, 1, newPosition);
                sqlite3_bind_int(statement, 2, shoppingItem.ID);
                
                if(sqlite3_step(statement) == SQLITE_DONE) {
                    success = YES;
                } else {
                    errMsg = [NSString stringWithFormat:@"Fail to update position of %@: %s", shoppingItem.itemName, sqlite3_errmsg(db)];
                    NSLog(@"%@", errMsg);
                }
                
                sqlite3_finalize(statement);
            }
        }
        
        sqlite3_close(db);
        return success;
    }
}

- (int)totalShoppingItems
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return 0;
        }
        sqlite3_stmt *statement = NULL;
        int itemCount = 0;
        
        NSString *command = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@;", kTableShoppingList];
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            while(sqlite3_step(statement) == SQLITE_ROW) {
                itemCount = sqlite3_column_int(statement, 0);
            }
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        return itemCount;
    }
}

- (ShoppingItem *)getShoppingItemFromQueryResult:(sqlite3_stmt *)statement skipColumn:(NSString *)skipColumnName
{
    if(statement == NULL) {
        return nil;
    }
    
    ShoppingItem *item = [[ShoppingItem alloc] init];
    
    char *strTextResult = NULL;
    for(int column = sqlite3_column_count(statement) - 1; column >= 0; column--) {
        if(sqlite3_column_bytes(statement, column) == 0) {
//            NSLog(@"Skip empty column: %s", sqlite3_column_name(statement, column));
            continue;
        }
        
        NSString *columnName = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, column)];
        if([columnName isEqualToString:skipColumnName]) {
            continue;
        }
        
        if([columnName isEqualToString: kShoppingListColumnID]) {
            item.ID = sqlite3_column_int(statement, column);
        } else if([columnName isEqualToString: kShoppingListColumnItemName]) {
            strTextResult = (char *)sqlite3_column_text(statement, column);
            if(strTextResult) {
                item.itemName = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
            }
        } else if([columnName isEqualToString: kShoppingListColumnItemImagePath]) {
            strTextResult = (char *)sqlite3_column_text(statement, column);
            if(strTextResult) {
                item.itemImagePath = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
            }
        } else if([columnName isEqualToString: kShoppingListColumnOriginFolderID]) {
            item.originalFolderID = sqlite3_column_int(statement, column);
        } else if([columnName isEqualToString: kShoppingListColumnListPosition]) {
            item.listPosition = sqlite3_column_int(statement, column);
        } else if([columnName isEqualToString: kShoppingListColumnCount]) {
            item.shoppingCount = sqlite3_column_int(statement, column);
        } else if([columnName isEqualToString: kShoppingListColumnHasBought]) {
            item.hasBought = sqlite3_column_int(statement, column);
        } else if([columnName isEqualToString: kShoppingListColumnPrice]) {
            item.price = sqlite3_column_double(statement, column);
        }
    }
    
    return item;
}

- (NSMutableArray *)getShoppingList
{
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        NSMutableArray *itemList = [NSMutableArray array];
        
        //Prepare query command
        NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@ ORDER BY %@;", kTableShoppingList, kShoppingListColumnListPosition];

        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            ShoppingItem *item = nil;
            while(sqlite3_step(statement) == SQLITE_ROW) {
                item = [self getShoppingItemFromQueryResult:statement skipColumn:nil];
                [itemList addObject:item];
            }
            
            sqlite3_finalize(statement);
        } else {
            itemList = nil;
        }
        
        sqlite3_close(db);
        
        return itemList;
    }
}

- (NSMutableArray *)getItemsFromShoppingItem:(ShoppingItem *)shoppingItem
{
    BOOL hasName = ([shoppingItem.itemName length] > 0) ? YES : NO;
    BOOL hasImage = ([shoppingItem.itemImagePath length] > 0) ? YES : NO;

    if(shoppingItem == nil ||
       (!hasName && !hasImage))
    {
        return nil;
    }
    
    @synchronized(self) {
        sqlite3 *db = [self openDB];
        if(!db) {
            return nil;
        }
        
        sqlite3_stmt *statement = NULL;
        NSMutableArray *itemList = [NSMutableArray array];
        FolderItem *item = nil;
        
        NSString *command = nil;
        if(hasName) {
            if(hasImage) {
                command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=? AND %@=?;",
                           kTableItem, kItemColumnName, kItemColumnImagePath];
            } else {
                //Name only
                command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=? AND (%@='' OR %@ IS NULL);",
                           kTableItem, kItemColumnName, kItemColumnImagePath, kItemColumnImagePath];
            }
        } else {
            //Image Only
            command = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE (%@='' OR %@ IS NULL) AND %@=?;",
                       kTableItem, kItemColumnName, kItemColumnName, kItemColumnImagePath];
        }
        
        int column = 1;
        if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
            if(hasName) {
                if(hasImage) {
                    sqlite3_bind_text(statement, column++, [shoppingItem.itemName UTF8String], -1, NULL);
                    sqlite3_bind_text(statement, column++, [shoppingItem.itemImagePath UTF8String], -1, NULL);
                } else {
                    //Name only
                    sqlite3_bind_text(statement, column++, [shoppingItem.itemName UTF8String], -1, NULL);
                }
            } else {
                //Image Only
                sqlite3_bind_text(statement, column++, [shoppingItem.itemImagePath UTF8String], -1, NULL);
            }
            
            while(sqlite3_step(statement) == SQLITE_ROW) {
                item = [self getItemFromQueryResult:statement skipColumn:kItemColumnName];
                item.name = shoppingItem.itemName;
                [itemList addObject:item];
            }
            
            sqlite3_finalize(statement);
        }
        
        sqlite3_close(db);
        
        //Caller must retain or copy this
        return itemList;
    }
}

- (NSMutableArray *)getFoldersContainsItemsRelatedToShoppingItem:(ShoppingItem *)shoppingItem
{
    NSArray *items = [self getItemsFromShoppingItem:shoppingItem];
    if([items count] == 0) {
        return nil;
    }

    NSMutableArray *folderIDs = [NSMutableArray array];
    NSMutableArray *folders = [NSMutableArray array];
    NSNumber *folderID;
    Folder *folder;
    for(FolderItem *item in items) {
        folderID = [NSNumber numberWithInt:item.folderID];
        if(![folderIDs containsObject:folderID]) {
            [folderIDs addObject:[NSNumber numberWithInt:item.folderID]];
            
            folder = [self getFolderByID:item.folderID];
            if(folder &&
               [folder.lockPhrease length] == 0)
            {
                [folders addObject:folder];
            }
        }
    }
    
    return folders;
}
//--------------------------------------------------------------
//  [END] Shopping List Related APIs
//==============================================================
@end
