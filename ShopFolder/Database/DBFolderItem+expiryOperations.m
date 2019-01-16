//
//  DBFolderItem+expiryOperations.m
//  ShopFolder
//
//  Created by Michael on 2012/09/19.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBFolderItem+expiryOperations.h"
#import "TimeUtil.h"
#import "DBNotifyDate.h"

@implementation DBFolderItem (expiryOperations)
- (BOOL)isExpiredIgnoreArchive:(BOOL)ignoreArchive ignoreCount:(BOOL)ignoreCount
{
    if(!ignoreArchive &&
       self.isArchived)
    {
        return NO;
    }
    
    if(!ignoreCount &&
       self.count == 0)
    {
        return NO;
    }
    
    return [TimeUtil isExpired:[NSDate dateWithTimeIntervalSinceReferenceDate:self.expiryDate.date]];
}

- (BOOL)isExpired
{
    return [self isExpiredIgnoreArchive:NO ignoreCount:NO];
//    return (self.count > 0 &&
//            !self.isArchived &&
//            [TimeUtil isExpired:[NSDate dateWithTimeIntervalSinceReferenceDate:self.expireTime]]);
}

- (BOOL)isNearExpiredIgnoreArchive:(BOOL)ignoreArchive ignoreCount:(BOOL)ignoreCount
{
    if(!ignoreArchive &&
       self.isArchived)
    {
        return NO;
    }
    
    if(!ignoreCount &&
       self.count == 0)
    {
        return NO;
    }
    
    if([self.nearExpiryDates count] == 0) {
        return NO;
    }
    
    NSMutableArray *notifyDates = [NSMutableArray arrayWithArray:[self.nearExpiryDates allObjects]];
    NSTimeInterval minTime = ((DBNotifyDate *)[notifyDates objectAtIndex:0]).date;
    for(DBNotifyDate *date in notifyDates) {
        if(date.date < minTime) {
            minTime = date.date;
        }
    }
    
    return (![self isExpired] &&
            minTime <= [[TimeUtil today] timeIntervalSinceReferenceDate]);
}

- (BOOL) isNearExpired
{
    return [self isNearExpiredIgnoreArchive:NO ignoreCount:NO];
//    if(self.count == 0 ||
//       self.isArchived ||
//       [self.nearExpiredDays length] == 0)
//    {
//        return NO;
//    }
//    
//    NSString *lastExpireDay = (NSString *)[[self.nearExpiredDays componentsSeparatedByString:kDaySeperator] lastObject];
//    return (![self isExpired] && [TimeUtil isNearExpired:[NSDate dateWithTimeIntervalSinceReferenceDate:self.expireTime]
//                                         nearExpiredDays:[lastExpireDay intValue]]);
}
@end
