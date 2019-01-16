//
//  DropboxBackupFilePicker.h
//  ShopFolder
//
//  Created by Michael on 2012/12/24.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "BackupFilePicker.h"
#import <DropboxSDK/DropboxSDK.h>

@interface DropboxBackupFilePicker : BackupFilePicker <DBRestClientDelegate, UIAlertViewDelegate>

@end
