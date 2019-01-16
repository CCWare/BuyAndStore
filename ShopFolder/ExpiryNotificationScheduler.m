//
//  ExpiryNotificationScheduler.m
//  ShopFolder
//
//  Created by Michael Tsai on 2012/02/06.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "ExpiryNotificationScheduler.h"
#import "NotificationConstant.h"
#import "PreferenceConstant.h"
#import "CoreDataDatabase.h"
#import "TimeUtil.h"
#import "VersionCompare.h"
#import "FlurryAnalytics.h"
#import "UIApplication+BadgeUpdate.h"

#define kScheduleDelay  0.001

#define kMaxSchedulePeriod  31536000 //365(day) * 24(hour) * 60(min) * 60(sec)
#define kAlertBody  (NSLocalizedString(@"Check expiry list.", @"Unified AlertBody"))

#define DEBUG_NOTIFICATION  0

static dispatch_queue_t g_scheduleNotificationsQueue;

@interface ExpiryNotificationScheduler ()
+ (void)_receiveMangedContextDidSaveNotification:(NSNotification *)notification;
+ (void)_receiveExpirePreferenceChangeNotification:(NSNotification *)notification;

+ (void)_doSyncNotificationsWithDatabase;

//Utilities
#ifdef DEBUG
+ (NSString *)_dateToFormattedString:(NSDate *)date;
+ (NSString *)_timeIntervalToFormattedString:(NSTimeInterval)time;
#endif
@end

@implementation ExpiryNotificationScheduler
+ (void)initialize
{
    if(self == [ExpiryNotificationScheduler class]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            g_scheduleNotificationsQueue = dispatch_queue_create("ExpiryNotificationScheduleQueue", NULL);
            
            //Add notofication listener
            [self enableReceivingNotifications];
        });
    }
}

+ (void)enableReceivingNotifications
{
    dispatch_async(dispatch_get_main_queue(), ^{
        //Add notofication listener
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_receiveMangedContextDidSaveNotification:)
                                                     name:NSManagedObjectContextDidSaveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_receiveExpirePreferenceChangeNotification:)
                                                     name:kExpirePreferenceChangeNotification
                                                   object:nil];
    });
}

+ (void)disableReceivingNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kExpirePreferenceChangeNotification object:nil];
}

+ (void)rescheduleAllNotifications
{
    static BOOL isSchedulingCancelled;
    isSchedulingCancelled = YES;    //cancel last running schedule block
    dispatch_async(g_scheduleNotificationsQueue, ^(void) {
        [[UIApplication sharedApplication] refreshApplicationBadgeNumber];
        
#ifdef DEBUG
#if DEBUG_NOTIFICATION
        NSLog(@"===== Reschedule all notifications =====");
#endif
#endif
        isSchedulingCancelled = NO;
        const BOOL NOTIFY_EXPIRED = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingNotifyExpired];
        const BOOL NOTIFY_NEAR_EXPIRED = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingNotifyNearExpired];
        const int ALERT_HOUR = [[NSUserDefaults standardUserDefaults] integerForKey:kSettingDailyNotifyHour];
        const int ALERT_MINUTE = [[NSUserDefaults standardUserDefaults] integerForKey:kSettingDailyNotifyMinute];
        
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kHasScheduledNotifications];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        
        NSManagedObjectContext *moc = [CoreDataDatabase getContextForCurrentThread];
        [CoreDataDatabase removeEmptyDatesInContext:moc];
        NSMutableArray *notifyDates = [CoreDataDatabase getNotifyDatesWithinDaysFromToday:365 inContext:moc];
        UILocalNotification *notif;
        NSDate *fireDate;
        for(DBNotifyDate *notifyDate in notifyDates) {
            @autoreleasepool {
                fireDate = [NSDate dateWithTimeIntervalSinceReferenceDate:notifyDate.date];
                
                if(isSchedulingCancelled) {
                    return;
                }
                
                //Schedule badge change notification
                if([notifyDate.expireItems count] > 0) {
                    notif = [UILocalNotification new];
                    notif.timeZone = [NSTimeZone defaultTimeZone];
                    notif.fireDate = fireDate;
                    notif.applicationIconBadgeNumber = [CoreDataDatabase totalExpiredItemsBeforeAndIncludeDate:fireDate inContext:moc];
#ifdef DEBUG
#if DEBUG_NOTIFICATION
                    NSLog(@"Set badge to %d @%@", notif.applicationIconBadgeNumber, [self _dateToFormattedString:fireDate]);
#endif
#endif
                    [[UIApplication sharedApplication] scheduleLocalNotification:notif];
                }
                
                if(isSchedulingCancelled) {
                    return;
                }
                
                //Schedule alert notification
                if((NOTIFY_EXPIRED && [notifyDate.expireItems count] > 0) ||
                   (NOTIFY_NEAR_EXPIRED && [notifyDate.nearExpireItems count] > 0))
                {
                    notif = [UILocalNotification new];
                    notif.timeZone = [NSTimeZone defaultTimeZone];
                    notif.fireDate = [TimeUtil timeInDate:fireDate hour:ALERT_HOUR minute:ALERT_MINUTE second:0];
                    notif.alertBody = kAlertBody;
#ifdef DEBUG
#if DEBUG_NOTIFICATION
                    NSLog(@"Alert @%@", [self _dateToFormattedString:notif.fireDate]);
#endif
#endif
                    [[UIApplication sharedApplication] scheduleLocalNotification:notif];
                }
            }
        }
        
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kHasScheduledNotifications];
        [[NSUserDefaults standardUserDefaults] setValue:kCurrentNotificationVersion forKey:kNotificationVersion];
        [[NSUserDefaults standardUserDefaults] synchronize];

