//
//  NotificationConstant.h
//  ShopFolder
//
//  Created by Michael on 2011/11/18.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>

//===== Notification names =====
#define kExpirePreferenceChangeNotification     @"ExpirePreferenceChangeNotification"

#define kDisablePageScrollNotification          @"DisablePageScrollNotification"
#define kEnablePageScrollNotification           @"EnablePageScrollNotification"

#define kMoveItemsNotification                  @"MoveItemsNotification"

//===== Notification UserInfo keys =====
#define kSelectedItemsToMove                    @"SelectedItemsToMove"    //Array of SelectedFolderItem
