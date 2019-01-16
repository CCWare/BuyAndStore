//
//  AppSettingViewController.h
//  ShopFolder
//
//  Created by Michael on 2011/11/23.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SetNotificationTimeViewController.h"
#import "TutorialViewController.h"
#import "FeedbackViewController.h"
#import "DataBackupRestoreAgent.h"
#import "MBProgressHUD.h"
#import "BackupFilePicker.h"
#import "iTunesBackupFilePicker.h"
#import "DropboxBackupFilePicker.h"
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "ExpiryListViewController.h"
#import <DropboxSDK/DropboxSDK.h>
#import "Reachability.h"

@protocol AppSettingViewControllerDelegate;

@interface AppSettingViewController : UIViewController <UITableViewDelegate, UITableViewDataSource,
                                                        UIImagePickerControllerDelegate, UINavigationControllerDelegate,
                                                        UIActionSheetDelegate, UIAlertViewDelegate,
                                                        MFMailComposeViewControllerDelegate,
                                                        SetNotificationTimeViewControllerDelegate,
                                                        TutorialViewControllerDelegate, FeedbackViewControllerDelegate,
                                                        DataBackupRestoreAgentDelegate, BackupFilePickerDelegate,
                                                        ExpiryListViewControllerDelegate, DBRestClientDelegate>
{
    UITableView *table;
    
    BOOL hasRearCam;
    
    UIActionSheet *importDBSheet;
    UIActionSheet *exportDBSheet;
@private
    MBProgressHUD *_hud;
    UIAlertView *_backupConfirmAlert;
    UIAlertView *_restoreConfirmAlert;
    NSString *_restoreFileName;
    
    int _restoreSource;
    
    DBRestClient *_restClient;
    BOOL _loggingInDropbox;
    BOOL _isBackup;
    UIAlertView *_cellularNetworkAlert;
    Reachability *_internetReachable;
    UILabel *_footerLabelForDatabaseSection;
}

@property (nonatomic, strong) IBOutlet UITableView *table;
@property (nonatomic, weak) id <AppSettingViewControllerDelegate> delegate;
- (IBAction)done:(id)sender;
@end

@protocol AppSettingViewControllerDelegate
- (void)flipsideViewControllerDidFinish:(AppSettingViewController *)controller;
- (void)databaseRestored;
@end