#ifdef DEBUG
#if DEBUG_NOTIFICATION
        NSLog(@"===== Finish scheduling all notifications =====");
#endif
#endif
    });
}

+ (void)_doSyncNotificationsWithDatabase
{
    [[UIApplication sharedApplication] refreshApplicationBadgeNumber];
    
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kHasScheduledNotifications];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    //Init existed notification maps, this will only get notifications from now on
    NSMutableArray *notifications = [NSMutableArray arrayWithArray:
                                     [[UIApplication sharedApplication] scheduledLocalNotifications]];
    NSMutableDictionary *badgeChangeDateToNotifMap = [NSMutableDictionary dictionary];    //NSDate(midnight) -> Notification
    NSMutableDictionary *alertDateToNotifMap = [NSMutableDictionary dictionary];          //NSDate(midnight) -> Notification
    
#ifdef DEBUG
#if DEBUG_NOTIFICATION
    NSLog(@"===== Start to get system notifications =====");
#endif
#endif
    UILocalNotification *notif;
    for(notif in notifications) {
        if(notif.applicationIconBadgeNumber > 0 ||
           [notif.alertBody length] == 0)
        {
            //Collect badge change notifications
#ifdef DEBUG
#if DEBUG_NOTIFICATION
            NSLog(@"Badge number: %d @%@", notif.applicationIconBadgeNumber, [self _dateToFormattedString:notif.fireDate]);
#endif
#endif
            [badgeChangeDateToNotifMap setObject:notif
                                            forKey:notif.fireDate];
        } else {
            //Collect alert notifications, item IDs are stored in userInfo
#ifdef DEBUG
#if DEBUG_NOTIFICATION
            NSLog(@"Alert @%@:\n%@", [self _dateToFormattedString:notif.fireDate], notif.alertBody);
#endif
#endif
            [alertDateToNotifMap setObject:notif
                                      forKey:[TimeUtil timeInDate:notif.fireDate hour:0 minute:0 second:0]];
        }
    }
    
    const BOOL NOTIFY_EXPIRED = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingNotifyExpired];
    const BOOL NOTIFY_NEAR_EXPIRED = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingNotifyNearExpired];
    const int ALERT_HOUR = [[NSUserDefaults standardUserDefaults] integerForKey:kSettingDailyNotifyHour];
    const int ALERT_MINUTE = [[NSUserDefaults standardUserDefaults] integerForKey:kSettingDailyNotifyMinute];
    
    NSManagedObjectContext *moc = [CoreDataDatabase getContextForCurrentThread];
    int nExpireCount;
    NSDate *date;
    NSMutableArray *notifyDates = [CoreDataDatabase getNotifyDatesWithinDaysFromToday:365 inContext:moc];
    for(DBNotifyDate *notifyDate in notifyDates) {
        @autoreleasepool {
            date = [NSDate dateWithTimeIntervalSinceReferenceDate:notifyDate.date];
            
            //Add or correct badge change notifications
            notif = [badgeChangeDateToNotifMap objectForKey:date];
            if(notif) {
                //Notification exists, check for badge consistence
                nExpireCount = [CoreDataDatabase totalExpiredItemsBeforeAndIncludeDate:date
                                                                             inContext:moc];
                if(nExpireCount != notif.applicationIconBadgeNumber) {
                    [[UIApplication sharedApplication] cancelLocalNotification:notif];
#ifdef DEBUG
#if DEBUG_NOTIFICATION
                    NSLog(@"Correct badge to %d @%@", notif.applicationIconBadgeNumber, [self _dateToFormattedString:fireDate]);
#endif
#endif
                    notif.applicationIconBadgeNumber = nExpireCount;
                    [[UIApplication sharedApplication] scheduleLocalNotification:notif];
                }
                
                [badgeChangeDateToNotifMap removeObjectForKey:date];
            } else if([notifyDate.expireItems count] > 0) {
                notif = [UILocalNotification new];
                notif.timeZone = [NSTimeZone defaultTimeZone];
                notif.fireDate = date;
                notif.applicationIconBadgeNumber = [CoreDataDatabase totalExpiredItemsBeforeAndIncludeDate:date
                                                                                                 inContext:moc];
#ifdef DEBUG
#if DEBUG_NOTIFICATION
                NSLog(@"Set badge to %d @%@", notif.applicationIconBadgeNumber, [self _dateToFormattedString:fireDate]);
#endif
#endif
                [[UIApplication sharedApplication] scheduleLocalNotification:notif];
            }
            
            if(!NOTIFY_EXPIRED && !NOTIFY_NEAR_EXPIRED) {
                continue;
            }
            
            //Add alert notification
            notif = [alertDateToNotifMap objectForKey:date];
            if(notif) {
                [alertDateToNotifMap removeObjectForKey:date];
            } else {
                notif = [UILocalNotification new];
                notif.timeZone = [NSTimeZone defaultTimeZone];
                notif.fireDate = [TimeUtil timeInDate:date hour:ALERT_HOUR minute:ALERT_MINUTE second:0];
                notif.alertBody = kAlertBody;
#ifdef DEBUG
#if DEBUG_NOTIFICATION
                NSLog(@"Alert @%@", [self _dateToFormattedString:notif.fireDate]);
#endif
#endif
                [[UIApplication sharedApplication] scheduleLocalNotification:notif];
            }
        }
    }
    
    //Remove notifications which are no longer used
    for(notif in [badgeChangeDateToNotifMap allValues]) {
        if(notif) {
            [[UIApplication sharedApplication] cancelLocalNotification:notif];
        }
    }
    
    for(notif in [alertDateToNotifMap allValues]) {
        if(notif) {
            [[UIApplication sharedApplication] cancelLocalNotification:notif];
        }
    }
    
    [CoreDataDatabase removeEmptyDatesInContext:moc];
    
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kHasScheduledNotifications];
    [[NSUserDefaults standardUserDefaults] setValue:kCurrentNotificationVersion forKey:kNotificationVersion];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
