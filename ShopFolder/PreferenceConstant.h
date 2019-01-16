//
//  PreferenceConstant.h
//  ShopFolder
//
//  Created by Michael on 2011/11/24.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#ifndef ShopFolder_PreferenceConstant_h
#define ShopFolder_PreferenceConstant_h

#define kCurrentPage        @"CurrentPage"      //INT
#define kIsInShoppingList   @"IsInShoppingList" //BOOL

//===== For Settings =====
//Notice that the string must sync with Defaults.plist
#define kSettingUseBarcodeScanner       @"SettingUseBarcodeScanner"         //BOOL  //For iPhone 3G, iPod touch and iPad2
#define kSettingVibrateBarcodeDetection @"SettingVibrateBarcodeDetection"   //BOOL
#define kSettingSoundBarcodeDetection   @"SettingSoundBarcodeDetection"     //BOOL
#define kSettingNotifyExpired           @"SettingNotifyExpired"             //BOOL
#define kSettingNotifyNearExpired       @"SettingNotifyNearExpired"         //BOOL
#define kSettingDailyNotifyHour         @"SettingDailyNotifyHour"           //0-23
#define kSettingDailyNotifyMinute       @"SettingDailyNotifyMinute"         //0-59, interval: 5
#define kSettingNearExpiredDays         @"SettingNearExpiredDays"           //1-7, 30, 60, 90

#define kSettingShowTutorial            @"SettingShowTutorial"              //BOOL

#define kSettingNoticeBarcodeScanner    @"NoticeBarcodeScanner"             //BOOL, If YES, notice users about barcode problem

#define kHasScheduledNotifications      @"HasScheduledNotifications"        //BOOL
#define kNotificationVersion            @"NotificationVersion"              //String

#define kLastSortField                  @"LastSortField"                    //0-4
#define kLastSortOrder                  @"LastSortOrder"                    //0,1

#define kLastBackupRestoreOperation     @"LastBackupRestoreOperation"       //NSString, Backup/RestoreOperation, see DataBackupRestoreAgent.h
#define kLastBackupFileInProcess        @"LastBackupFileInProcess"          //NSString
#define kLastBackupFileSuffix           @"LastBackupFileSuffix"             //NSString  //"_ooooo" in xxx.sqlite_ooooo 

#define kIsInProtectedFolder            @"IsInProtectedFolder"              //BOOL
#define kShoppingListCountTextMode      @"ShoppingListCountTextMode"        //0, 1

#define kPurchaseUnlimitCount           @"PurchaseUnlimitCount"             //BOOL
//#define kPurchaseRemoveAD               @"PurchaseRemoveAD"                 //BOOL, Deprecated, but keep for future use

#define kSettingAllowAnalysis           @"SettingAllowAnalysis"             //BOOL

#define kLastExpiryListShowTime         @"LastExpiryListShowTime"           //INT, timeIntervalSinceReferenceDate of midnight

#endif
