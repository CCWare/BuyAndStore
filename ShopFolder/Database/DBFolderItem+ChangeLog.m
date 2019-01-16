//
//  DBFolderItem+ChangeLog.m
//  ShopFolder
//
//  Created by Michael on 2012/10/11.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBFolderItem+ChangeLog.h"
#import "TimeUtil.h"
#import "CoreDataDatabase.h"

enum ChangeID_E {
    kItemCreated,
    kCountChanged,          //param:oldCount, newCount
    kCreateDateChanged,
    kExpiryDateChanged,
    kNearExpiryDaysChanged,
    kPriceChanged,
    kLocationChanged,
    kNoteChanged,
    kArchiveStatusChanged,
    kExpiryDateRemoved,
    kAlertDaysRemoved,
    kPriceRemoved,
    kLocationRemoved,
    kNoteRemoved
};

@implementation DBFolderItem (ChangeLog)
- (ChangeLog *)_parseChangeLog:(NSString *)log
{
    NSString *localizedLog;
    int changeDate;
    int changeID;
    NSScanner *scanner= [NSScanner scannerWithString:log];
    
    if([scanner scanInt:&changeDate] &&
       [scanner scanInt:&changeID])
    {
        localizedLog = nil;
        
        switch (changeID) {
            case kItemCreated:
                localizedLog = NSLocalizedString(@"Created", @"FolderItem created log");
                break;
                
            case kCountChanged:
            {
                int oldCount = 0;
                int newCount = 0;
                if([scanner scanInt:&oldCount] &&
                   [scanner scanInt:&newCount])
                {
                    localizedLog  = [NSString stringWithFormat:NSLocalizedString(@"Change count from %d to %d", @"FolderItem change log"),
                                     oldCount, newCount];
                } else {
                    NSLog(@"[ERROR] Cannot get count from change log");
                }
                
            }
                break;
                
            case kCreateDateChanged:
            {
                int date = 0;
                if([scanner scanInt:&date]) {
                    localizedLog = [NSString stringWithFormat:NSLocalizedString(@"Change created date to %@", @"FolderItem change log"),
                                    [TimeUtil dateToStringInCurrentLocale:[NSDate dateWithTimeIntervalSinceReferenceDate:date]]];
                } else {
                    NSLog(@"[ERROR] Cannot get creation date from change log");
                }
            }
                break;
                
            case kExpiryDateChanged:
            {
                int date = 0;
                if([scanner scanInt:&date]) {
                    localizedLog = [NSString stringWithFormat:NSLocalizedString(@"Change expiry date to %@", @"FolderItem change log"),
                                    [TimeUtil dateToStringInCurrentLocale:[NSDate dateWithTimeIntervalSinceReferenceDate:date]]];
                } else {
                    NSLog(@"[ERROR] Cannot get expiry date from change log");
                }
            }
                break;
                
            case kNearExpiryDaysChanged:
                localizedLog = NSLocalizedString(@"Change expiry alert days", @"FolderItem change log");
                break;
                
            case kPriceChanged:
            {
                float price = 0.0f;
                if([scanner scanFloat:&price]) {
                    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
                    formatter.minimumFractionDigits = 0;
                    NSString *priceString = [formatter stringFromNumber:[NSNumber numberWithDouble:price]];
                    
                    localizedLog = [NSString stringWithFormat:NSLocalizedString(@"Change price to %@", @"FolderItem change log"),
                                    priceString];
                } else {
                    NSLog(@"[ERROR] Cannot get price from change log");
                }
            }
                break;
                
            case kLocationChanged:
            {
                NSString *locationName;
                if([scanner scanUpToString:@"\n" intoString:&locationName]) {
                    localizedLog = [NSString stringWithFormat:NSLocalizedString(@"Change location to %@", @"FolderItem change log"), locationName];
                }
            }
                break;
                
            case kNoteChanged:
                localizedLog = NSLocalizedString(@"Edit note", @"FolderItem change log");
                break;
                
            case kArchiveStatusChanged:
            {
                int archiveStatus = 0;
                if([scanner scanInt:&archiveStatus]) {
                    if(archiveStatus == 0) {
                        localizedLog = NSLocalizedString(@"Unarchive", @"FolderItem change log");
                    } else {
                        localizedLog = NSLocalizedString(@"Archived", @"FolderItem change log");
                    }
                } else {
                    NSLog(@"[ERROR] Cannot get archive status from change log");
                }
            }
                break;
            case kExpiryDateRemoved:
                localizedLog = NSLocalizedString(@"Remove expiry date", @"FolderItem change log");
                break;
            case kAlertDaysRemoved:
                localizedLog = NSLocalizedString(@"Disable expiry alert", @"FolderItem change log");
                break;
            case kPriceRemoved:
                localizedLog = NSLocalizedString(@"Remove price", @"FolderItem change log");
                break;
            case kLocationRemoved:
                localizedLog = NSLocalizedString(@"Remove location", @"FolderItem change log");
                break;
            case kNoteRemoved:
                localizedLog = NSLocalizedString(@"Remove note", @"FolderItem change log");
                break;
            default:
                break;
        }
    }
    
    if([localizedLog length] == 0) {
        return nil;
    }
    
    return [[ChangeLog alloc] initWithTime:[NSDate dateWithTimeIntervalSinceReferenceDate:changeDate] log:localizedLog];
}

