//
//  DataBackupRestoreAgentDelegate.m
//  ShopFolder
//
//  Created by Michael Tsai on 2012/02/21.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DataBackupRestoreAgent.h"
#import "ZipFile.h"
#import "FileInZipInfo.h"
//#import "ZipWriteStream.h"
//#import "ZipReadStream.h"
//#import "ZipException.h"
#import "TimeUtil.h"
#import "StringUtil.h"
#import "Database.h"    //For restoring old database and convert to the new one
#import "CoreDataDatabase.h"
#import "PreferenceConstant.h"
#import "FlurryAnalytics.h"
#import "ZipArchive.h"

#define kShowDebugLog   1

//#define kZipBufferSize  4096 //byte
//#define kBakSuffix      @"_bak"

@interface DataBackupRestoreAgent ()

@end

@implementation DataBackupRestoreAgent
@synthesize delegate;

static dispatch_queue_t gRunningQueue;
static BOOL gCancelled;
static DataBackupRestoreAgent *gInstance;

+ (id)sharedSingleton
{
    return gInstance;
}

+ (void)initialize
{
    if(self == [DataBackupRestoreAgent class]) {
        if(!gInstance) {
            gRunningQueue = dispatch_queue_create("BackupRestoreQueue", NULL);
            gInstance = [DataBackupRestoreAgent new];
        }
    }
}

- (void)cancelLastOperation
{
    gCancelled = YES;
}

- (NSString *)createBackupFileWithName:(NSString *)fileName moveToDocument:(BOOL)move
{
    //Backup to tmp and then move to Documents
    NSString *zipFilePath = [StringUtil fullPathInTemp:fileName];
    NSString *fileNameToZip;
    
    void(^removeBackupFileBlock)(ZipArchive *zip) = ^(ZipArchive *zip) {
        [zip CloseZipFile2];
        [[NSFileManager defaultManager] removeItemAtPath:zipFilePath error:nil];
    };
    
    //1. Add .sqlite file
    NSURL *sourceURL = [CoreDataDatabase databaseURL];
    NSString *sourceFilePath = [sourceURL path];
    
#ifdef DEBUG
#if kShowDebugLog
    NSLog(@"Start backup to %@ ...", kDataBaseFileName);
#endif
#endif
    ZipArchive *zip = [[ZipArchive alloc] init];
    
    [zip CreateZipFile2:zipFilePath];
    if(![zip CreateZipFile2:zipFilePath]) {
        removeBackupFileBlock(zip);
        return nil;
    }
    
    if(![zip addFileToZip:sourceFilePath newname:kDataBaseFileName]) {
        removeBackupFileBlock(zip);
        return nil;
    }
    
    //2. Add .XXX_SUPPORT
    sourceURL =  [CoreDataDatabase externalBlobURL];
    sourceFilePath = [NSString stringWithFormat:@"%@/_EXTERNAL_DATA", [sourceURL path]];
    NSString *blobFolderName = [NSString stringWithFormat:@"%@/_EXTERNAL_DATA", kDatabaseExtStorage];
    NSArray *fileList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:sourceFilePath error:nil];
    for(NSString *fileName in fileList) {
        fileNameToZip = [NSString stringWithFormat:@"%@/%@", blobFolderName, fileName];
        
#ifdef DEBUG
#if kShowDebugLog
        NSLog(@"Add %@", fileNameToZip);
#endif
#endif
        
        if(![zip addFileToZip:[NSString stringWithFormat:@"%@/%@", sourceFilePath, fileName] newname:fileNameToZip]) {
            removeBackupFileBlock(zip);
            return nil;
        }
    }
    
    [zip CloseZipFile2];
    
    //Move from tmp to Documents
    if(move &&
       ![[NSFileManager defaultManager] moveItemAtPath:zipFilePath toPath:[StringUtil fullPathInDocument:fileName] error:nil])
    {
        NSLog(@"Cannot move %@", zipFilePath);
        [[NSFileManager defaultManager] removeItemAtPath:zipFilePath error:nil];
        return nil;
    }
    
    return zipFilePath;
}

