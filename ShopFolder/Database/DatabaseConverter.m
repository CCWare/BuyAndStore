//
//  DatabaseConverter.m
//  ShopFolder
//
//  Created by Michael on 2012/10/09.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DatabaseConverter.h"
#import "CoreDataDatabase.h"
#import "Database.h"
#import "TimeUtil.h"
#import "StringUtil.h"
#import "DBFolder+Validate.h"
#import "DBItemBasicInfo+Validate.h"
#import "DBFolderItem+Validate.h"
#import <ImageIO/ImageIO.h>
#import "DBFolderItem+ChangeLog.h"
#import "DBItemBasicInfo+SetAdnGet.h"

#define kJPEGQuality            0.75f

@implementation DatabaseConverter

- (BOOL)convertDatabase
{
//    [CoreDataDatabase resetDatabase]; //Since mainMOC must be gotten in main thread, we move this out
    NSManagedObjectContext *moc = [CoreDataDatabase getContextForCurrentThread];
    
    //Open datatabase
    sqlite3 *db = [[Database sharedSingleton] openDB];
    if(db == NULL) {
        return YES;
    }
    
    //1. Convert Folder -> DBFolder
    NSError *error;
    sqlite3_stmt *statement = NULL;
    NSString *command = [NSString stringWithFormat:@"SELECT * FROM %@;", kTableFolder];
    
    if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
        Folder *oldFolder;
        DBFolder *newFolder;
        while(sqlite3_step(statement) == SQLITE_ROW) {
            @autoreleasepool {
                oldFolder = [[Database sharedSingleton] getFolderFromQueryResult:statement skipColumn:nil];
                newFolder = [CoreDataDatabase obtainFolderInContext:moc];
                
                newFolder.name = oldFolder.name;
                newFolder.page = oldFolder.page;
                newFolder.number = oldFolder.number;
                newFolder.password = ([oldFolder.lockPhrease length] > 0) ? oldFolder.lockPhrease : nil;
                if(oldFolder.image) {
                    newFolder.imageRawData = UIImageJPEGRepresentation(oldFolder.image, kJPEGQuality);
                }
                
                if(![newFolder canSaveInContext:moc]) {
                    [newFolder.managedObjectContext deleteObject:newFolder];
                }
//                [CoreDataDatabase commitChanges:&error inContext:moc];
            }
        }
    }
    
    //2. Convert Location -> DBLocation
    NSMutableArray *oldLocations = [[Database sharedSingleton] getAllLocations];
    NSMutableDictionary *oldIdToNewLocationMap = [NSMutableDictionary dictionary];  //_ID -> DBLocation
    int nListPosition = 0;
    DBLocation *newLocation;
    for(Location *oldLocation in oldLocations) {
        newLocation = [CoreDataDatabase obtainLocationInContext:moc];
        newLocation.listPosition = nListPosition++;
        newLocation.name = oldLocation.name;
        newLocation.address = oldLocation.address;
        if(oldLocation.locationData) {
            newLocation.latitude = oldLocation.locationData.coordinate.latitude;
            newLocation.longitude = oldLocation.locationData.coordinate.longitude;
            newLocation.altitude = oldLocation.locationData.altitude;
            newLocation.verticalAccuracy = oldLocation.locationData.verticalAccuracy;
            newLocation.horizontalAccuracy = oldLocation.locationData.horizontalAccuracy;
        }
        
        [oldIdToNewLocationMap setObject:newLocation forKey:[NSNumber numberWithInt:oldLocation.ID]];
//        [CoreDataDatabase commitChanges:&error inContext:moc];
    }
    
    //3. Convert Barcode -> DBItemBasicInfo
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *imageFileAttr;
    NSDictionary *itemImageFileAttr;
    NSString *imagePath;
    UIImage *image;
    CGFloat imageWidth;
    CGFloat imageHeight;
    
    void(^getImageSizeBlock)(NSString *imagePath, CGFloat *width, CGFloat *height) = ^(NSString *imagePath, CGFloat *width, CGFloat *height) {
        NSURL *imageURL = [NSURL fileURLWithPath:[StringUtil fullPathOfItemImage:imagePath]];
        CGImageSourceRef imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)imageURL, NULL);
        CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
        if(imageProperties != NULL) {
            CFNumberRef widthNum  = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelWidth);
            if (widthNum != NULL) {
                CFNumberGetValue(widthNum, kCFNumberFloatType, width);
            }
            
            CFNumberRef heightNum = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight);
            if (heightNum != NULL) {
                CFNumberGetValue(heightNum, kCFNumberFloatType, height);
            }
            
            CFRelease(imageProperties);
        }
    };
    
    NSMutableDictionary *imagePathToBasicInfoMap = [NSMutableDictionary dictionary];
    NSMutableDictionary *basicInfoIDToImageWidthMap = [NSMutableDictionary dictionary];
    NSMutableDictionary *basicInfoIDToModifyDate = [NSMutableDictionary dictionary];
    DBItemBasicInfo *basicInfo = nil;
    NSData *imageData;
    
    command = [NSString stringWithFormat:@"SELECT * FROM %@;", kTableBarcode];
    if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
        char *strTextResult = NULL;
        NSString *columnName = nil;
        Barcode *barcode = [Barcode new];
        
        while(sqlite3_step(statement) == SQLITE_ROW) {
            @autoreleasepool {
                basicInfo = [CoreDataDatabase obtainItemBasicInfoInContext:moc];
                barcode.ID = 0;
                barcode.barcodeData = nil;
                barcode.barcodeType = nil;
                imagePath = nil;
                image = nil;
                imageWidth = 0.0f;
                imageHeight = 0.0f;
                
                for(int column = sqlite3_column_count(statement) - 1; column >= 0; column--) {
                    if(sqlite3_column_bytes(statement, column) == 0) {
//                        NSLog(@"Skip empty column: %s", sqlite3_column_name(statement, column));
                        continue;
                    }
                    
                    columnName = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, column)];
                    if([columnName isEqualToString: kBarcodeColumnID]) {
                        barcode.ID = sqlite3_column_int(statement, column);
                    } else if([columnName isEqualToString: kBarcodeColumnItemName]) {
                        strTextResult = (char *)sqlite3_column_text(statement, column);
                        if(strTextResult) {
                            basicInfo.name = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
                        }
                    } else if([columnName isEqualToString: kBarcodeColumnBarcodeType]) {
                        strTextResult = (char *)sqlite3_column_text(statement, column);
                        if(strTextResult) {
                            basicInfo.barcodeType = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
                            barcode.barcodeType = basicInfo.barcodeType;
                        }
                    } else if([columnName isEqualToString: kBarcodeColumnBarcodeData]) {
                        strTextResult = (char *)sqlite3_column_text(statement, column);
                        if(strTextResult) {
                            basicInfo.barcodeData = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
                            barcode.barcodeData = basicInfo.barcodeData;
                        }
                    } else if([columnName isEqualToString: kBarcodeColumnItemImagePath]) {
                        strTextResult = (char *)sqlite3_column_text(statement, column);
                        if(strTextResult) {
                            imagePath = [NSString stringWithCString:strTextResult encoding:NSUTF8StringEncoding];
                            NSString *fullImagePath = [StringUtil fullPathOfItemImage:imagePath];
                            if([fm fileExistsAtPath:fullImagePath]) {
                                if((imageData = [[NSData alloc] initWithContentsOfFile:[StringUtil fullPathOfItemImage:imagePath]])) {
                                    basicInfo.imageRawData = imageData;
                                    [imagePathToBasicInfoMap setValue:basicInfo forKey:imagePath];
                                    
                                    getImageSizeBlock(imagePath, &imageWidth, &imageHeight);
                                    [basicInfoIDToImageWidthMap setObject:[NSNumber numberWithFloat:imageWidth] forKey:basicInfo.objectID];
                                    
                                    imageFileAttr = [fm attributesOfItemAtPath:fullImagePath error:&error];
                                    [basicInfoIDToModifyDate setObject:[imageFileAttr fileCreationDate] forKey:basicInfo.objectID];
                                }
                            }
                        }
                    }
                } //End of barcode query
                
                if(![basicInfo canSave]) {
                    [CoreDataDatabase removeItemBasicInfo:basicInfo inContext:moc];
                    NSLog(@"[ERROR] BasicInfo from Barcode is unable to save");
                }
