//
//  DBFolderItem+ChangeLog.h
//  ShopFolder
//
//  Created by Michael on 2012/10/11.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBFolderItem.h"
#import "ChangeLog.h"

@interface DBFolderItem (ChangeLog)
- (NSArray *)localizedChangeLogs;   //array of ChangeLog

- (void)addItemCreateLog;
- (void)changeItemCreateLogToDate:(NSDate *)newCreateDate;
- (void)addCountChangeLogFromOldCount:(int)count;
- (void)addCreateDateChangeLog;
- (void)addExpiryDateChangeLog;
- (void)addNearExpiryDaysChangeLog;
- (void)addPriceChangeLog;
- (void)addLocationChangeLog;
- (void)addNoteChangeLog;
- (void)addArchiveStatusChangeLog;

@end