- (void)backupToiTunes
{
    NSString *fileName = [NSString stringWithFormat:@"%@%@%@", kBackupFileNamePrefix, 
                          [TimeUtil dateToString:[NSDate date] inFormat:@"yyyyMMdd_HHmmss"], kBackupFileNameSuffix];
    gCancelled = YES;   //Cancel last running operation
    
    dispatch_async(gRunningQueue, ^{
        gCancelled = NO;
        [[NSUserDefaults standardUserDefaults] setValue:kBackupOperation forKey:kLastBackupRestoreOperation];
        [[NSUserDefaults standardUserDefaults] setValue:fileName forKey:kLastBackupFileInProcess];
        [[NSUserDefaults standardUserDefaults] synchronize];

        if([self createBackupFileWithName:fileName moveToDocument:YES]) {
            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupRestoreOperation];
            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupFileInProcess];
            [[NSUserDefaults standardUserDefaults] synchronize];

            [self.delegate finishBackupToiTunesWithName:fileName];
        } else {
            [self.delegate failToBackupWithError:nil];
        }
    });
}

- (void)backupToDropbox
{
    NSString *fileName = [NSString stringWithFormat:@"%@%@%@", kBackupFileNamePrefix,
                          [TimeUtil dateToString:[NSDate date] inFormat:@"yyyyMMdd_HHmmss"], kBackupFileNameSuffix];
    gCancelled = YES;   //Cancel last running operation
    
    dispatch_async(gRunningQueue, ^{
        gCancelled = NO;
        [[NSUserDefaults standardUserDefaults] setValue:kBackupOperation forKey:kLastBackupRestoreOperation];
        [[NSUserDefaults standardUserDefaults] setValue:fileName forKey:kLastBackupFileInProcess];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        NSString *zipFilePath;
        if((zipFilePath = [self createBackupFileWithName:fileName moveToDocument:NO])) {
            [self.delegate readyToUploadFile:fileName fromPath:zipFilePath];

            //Since delegate is implemented in ViewController, so we have to set those in delegate
//            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupRestoreOperation];
//            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupFileInProcess];
//            [[NSUserDefaults standardUserDefaults] synchronize];
//            
//            [self.delegate finishBackupToiTunesWithName:fileName];
        } else {
            [self.delegate failToBackupWithError:nil];
        }
    });
}

- (void)restoreFromiTunes:(NSString *)backupFileName
{
    [self restoreFromPath:[StringUtil fullPathInDocument:backupFileName]];
}

