//
//  BackupFilePicker.h
//  ShopFolder
//
//  Created by Michael Tsai on 2012/02/23.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DataBackupRestoreAgent.h"
#import "MBProgressHUD.h"

@protocol BackupFilePickerDelegate
- (void)selectBackupFile:(NSString *)fileName;
@end

@interface BackupFileProperty : NSObject
{
    NSString *name;
    NSNumber *sizeInByte;
}

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSNumber *sizeInByte;

- (NSComparisonResult)compare:(BackupFileProperty *)file;
@end

@interface BackupFilePicker : UIViewController <UITableViewDelegate, UITableViewDataSource,
                                                MBProgressHUDDelegate>
{
    NSMutableArray *fileList;
    MBProgressHUD *hud;
}

@property (nonatomic, strong) IBOutlet UITableView *table;
@property (nonatomic, weak) id<BackupFilePickerDelegate> delegate;

@end