//==============================================================
//  [BEGIN] Utilities
#pragma mark - Utilities
//--------------------------------------------------------------
#ifdef DEBUG
+ (NSString *)_dateToFormattedString:(NSDate *)date
{
    return [TimeUtil dateToString:date inFormat:@"yyyy-MM-dd HH:mm"];
}

+ (NSString *)_timeIntervalToFormattedString:(NSTimeInterval)time
{
    return [self _dateToFormattedString:[NSDate dateWithTimeIntervalSince1970:time]];
}
#endif
//--------------------------------------------------------------
//  [END] Utilities
//==============================================================

//==============================================================
//  [BEGIN] Notification receivers
#pragma mark - Notification receivers
//--------------------------------------------------------------
+ (void)_receiveMangedContextDidSaveNotification:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    DBFolderItem *folderItem = nil;
    
    BOOL needUpdateSchedule = NO;
    
    NSSet *insertedObjects = [userInfo objectForKey:NSInsertedObjectsKey];
    for(NSManagedObject *object in insertedObjects) {
        if([object class] == [DBFolderItem class]) {
            folderItem = (DBFolderItem *)object;
            if(folderItem.expiryDate != nil &&
               folderItem.count > 0 &&
               !folderItem.isArchived)
            {
                needUpdateSchedule = YES;
                break;
            }
        }
    }
    
    if(!needUpdateSchedule) {
        NSSet *deletedObjects = [userInfo objectForKey:NSDeletedObjectsKey];
        for(NSManagedObject *object in deletedObjects) {
            if([object class] == [DBFolderItem class]) {
                needUpdateSchedule = YES;
                break;
            }
        }
    }
    
    NSDictionary *changedValues = nil;
    NSArray *changedKeys = nil;
    if(!needUpdateSchedule) {
        NSSet *updatedObjects = [userInfo objectForKey:NSUpdatedObjectsKey];
        for(NSManagedObject *object in updatedObjects) {
            if([object class] == [DBFolderItem class]) {
                changedValues = [object changedValues];
                changedKeys = [changedValues allKeys];
                for(NSString *key in changedKeys) {
                    if([key isEqualToString:kAttrExpiryDate] ||
                       [key isEqualToString:kAttrNearExpiryDates])
                    {
                        needUpdateSchedule = YES;
                        break;
                    }
                }
            }
        }
    }
    
    if(!needUpdateSchedule) {
        return;
    }
    
    dispatch_async(g_scheduleNotificationsQueue, ^(void) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kHasScheduledNotifications];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
#ifndef DEBUG
        @try {
#endif
            
            [self _doSyncNotificationsWithDatabase];
#ifndef DEBUG
        }
        @catch (NSException *exception) {
            if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                [FlurryAnalytics logError:@"ScheduleModifiedItem" message:exception.reason exception:exception];
            }
            NSLog(@"Caught exception when sync notif with DB:\nName: %@\nReason: %@", exception.name, exception.reason);
            [self rescheduleAllNotifications];
            return;
        }
        @finally {
        }
#endif
        
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kHasScheduledNotifications];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
}

+ (void)_receiveExpirePreferenceChangeNotification:(NSNotification *)notification
{
    [self rescheduleAllNotifications];
}
//--------------------------------------------------------------
//  [END] Notification receivers
//==============================================================
@end
