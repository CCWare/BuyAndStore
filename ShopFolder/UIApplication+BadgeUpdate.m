//
//  UIApplication+BadgeUpdate.m
//  ShopFolder
//
//  Created by Michael on 2011/11/21.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "UIApplication+BadgeUpdate.h"
#import "CoreDataDatabase.h"
#import "TimeUtil.h"

@implementation UIApplication (BadgeUpdate)
- (void)refreshApplicationBadgeNumber
{
//    dispatch_async(dispatch_get_main_queue(), ^{
        NSManagedObjectContext *moc = [CoreDataDatabase getContextForCurrentThread];
        [UIApplication sharedApplication].applicationIconBadgeNumber =
            [CoreDataDatabase totalExpiredItemsBeforeAndIncludeDate:[TimeUtil today] inContext:moc];
//    });
}
@end