- (NSArray *)localizedChangeLogs
{
    NSMutableArray *changeLogs = [NSMutableArray array];
    
    NSArray *logs = [self.changeLog componentsSeparatedByString:@"\n"];
    ChangeLog *changeLog;
    for(NSString *log in logs) {
        changeLog = [self _parseChangeLog:log];
        if(changeLog) {
            [changeLogs addObject:changeLog];
        }
    }
    
    return changeLogs;
}

- (void)_addTimePrefixToLog
{
    NSMutableString *newLog = (self.changeLog) ? [NSMutableString stringWithString:self.changeLog] : [NSMutableString string];
    if([newLog length] > 0) {
        [newLog appendString:@"\n"];
    }
    
    [newLog appendFormat:@"%d ", (int)[[NSDate date] timeIntervalSinceReferenceDate]];
    self.changeLog = newLog;
}

- (void)addItemCreateLog
{
    NSMutableString *newLog = [NSMutableString stringWithFormat:@"%d %d",
                               (int)[[TimeUtil today] timeIntervalSinceReferenceDate], kItemCreated];
    
    if([self.changeLog length] > 0) {
        NSArray *logs = [self.changeLog componentsSeparatedByString:@"\n"];
        for(NSString *log in logs) {
            if(log == [logs objectAtIndex:0]) {
                continue;
            } else {
                [newLog appendString:log];
                if(log != [logs lastObject]) {
                    [newLog appendString:@"\n"];
                }
            }
        }
    }
    
    self.changeLog = newLog;
}

- (void)changeItemCreateLogToDate:(NSDate *)newCreateDate
{
    NSMutableString *newLog = [NSMutableString stringWithFormat:@"%d %d", (int)[newCreateDate timeIntervalSinceReferenceDate], kItemCreated];
    if([self.changeLog length] > 0) {
        NSArray *logs = [self.changeLog componentsSeparatedByString:@"\n"];
        for(NSString *log in logs) {
            if(log == [logs objectAtIndex:0]) {
                continue;
            } else {
                [newLog appendString:log];
                if(log != [logs lastObject]) {
                    [newLog appendString:@"\n"];
                }
            }
        }
    }
    
    self.changeLog = newLog;
}

- (void)addCountChangeLogFromOldCount:(int)oldCount
{
    [self _addTimePrefixToLog];
    
    NSMutableString *newLog = [NSMutableString stringWithString:self.changeLog];
    [newLog appendFormat:@"%d %d %d", kCountChanged, oldCount, self.count];
    self.changeLog = newLog;
}

- (void)addCreateDateChangeLog
{
    [self _addTimePrefixToLog];
    
    NSMutableString *newLog = [NSMutableString stringWithString:self.changeLog];
    [newLog appendFormat:@"%d %d", kCreateDateChanged, (int)self.createTime];
    self.changeLog = newLog;
}

- (void)addExpiryDateChangeLog
{
    [self _addTimePrefixToLog];
    
    NSMutableString *newLog = [NSMutableString stringWithString:self.changeLog];
    int newDate = (int)self.expiryDate.date;
    if(newDate > 0) {
        [newLog appendFormat:@"%d %d", kExpiryDateChanged, newDate];
    } else {
        [newLog appendFormat:@"%d", kExpiryDateRemoved];
    }
    self.changeLog = newLog;
}

- (void)addNearExpiryDaysChangeLog
{
    [self _addTimePrefixToLog];
    NSMutableString *newLog = [NSMutableString stringWithString:self.changeLog];
    if([self.nearExpiryDates count] > 0) {
        [newLog appendFormat:@"%d", kNearExpiryDaysChanged];
    } else {
        [newLog appendFormat:@"%d", kAlertDaysRemoved];
    }
    self.changeLog = newLog;
}

- (void)addPriceChangeLog
{
    [self _addTimePrefixToLog];
    NSMutableString *newLog = [NSMutableString stringWithString:self.changeLog];
    if(self.price != 0.0f) {
        [newLog appendFormat:@"%d %f", kPriceChanged, self.price];
    } else {
        [newLog appendFormat:@"%d", kPriceRemoved];
    }
    self.changeLog = newLog;
}

- (void)addLocationChangeLog
{
    [self _addTimePrefixToLog];
    NSMutableString *newLog = [NSMutableString stringWithString:self.changeLog];
    if(self.location != nil) {
        [newLog appendFormat:@"%d %@", kLocationChanged, self.location.name];
    } else {
        [newLog appendFormat:@"%d", kLocationRemoved];
    }
    self.changeLog = newLog;
}

- (void)addNoteChangeLog
{
    [self _addTimePrefixToLog];
    NSMutableString *newLog = [NSMutableString stringWithString:self.changeLog];
    if([self.note length] > 0) {
        [newLog appendFormat:@"%d", kNoteChanged];
    } else {
        [newLog appendFormat:@"%d", kNoteRemoved];
    }
    self.changeLog = newLog;
}

- (void)addArchiveStatusChangeLog
{
    [self _addTimePrefixToLog];
    NSMutableString *newLog = [NSMutableString stringWithString:self.changeLog];
    [newLog appendFormat:@"%d %d", kArchiveStatusChanged, self.isArchived];
    self.changeLog = newLog;
}

@end
