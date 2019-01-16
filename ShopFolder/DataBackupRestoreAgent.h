//
//  DataBackupRestoreAgentDelegate.h
//  ShopFolder
//
//  Created by Michael Tsai on 2012/02/21.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DropboxSDK/DropboxSDK.h>

#define kBackupOperation        @"BackupOperation"
#define kRestoreoperation       @"RestoreOperation"

#define kBackupFileNamePrefix   @"BuyRecord_"
#define kBackupFileNameSuffix   @".db"

#define kFileNotFoundExceptionName          @"FileNotFoundException"
#define kOperationCancelledExceptionName    @"OperationCancelledExceptionName"

@protocol DataBackupRestoreAgentDelegate
@optional
- (void)finishBackupToiTunesWithName:(NSString *)backupFileName;
- (void)finishRestore;
- (void)progressUpdated:(int)progress;  //0~100
- (void)failToBackupWithError:(NSError *)error;
- (void)failToRestoreWithError:(NSError *)error;

- (void)readyToUploadFile:(NSString *)name fromPath:(NSString *)path;
@end

@interface DataBackupRestoreAgent : NSObject
{
}

@property (nonatomic, weak) id<DataBackupRestoreAgentDelegate> delegate;

+ (id)sharedSingleton;
+ (BOOL)isLastOperationFail;
+ (void)recoverFromLastFailOperation;

- (NSString *)createBackupFileWithName:(NSString *)fileName moveToDocument:(BOOL)move;
- (void)cancelLastOperation;

- (void)backupToiTunes;
- (void)backupToDropbox;
//- (void)backupToiCloud;

- (void)restoreFromiTunes:(NSString *)backupFileName;
- (void)restoreFromPath:(NSString *)backupFilePath;
//- (void)restoreFromiCloud:(NSString *)backupFileName;   //not final API
@end