//                [CoreDataDatabase commitChanges:&error inContext:moc];
            } //End of @autoreleasepool
        }
    }

    //4. Convert FolderItem -> DBItemBasicInfo, DBFolderItem
    DBNotifyDate *notifyDate;
    NSDate *date;
    command = [NSString stringWithFormat:@"SELECT * FROM %@ ORDER BY %@;", kTableItem, kItemColumnCreateTime];
    if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
        FolderItem *oldItem;
        DBFolderItem *newItem;
        Folder *folder;
        BOOL needNewBasicInfo;
        while(sqlite3_step(statement) == SQLITE_ROW) {
            @autoreleasepool {
                oldItem = [[Database sharedSingleton] getItemFromQueryResult:statement skipColumn:nil];
                if(oldItem.folderID == 0) {
                    continue;
                }
                newItem = [CoreDataDatabase obtainFolderItemInContext:moc];
                [newItem changeItemCreateLogToDate:oldItem.createTime];
                
                //Get existed basicInfo or create a new one
                needNewBasicInfo = YES;
                if(oldItem.barcode) {
                    //BasicInfo has been updated before, so just get it
                    newItem.basicInfo = [CoreDataDatabase getItemBasicInfoByBarcode:oldItem.barcode inContext:moc];
                    needNewBasicInfo = NO;
                } else if([oldItem.name length] > 0) {
                    //Find existed folderItem with the same name
                    newItem.basicInfo = [CoreDataDatabase getItemBasicInfoByName:oldItem.name shouldExcludeBarcode:YES inContext:moc];
                    if(newItem.basicInfo) {
                        needNewBasicInfo = NO;
                    }
                }
                
                if(needNewBasicInfo) {
                    newItem.basicInfo = [CoreDataDatabase obtainItemBasicInfoInContext:moc];
                    newItem.basicInfo.name = oldItem.name;
                }
                
                if([oldItem.imagePath length] > 0 &&
                   [imagePathToBasicInfoMap valueForKey:oldItem.imagePath] != newItem.basicInfo)
                {
                    //Compare image size first without loading whole image
                    getImageSizeBlock(oldItem.imagePath, &imageWidth, &imageHeight);
                    
                    //May be nil if the newItem.basicInfo is really new
                    NSNumber *oldImageWidth = [basicInfoIDToImageWidthMap objectForKey:newItem.basicInfo.objectID];
                    if([oldImageWidth floatValue] < imageWidth) {
                        if((imageData = [[NSData alloc] initWithContentsOfFile:[StringUtil fullPathOfItemImage:oldItem.imagePath]])) {
                            newItem.basicInfo.imageRawData = imageData;
 
                            [imagePathToBasicInfoMap setValue:newItem.basicInfo forKey:oldItem.imagePath];
                            [basicInfoIDToImageWidthMap setObject:[NSNumber numberWithFloat:imageWidth] forKey:newItem.basicInfo.objectID];
                            
                            imageFileAttr = [fm attributesOfItemAtPath:[StringUtil fullPathOfItemImage:oldItem.imagePath] error:&error];
                            [basicInfoIDToModifyDate setObject:[imageFileAttr fileCreationDate] forKey:newItem.basicInfo.objectID];
                        }
                    } else {
                        //Compare create date
                        NSDate *oldCreationDate = [basicInfoIDToModifyDate objectForKey:newItem.basicInfo.objectID];
                        itemImageFileAttr = [fm attributesOfItemAtPath:[StringUtil fullPathOfItemImage:oldItem.imagePath] error:&error];
                        if([[itemImageFileAttr fileCreationDate] compare:oldCreationDate] == NSOrderedDescending) {
                            if((imageData = [[NSData alloc] initWithContentsOfFile:[StringUtil fullPathOfItemImage:oldItem.imagePath]])) {
                                newItem.basicInfo.imageRawData = imageData;
                                
                                [imagePathToBasicInfoMap setValue:newItem.basicInfo forKey:oldItem.imagePath];
                                [basicInfoIDToImageWidthMap setObject:[NSNumber numberWithFloat:imageWidth] forKey:newItem.basicInfo.objectID];
                                [basicInfoIDToModifyDate setObject:[itemImageFileAttr fileCreationDate] forKey:newItem.basicInfo.objectID];
                            }
                        }
                    }
                }
                
                if(![newItem.basicInfo canSave]) {
                    if(needNewBasicInfo) {
                        [CoreDataDatabase removeItemBasicInfo:newItem.basicInfo inContext:moc];
                    }
                    [CoreDataDatabase removeItem:newItem inContext:moc];
//                    [CoreDataDatabase commitChanges:&error inContext:moc];
                    continue;
                }
                
                //Assign rest part
                folder = [[Database sharedSingleton] getFolderByID:oldItem.folderID];
                if(folder) {
                    newItem.folder = [CoreDataDatabase getFolderInPage:folder.page withNumber:folder.number inContext:moc];
                }

                if(oldItem.location) {
                    newItem.location = [oldIdToNewLocationMap objectForKey:[NSNumber numberWithInt:oldItem.location.ID]];
                }
                
                newItem.isArchived = oldItem.isArchived;
                newItem.count = oldItem.count;
                newItem.note = oldItem.note;
                newItem.price = oldItem.price;
                newItem.createTime = [oldItem.createTime timeIntervalSinceReferenceDate];
                newItem.lastUpdateTime = newItem.createTime;
                if([oldItem.expireTime timeIntervalSince1970] > 0) {
                    notifyDate = [CoreDataDatabase getNotifyDateOfDate:oldItem.expireTime inContext:moc];
                    if(notifyDate == nil) {
                        notifyDate = [CoreDataDatabase obtainNotifyDateInContext:moc];
                        notifyDate.date = [oldItem.expireTime timeIntervalSinceReferenceDate];
                    }
                    newItem.expiryDate = notifyDate;
                    if([oldItem.nearExpiredDays count] > 0) {
                        @autoreleasepool {
                            NSMutableSet *dates = [NSMutableSet set];
                            for(NSNumber *day in oldItem.nearExpiredDays) {
                                date = [TimeUtil dateFromDate:oldItem.expireTime inDays: -[day intValue]];
                                notifyDate = [CoreDataDatabase getNotifyDateOfDate:date inContext:moc];
                                if(notifyDate == nil) {
                                    notifyDate = [CoreDataDatabase obtainNotifyDateInContext:moc];
                                    notifyDate.date = [date timeIntervalSinceReferenceDate];
                                }
                                
                                [dates addObject:notifyDate];
                            }
                            
                            newItem.nearExpiryDates = ([dates count] > 0) ? dates : nil;
                        }
                    }
                }
                
//                [CoreDataDatabase commitChanges:&error inContext:moc];
            } //End of @autoreleasepool
        }
    }
    
    //5. Convert ShoppingItem -> DBItemBasicInfo, DBShoppingItem
    command = [NSString stringWithFormat:@"SELECT * FROM %@ ORDER BY %@;", kTableShoppingList, kShoppingListColumnListPosition];
    if(sqlite3_prepare_v2(db, [command UTF8String], -1, &statement, nil) == SQLITE_OK) {
        int nPosition = 0;
        ShoppingItem *oldShoppingItem;
        DBShoppingItem *newShoppingItem;
        while(sqlite3_step(statement) == SQLITE_ROW) {
            newShoppingItem = [CoreDataDatabase obtainShoppingItemInContext:moc];
            oldShoppingItem = [[Database sharedSingleton] getShoppingItemFromQueryResult:statement skipColumn:nil];
            
            basicInfo = nil;
            
            //1. Try to find the existed basicInfo with the same name
            if([oldShoppingItem.itemName length] > 0) {
                basicInfo = [CoreDataDatabase getItemBasicInfoByName:oldShoppingItem.itemName shouldExcludeBarcode:NO inContext:moc];
            }
            
            //If shopping item has an image, try to look for an existed basicInfo, otherwise create a new one
            image = nil;
            
            //Try to find an existed basicInfo which has the same imagePath
            if(basicInfo == nil) {
                basicInfo = [imagePathToBasicInfoMap objectForKey:oldShoppingItem.itemImagePath];
            }
            
            //No basicInfo has the same name and imagePath, it's time to create a new one
            if(basicInfo == nil) {
                basicInfo = [CoreDataDatabase obtainItemBasicInfoInContext:moc];
            }
            
            if([oldShoppingItem.itemImagePath length] > 0 &&
               [fm fileExistsAtPath:[StringUtil fullPathOfItemImage:oldShoppingItem.itemImagePath]] &&
               [imagePathToBasicInfoMap objectForKey:oldShoppingItem.itemImagePath] != basicInfo)
            {
                getImageSizeBlock(oldShoppingItem.itemImagePath, &imageWidth, &imageHeight);
                NSNumber *oldImageWidth = [basicInfoIDToImageWidthMap objectForKey:basicInfo.objectID];
                if([oldImageWidth floatValue] < imageWidth) {
                    if((imageData = [[NSData alloc] initWithContentsOfFile:[StringUtil fullPathOfItemImage:oldShoppingItem.itemImagePath]])) {
                        basicInfo.imageRawData = imageData;
                        
                        [imagePathToBasicInfoMap setValue:basicInfo forKey:oldShoppingItem.itemImagePath];
                        [basicInfoIDToImageWidthMap setObject:[NSNumber numberWithFloat:imageWidth] forKey:basicInfo.objectID];
                        
                        imageFileAttr = [fm attributesOfItemAtPath:[StringUtil fullPathOfItemImage:oldShoppingItem.itemImagePath] error:&error];
                        [basicInfoIDToModifyDate setObject:[imageFileAttr fileCreationDate] forKey:basicInfo.objectID];
                    }
                } else {
                    //Compare create date
                    NSDate *oldCreationDate = [basicInfoIDToModifyDate objectForKey:basicInfo.objectID];
                    itemImageFileAttr = [fm attributesOfItemAtPath:[StringUtil fullPathOfItemImage:oldShoppingItem.itemImagePath] error:&error];
                    if([[itemImageFileAttr fileCreationDate] compare:oldCreationDate] == NSOrderedDescending) {
                        if((imageData = [[NSData alloc] initWithContentsOfFile:[StringUtil fullPathOfItemImage:oldShoppingItem.itemImagePath]])) {
                            basicInfo.imageRawData = imageData;
                            
                            [imagePathToBasicInfoMap setValue:basicInfo forKey:oldShoppingItem.itemImagePath];
                            [basicInfoIDToImageWidthMap setObject:[NSNumber numberWithFloat:imageWidth] forKey:basicInfo.objectID];
                            [basicInfoIDToModifyDate setObject:[itemImageFileAttr fileCreationDate] forKey:basicInfo.objectID];
                        }
                    }
                }
            }
            
            basicInfo.name = oldShoppingItem.itemName;
            newShoppingItem.basicInfo = basicInfo;
            
            //Assign rest part
            newShoppingItem.count = oldShoppingItem.shoppingCount;
            newShoppingItem.price = oldShoppingItem.price;
            newShoppingItem.hasBought = oldShoppingItem.hasBought;
            newShoppingItem.listPosition = nPosition;
            nPosition++;
            
//            [CoreDataDatabase commitChanges:&error inContext:moc];
        }
    }

    BOOL success = [CoreDataDatabase commitChanges:&error inContext:moc];
    if(success) {
        NSString *oldPath = [StringUtil fullPathInDocument:kDBName];
        NSString *newPath = [StringUtil fullPathInTemp:kDBName];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:newPath]) {
            if(![[NSFileManager defaultManager] removeItemAtPath:newPath error:&error]) {
                 NSLog(@"Cannot remove %@, error: %@", [[newPath componentsSeparatedByString:@"/"] lastObject], error);
            }
        }
        
        if([[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&error]) {
            [[NSFileManager defaultManager] removeItemAtPath:oldPath error:&error];
        } else {
            NSLog(@"[ERROR] %@", [error localizedDescription]);
        }
        
        oldPath = [StringUtil fullPathInDocument:kItemImagePrefix];
        newPath = [StringUtil fullPathInTemp:kItemImagePrefix];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:newPath]) {
            if(![[NSFileManager defaultManager] removeItemAtPath:newPath error:&error]) {
                NSLog(@"Cannot remove %@, error: %@", [[newPath componentsSeparatedByString:@"/"] lastObject], error);
            }
        }
        
        if([[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&error]) {
            [[NSFileManager defaultManager] removeItemAtPath:oldPath error:&error];
        } else {
            NSLog(@"[ERROR] %@", [error localizedDescription]);
        }
        
        oldPath = [StringUtil fullPathInDocument:kFolderImagePrefix];
        newPath = [StringUtil fullPathInTemp:kFolderImagePrefix];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:newPath]) {
            if(![[NSFileManager defaultManager] removeItemAtPath:newPath error:&error]) {
                NSLog(@"Cannot remove %@, error: %@", [[newPath componentsSeparatedByString:@"/"] lastObject], error);
            }
        }
        
        if([[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&error]) {
            [[NSFileManager defaultManager] removeItemAtPath:oldPath error:&error];
        } else {
            NSLog(@"[ERROR] %@", [error localizedDescription]);
        }
    } else {
        [CoreDataDatabase cancelUnsavedChangesInContext:moc];
        sqlite3_close(db);
    }
    
    return NO;
}

@end