- (void)restoreFromPath:(NSString *)backupFilePath
{
    gCancelled = YES;   //Cancel last running operation
    
    [[NSUserDefaults standardUserDefaults] setValue:kRestoreoperation forKey:kLastBackupRestoreOperation];
    [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupFileInProcess];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    //1. Check existness of backup file
    if(![[NSFileManager defaultManager] fileExistsAtPath:backupFilePath]) {
        NSLog(@"Error: Backup file does not exist.");
        [self.delegate failToRestoreWithError:nil];
        return;
    }
    
    //2. Backup current data
    //Old database should be converted, so we just backup the new one
    NSArray *oldPaths = [NSArray arrayWithObjects:
                         [[CoreDataDatabase databaseURL] path],
                         [[CoreDataDatabase externalBlobURL] path], nil];
    NSString *newPath;
    NSString *bakSuffix = [NSString stringWithFormat:@"_%d", (int)[[NSDate date] timeIntervalSinceReferenceDate]];
    [[NSUserDefaults standardUserDefaults] setValue:bakSuffix forKey:kLastBackupFileSuffix];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    for(NSString *oldPath in oldPaths) {
        newPath = [NSString stringWithFormat:@"%@%@", oldPath, bakSuffix];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:newPath]) {
            if(![[NSFileManager defaultManager] removeItemAtPath:newPath error:nil]) {
                NSLog(@"Cannot remove existed backup file of %@", newPath);
            }
        }
        
        if(![[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:nil]) {
            NSLog(@"Cannot backup %@", oldPath);
        }
    }
    [CoreDataDatabase resetDatabase];
    
    dispatch_async(gRunningQueue, ^{
        gCancelled = NO;
        
        //3. Restore from backupFile
        void(^restoreBackupFileBlock)() = ^{
            NSString *newPath;
            
            for(NSString *backupPath in oldPaths) {
                newPath = [NSString stringWithFormat:@"%@%@", backupPath, bakSuffix];
                
                if([[NSFileManager defaultManager] fileExistsAtPath:backupPath]) {
                    if(![[NSFileManager defaultManager] removeItemAtPath:backupPath error:nil]) {
                        NSLog(@"Cannot remove existed backup file of %@", backupPath);
                    }
                }
                
                if(![[NSFileManager defaultManager] moveItemAtPath:newPath toPath:backupPath error:nil]) {
                    NSLog(@"Cannot restore %@", backupPath);
                }
            }
            
            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupFileSuffix];
            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupRestoreOperation];
            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupFileInProcess];
            [[NSUserDefaults standardUserDefaults] synchronize];
        };
        
        void(^removeBackupFileBlock)() = ^{
            NSString *bakPath;
            
            for(NSString *backupPath in oldPaths) {
                bakPath = [NSString stringWithFormat:@"%@%@", backupPath, bakSuffix];
                
                if([[NSFileManager defaultManager] fileExistsAtPath:bakPath]) {
                    if(![[NSFileManager defaultManager] removeItemAtPath:bakPath error:nil]) {
                        NSLog(@"Cannot remove existed backup file of %@", bakPath);
                    }
                }
            }
            
            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupFileSuffix];
            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupRestoreOperation];
            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupFileInProcess];
            [[NSUserDefaults standardUserDefaults] synchronize];
        };
        
        ZipArchive *zip = [ZipArchive new];
        if(![zip UnzipOpenFile:backupFilePath]) {
            restoreBackupFileBlock();
            [self.delegate failToRestoreWithError:nil];
            return;
        }
        
        //Check DB version and decide destination
        NSString *restoreDestination = [StringUtil fullPathInLibrary:nil];
        ZipFile *unzipFile = [[ZipFile alloc] initWithFileName:backupFilePath mode:ZipFileModeUnzip];
        NSArray *fileInfos = [unzipFile listFileInZipInfos];
        for(FileInZipInfo *fileInfo in fileInfos) {
            if([fileInfo.name hasPrefix:kItemImagePrefix]) {
                restoreDestination = [StringUtil fullPathInDocument:nil];
                break;
            }
        }
        
        if(![zip UnzipFileTo:restoreDestination overWrite:YES]) {
            restoreBackupFileBlock();
            [self.delegate failToRestoreWithError:nil];
            return;
        }
        
        removeBackupFileBlock();
        [self.delegate finishRestore];
    });
}

+ (BOOL)isLastOperationFail
{
    return ([[[NSUserDefaults standardUserDefaults] objectForKey:kLastBackupRestoreOperation] length] > 0);
}

+ (void)recoverFromLastFailOperation
{
    NSString *lastOperation = [[NSUserDefaults standardUserDefaults] valueForKey:kLastBackupRestoreOperation];
    if([lastOperation length] == 0) {
        return;
    }
    
    if([kBackupOperation isEqualToString:lastOperation]) {
        NSString *backupFile = [[NSUserDefaults standardUserDefaults] valueForKey:kLastBackupFileInProcess];
        NSString *fullPath = [StringUtil fullPathInTemp:backupFile];
        BOOL succeed = YES;
        if([[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
            if(![[NSFileManager defaultManager] removeItemAtPath:fullPath error:nil]) {
                NSLog(@"Fail to remove last in-process backup file");
                succeed = NO;
            }
        } else {
            NSLog(@"Last in-in-process backup(%@) file is not found", backupFile);
        }
        
        if(succeed) {
            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupFileInProcess];
            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupRestoreOperation];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    } else {
        NSArray *oldPaths = [NSArray arrayWithObjects:
                             [[CoreDataDatabase databaseURL] path],
                             [[CoreDataDatabase externalBlobURL] path], nil];
        NSString *newPath;
        NSString *bakSuffix = [[NSUserDefaults standardUserDefaults] valueForKey:kLastBackupFileSuffix];
        for(NSString *backupPath in oldPaths) {
            newPath = [NSString stringWithFormat:@"%@%@", backupPath, bakSuffix];
            
            if([[NSFileManager defaultManager] fileExistsAtPath:backupPath]) {
                if(![[NSFileManager defaultManager] removeItemAtPath:backupPath error:nil]) {
                    NSLog(@"Cannot remove existed backup file of %@", backupPath);
                }
            }
            
            if(![[NSFileManager defaultManager] moveItemAtPath:newPath toPath:backupPath error:nil]) {
                NSLog(@"Cannot restore %@", backupPath);
            }
        }
        
        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupFileInProcess];
        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupRestoreOperation];
        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupFileSuffix];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}
@end
