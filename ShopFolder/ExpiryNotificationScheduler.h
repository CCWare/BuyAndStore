//
//  ExpiryNotificationScheduler.h
//  ShopFolder
//
//  Created by Michael Tsai on 2012/02/06.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DBFolderItem.h"

//#define kCurrentNotificationVersion @"1.0"
//#define kCurrentNotificationVersion @"1.1"  //New notification scheduler, released in version 1.2
//#define kCurrentNotificationVersion @"1.2"  //Fix badge bug, ignore items archived and count is 0, released in version 1.3
#define kCurrentNotificationVersion @"1.3"  //New scheduler for Core Data

@interface ExpiryNotificationScheduler : NSObject
+ (void)rescheduleAllNotifications;

+ (void)enableReceivingNotifications;
+ (void)disableReceivingNotifications;
@end
