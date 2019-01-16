//
//  AppSettingViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/11/23.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "AppSettingViewController.h"
#import "PreferenceConstant.h"
#import "TimeUtil.h"
#import "NotificationConstant.h"
#import "SetExpirePeriodViewController.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "TutorialListViewController.h"
#import "HardwareUtil.h"
#import "PickLocationViewController.h"
#import "UIDevice+machine.h"
#import "FlurryAnalytics.h"
#import "FlurryKey.h"
#import "CoreDataDatabase.h"
#import "DatabaseConverter.h"
#import "UIApplication+BadgeUpdate.h"
#import "ExpiryNotificationScheduler.h"
#import "VersionCompare.h"
#import "ExpiryListViewController.h"
#import "ColorConstant.h"
#import <DropboxSDK/DropboxSDK.h>
#import "StringUtil.h"

//Sections
static int kSectionBarcodeScan          = 0;
static int kSectionExpiredNotification  = 1;
//static int kSectionChangeBackground       = kSectionExpiredNotification+1;
//static int kSectionSocialShare            = kSectionChangeBackground+1;
//static int kSectionShowHint               = kSectionUserFeedback+1;
static int kSectionShowExpiryList       = 2;
static int kSectionEditLocation         = 3;
static int kSectionImportExport         = 4;
static int kSectionTutorial             = 5;
static int kSectionUserFeedback         = 6;
//static int kSectionAnaysis              = 7;

//Rows in barcode scan section
#define kRowVibrateBarcodeDetection 0
#define kRowSoundBarcodeDetection   1

//Rows in expire notification section
#define kRowNotifyExpired           0
#define kRowNotifyNearExpired       1
#define kRowDailyNotifyTime         2

//Rows in Import/Export section
#define kRowBackupDatabase          0
#define kRowRestoreDatabase         1
#define kRowLogoutDropbox           2

//Rows in Feedback
static int kRowRateApp      = 0;
static int kRowReportBug    = 1;
static int kRowFillForm     = 2;

#define kCommonCellIdentifier       @"CommonCellIdentifier"

#define kRestoreFromiTunes  0
#define kRestoreFromDropbox 1

#define kFooterHeight       20.0f

@interface AppSettingViewController ()
- (void)_barcodeVibrationChange:(UISwitch *)sender;
- (void)_barcodeSoundChange:(UISwitch *)sender;

- (void)_expiredChange:(UISwitch *)sender;
- (void)_nearExpiredChange:(UISwitch *)sender;
- (void)_changeNotificationTime;
- (void)_changeBackground;

- (void)_setDayCell:(UITableViewCell *)cell withDays:(int)days;

- (void)_applicationWillResignActive;

- (void)_composeMailTo:(NSString *)receiver withSubject:(NSString *)subject andBody:(NSString *)body;

- (void)_allowAnalysisChange:(UISwitch *)sender;

- (BOOL)_shouldShowExpiryList;
- (void)_backupToDropbox;
- (void)_checkNetworkStatus;
- (void)_receiveNetworkChangeNotification:(NSNotification *)notification;
- (void)_receiveDidBecomeActiveNotification:(NSNotification *)notification;

@property (nonatomic, strong) DBRestClient *_restClient;
@end

@implementation AppSettingViewController
@synthesize table;
@synthesize delegate;
@synthesize _restClient;

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];

    self.table = nil;
    
    _hud.delegate = nil;
    [_hud hide:NO];
    [_hud removeFromSuperview]; //if _hud.removeFromSuperViewOnHide == NO
    _hud = nil;
    
    _footerLabelForDatabaseSection = nil;
}

- (void)dealloc
{
    _hud.delegate = nil;
    [_hud hide:NO];
    _hud.removeFromSuperViewOnHide = NO;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.contentSizeForViewInPopover = [[UIScreen mainScreen] bounds].size;
        
        _hud = [[MBProgressHUD alloc]
                initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width,
                                         [[UIScreen mainScreen] bounds].size.height-[[UIApplication sharedApplication] statusBarFrame].size.height-44.0)];
        [self.view addSubview:_hud];
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_applicationWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_receiveDidBecomeActiveNotification:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    if([HardwareUtil hasRearCam]) {
        hasRearCam = YES;
    } else {
        hasRearCam = NO;
        if(kSectionBarcodeScan >= 0) {  //prevent to delete rows when go to and comes back from settings
            kSectionBarcodeScan = -1;
            kSectionExpiredNotification--;
//            kSectionChangeBackground--;
//            kSectionSocialShare--;
//            kSectionShowHint--;
            kSectionShowExpiryList--;
            kSectionEditLocation--;
            kSectionImportExport--;
            kSectionTutorial--;
            kSectionUserFeedback--;
//            kSectionAnaysis--;
        }
    }
    
    if([self _shouldShowExpiryList]) {
        if(kSectionShowExpiryList < 0) {
            kSectionShowExpiryList = kSectionExpiredNotification + 1;
            kSectionEditLocation++;
            kSectionImportExport++;
            kSectionTutorial++;
            kSectionUserFeedback++;
//            kSectionAnaysis++;
        }
    } else {
        if(kSectionShowExpiryList >= 0) {
            kSectionShowExpiryList = -1;
            kSectionEditLocation--;
            kSectionImportExport--;
            kSectionTutorial--;
            kSectionUserFeedback--;
//            kSectionAnaysis--;
        }
    }
    
#ifdef _LITE_
    kRowRateApp     = 0;
    kRowReportBug   = 1;
    kRowFillForm    = 2;
    if(![[NSUserDefaults standardUserDefaults] boolForKey:kPurchaseUnlimitCount]) {
        kRowRateApp--;
        kRowReportBug--;
        kRowFillForm--;
    }
#endif

    // Do any additional setup after loading the view from its nib.
    self.title = NSLocalizedString(@"Settings", nil);
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                target:self
                                                                                action:@selector(done:)];
    self.navigationItem.rightBarButtonItem = doneButton;

    _internetReachable = [Reachability reachabilityForInternetConnection];
    
    _footerLabelForDatabaseSection = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, kFooterHeight)];
    _footerLabelForDatabaseSection.font = [UIFont systemFontOfSize:16];
    _footerLabelForDatabaseSection.shadowColor = [UIColor whiteColor];
    _footerLabelForDatabaseSection.shadowOffset = CGSizeMake(0, 1);
    _footerLabelForDatabaseSection.textAlignment = UITextAlignmentCenter;
    _footerLabelForDatabaseSection.textColor = [UIColor colorWithRed:76.0f/255.0f green:86.0f/255.0f blue:108.0f/255.0f alpha:1.0f];
    _footerLabelForDatabaseSection.backgroundColor = [UIColor clearColor];
    _footerLabelForDatabaseSection.opaque = NO;
    
    [self _checkNetworkStatus];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_receiveNetworkChangeNotification:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    [_internetReachable startNotifier];
}

- (void)viewWillAppear:(BOOL)animated
{
    NSIndexPath *selectedIndex = [self.table indexPathForSelectedRow];
    if(selectedIndex) {
        [self.table deselectRowAtIndexPath:selectedIndex animated:NO];
    }
    
    self.navigationItem.rightBarButtonItem.tintColor = kColorDoneButton;
    
    if(_loggingInDropbox) {
        _loggingInDropbox = NO;
        
        if ([[DBSession sharedSession] isLinked]) {
            if(_isBackup) {
                [self _backupToDropbox];
            } else {
                DropboxBackupFilePicker *filePicker = [DropboxBackupFilePicker new];
                filePicker.delegate = self;
                [self.navigationController pushViewController:filePicker animated:NO];
            }
        }
    }
    
    if([[DBSession sharedSession] isLinked]) {
        [self.table beginUpdates];
        [self.table reloadSections:[NSIndexSet indexSetWithIndex:kSectionImportExport]
                                                withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.table endUpdates];
    }
    
    [super viewWillAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

//==============================================================
//  [BEGIN] UITableViewDataSource
#pragma mark -
#pragma mark UITableViewDataSource Methods
//--------------------------------------------------------------
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    int nSection = 7;
    if(kSectionBarcodeScan < 0) {
        nSection--;
    }
    
    if(kSectionShowExpiryList < 0) {
        nSection--;
    }
    
    return nSection;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(section == kSectionBarcodeScan) {
        return 2;
    } else if(section == kSectionExpiredNotification) {
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingNotifyExpired] || 
           [[NSUserDefaults standardUserDefaults] boolForKey:kSettingNotifyNearExpired])
        {
            return 3;
        } else {
            return 2;   //hide "time" row
        }
    } else if(section == kSectionImportExport) {
        if([[DBSession sharedSession] isLinked]) {
            return 3;
        }
        
        return 2;
    } else if(section == kSectionUserFeedback) {
#ifdef _LITE_
        if(/*[[NSUserDefaults standardUserDefaults] boolForKey:kPurchaseRemoveAD] ||*/
           [[NSUserDefaults standardUserDefaults] boolForKey:kPurchaseUnlimitCount])
        {
            return 3;
        } else {
            return 2;
        }
#else
        return 3;
#endif
    }

    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if(section == kSectionBarcodeScan) {
        return NSLocalizedString(@"Barcode detected responce", nil);
    } else if(section == kSectionExpiredNotification) {
        return NSLocalizedString(@"Expiry notification", nil);
    }
    
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    NSString *cellIdentifier;
    if(indexPath.section == kSectionShowExpiryList) {
        cellIdentifier = kCommonCellIdentifier;
        cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if(cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        }
        
        cell.textLabel.textAlignment = UITextAlignmentCenter;
        cell.textLabel.text = NSLocalizedString(@"Expiry List", nil);
    } else if(indexPath.section == kSectionBarcodeScan) {
        if(indexPath.row == kRowVibrateBarcodeDetection) {
            cellIdentifier = @"kRowVibrateBarcodeDetection";
            cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
            if(cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
                cell.textLabel.text = NSLocalizedString(@"Vibration", nil);

                UISwitch *switchView = [[UISwitch alloc] init];
                switchView.on = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingVibrateBarcodeDetection];
                [switchView addTarget:self action:@selector(_barcodeVibrationChange:) forControlEvents:UIControlEventTouchUpInside];
                cell.accessoryView = switchView;
            }
        } else {    //kRowSoundBarcodeDetection
            cellIdentifier = @"kRowSoundBarcodeDetection";
            cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
            if(cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
                cell.textLabel.text = NSLocalizedString(@"Sound", nil);

                UISwitch *switchView = [[UISwitch alloc] init];
                switchView.on = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingSoundBarcodeDetection];
                [switchView addTarget:self action:@selector(_barcodeSoundChange:) forControlEvents:UIControlEventTouchUpInside];
                cell.accessoryView = switchView;
            }
        }
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if(indexPath.section == kSectionExpiredNotification) {
        BOOL notifyExpired = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingNotifyExpired];
        BOOL alertNearlyExpired = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingNotifyNearExpired];
        if(indexPath.row == kRowNotifyExpired) {
            cellIdentifier = @"kRowNotifyExpired";
            cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
            if(cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
                cell.textLabel.text = NSLocalizedString(@"Notify expired", nil);
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                
                UISwitch *switchView = [[UISwitch alloc] init];
                switchView.on = notifyExpired;
                [switchView addTarget:self action:@selector(_expiredChange:) forControlEvents:UIControlEventTouchUpInside];
                cell.accessoryView = switchView;
            }
        } else if(indexPath.row == kRowNotifyNearExpired) {
            cellIdentifier = @"kRowNotifyNearExpired";
            cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
            if(cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
                cell.textLabel.text = NSLocalizedString(@"Notify near-expired", nil);
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                
                UISwitch *switchView = [[UISwitch alloc] init];
                switchView.on = alertNearlyExpired;
                [switchView addTarget:self action:@selector(_nearExpiredChange:) forControlEvents:UIControlEventTouchUpInside];
                cell.accessoryView = switchView;
            }
        } else if (notifyExpired || alertNearlyExpired) {    //kRowDailyNotifyTime
            cellIdentifier = @"kRowDailyNotifyTime";
            cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
            if(cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
                cell.textLabel.text = NSLocalizedString(@"Notification time", nil);
                int nHour = [[NSUserDefaults standardUserDefaults] integerForKey:kSettingDailyNotifyHour];
                int nMinute = [[NSUserDefaults standardUserDefaults] integerForKey:kSettingDailyNotifyMinute];
                cell.detailTextLabel.text = [TimeUtil stringFromHour:nHour minute:nMinute];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
        }
    } else if(indexPath.section == kSectionEditLocation) {
        cellIdentifier = kCommonCellIdentifier;
        cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if(cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        }
        
        cell.textLabel.textAlignment = UITextAlignmentCenter;
        cell.textLabel.text = NSLocalizedString(@"Edit/Add Places", @"Row in settings");
    } else if(indexPath.section == kSectionImportExport) {
        cellIdentifier = kCommonCellIdentifier;
        cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if(cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        }

        cell.textLabel.textAlignment = UITextAlignmentCenter;
        if(indexPath.row == kRowRestoreDatabase) {
            cell.textLabel.text = NSLocalizedString(@"Restore Database", @"Row in settings");
        } else if(indexPath.row == kRowBackupDatabase){
            cell.textLabel.text = NSLocalizedString(@"Backup Database", @"Row in settings");
        } else if(indexPath.row == kRowLogoutDropbox) {
            cell.textLabel.text = NSLocalizedString(@"Unlink Dropbox", @"Row in settings");
        }
    } else if(indexPath.section == kSectionTutorial) {
        cellIdentifier = kCommonCellIdentifier;
        cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if(cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        }
        
        cell.textLabel.textAlignment = UITextAlignmentCenter;
        cell.textLabel.text = NSLocalizedString(@"Helps & Tutorials", @"Row in settings");
    } else if(indexPath.section == kSectionUserFeedback) {
        cellIdentifier = kCommonCellIdentifier;
        cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if(cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        }
        
        cell.textLabel.textAlignment = UITextAlignmentCenter;
        if(indexPath.row == kRowRateApp) {
            cell.textLabel.text = NSLocalizedString(@"Rate This App", @"Row in settings");
        } else if(indexPath.row == kRowReportBug) {
            cell.textLabel.text = NSLocalizedString(@"Report Bug", @"Row in settings");
        } else if(indexPath.row == kRowFillForm) {
            cell.textLabel.text = NSLocalizedString(@"Feedback", @"Row in settings");
        }
    }
//    else if(indexPath.section == kSectionAnaysis) {
//        cellIdentifier = @"kRowCollectData";
//        cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
//        if(cell == nil) {
//            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
//            cell.textLabel.text = NSLocalizedString(@"Polish the app with us", nil);
//            cell.selectionStyle = UITableViewCellSelectionStyleNone;
//            
//            UISwitch *switchView = [[UISwitch alloc] init];
//            switchView.on = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis];
//            [switchView addTarget:self action:@selector(_allowAnalysisChange:) forControlEvents:UIControlEventTouchUpInside];
//            cell.accessoryView = switchView;
//        }
//    }
//    else if(indexPath.section == kSectionChangeBackground) {
//        cellIdentifier = @"kSectionChangeBackground";
//        cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
//        if(cell == nil) {
//            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier] autorelease];
//            cell.textLabel.text = NSLocalizedString(@"Background", nil);
//            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
//        }
//      
//    }
    else {
        cell = [[UITableViewCell alloc] init];
    }

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if(section == kSectionImportExport) {
        return kFooterHeight;
    }
    
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if(section == kSectionImportExport) {
        return _footerLabelForDatabaseSection;
    }
    
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if(section == kSectionBarcodeScan &&
       ![HardwareUtil canAutoFocus])
    {
        return NSLocalizedString(@"The barcode scanner may not work perfectly without Autofocus Camera.", nil);
    }
    
//    if(section == kSectionAnaysis) {
//        return NSLocalizedString(@"We only collect anonymous statistics. We do not collect any personal data and the contents of your folders and items.", nil);
//    }
    
    return nil;
}
//--------------------------------------------------------------
//  [END] UITableViewDataSource
//==============================================================

//==============================================================
//  [BEGIN] UITableViewDelegate
#pragma mark -
#pragma mark UITableViewDelegate Methods
//--------------------------------------------------------------
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == kSectionShowExpiryList) {
        ExpiryListViewController *listVC = [ExpiryListViewController new];
        listVC.delegate = self;
        [self.navigationController pushViewController:listVC animated:YES];
    } else if(indexPath.section == kSectionExpiredNotification) {
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingNotifyExpired] ||
           [[NSUserDefaults standardUserDefaults] boolForKey:kSettingNotifyNearExpired])
        {
            switch (indexPath.row) {
                case kRowDailyNotifyTime:
                    [self _changeNotificationTime];
                default:
                    break;
            }
        }
    } else if(indexPath.section == kSectionEditLocation) {
        PickLocationViewController *pickLocationVC = [[PickLocationViewController alloc] init];
        pickLocationVC.title = NSLocalizedString(@"Edit/Add Places", nil);
        pickLocationVC.searchBarColor = [UIColor blackColor];
        [self.navigationController pushViewController:pickLocationVC animated:YES];
    } else if(indexPath.section == kSectionImportExport) {
        if(indexPath.row == kRowRestoreDatabase) {
            if([_internetReachable currentReachabilityStatus] != NotReachable) {
                importDBSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Restore Database", nil)
                                                            delegate:self
                                                   cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                              destructiveButtonTitle:nil
                                                   otherButtonTitles:[NSString stringWithFormat:NSLocalizedString(@"From %@", @"Choose backup source"), @"iTunes"],
                                                                     [NSString stringWithFormat:NSLocalizedString(@"From %@", @"Choose backup source"), @"Dropbox"], nil];
            } else {
                importDBSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Restore Database", nil)
                                                            delegate:self
                                                   cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                              destructiveButtonTitle:nil
                                                   otherButtonTitles:[NSString stringWithFormat:NSLocalizedString(@"From %@", @"Choose backup source"), @"iTunes"], nil];
            }
            [importDBSheet showInView:self.view];
        } else if(indexPath.row == kRowBackupDatabase) {
            if([_internetReachable currentReachabilityStatus] != NotReachable) {
                exportDBSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Backup Database", nil)
                                                            delegate:self
                                                   cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                              destructiveButtonTitle:nil
                                                   otherButtonTitles:[NSString stringWithFormat:NSLocalizedString(@"To %@", @"Choose backup target"), @"iTunes"],
                                 [NSString stringWithFormat:NSLocalizedString(@"To %@", @"Choose backup target"), @"Dropbox"], nil];
            } else {
                exportDBSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Backup Database", nil)
                                                            delegate:self
                                                   cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                              destructiveButtonTitle:nil
                                                   otherButtonTitles:[NSString stringWithFormat:NSLocalizedString(@"To %@", @"Choose backup target"), @"iTunes"], nil];
            }
            
            [exportDBSheet showInView:self.view];
        } else if(indexPath.row == kRowLogoutDropbox) {
            [[DBSession sharedSession] unlinkAll];
            
            [self.table beginUpdates];
            [self.table deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            [self.table endUpdates];
        }
        [self.table deselectRowAtIndexPath:indexPath animated:YES];
    } else if(indexPath.section == kSectionTutorial) {
        TutorialListViewController *tutorialVC = [[TutorialListViewController alloc] init];
        tutorialVC.title = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;
        [self.navigationController pushViewController:tutorialVC animated:YES];
    } else if(indexPath.section == kSectionUserFeedback) {
        if(indexPath.row == kRowRateApp) {
            NSString *rateURL = @"itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=";
            // Here is the app id from itunesconnect
#ifdef _LITE_
            rateURL = [NSString stringWithFormat:@"%@489158369", rateURL]; 
#else
            rateURL = [NSString stringWithFormat:@"%@489145746", rateURL];
#endif
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:rateURL]];

            [self.table deselectRowAtIndexPath:indexPath animated:NO];
        } else if(indexPath.row == kRowReportBug) {
            NSMutableString *clientInfo = [NSMutableString string];
            [clientInfo appendFormat:@"App Bundle: %@\n", [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey]];
            [clientInfo appendFormat:@"Device: %@\n", [[UIDevice currentDevice] machine]];
            [clientInfo appendFormat:@"OS Version: %@ %@\n", [[UIDevice currentDevice] systemName], [[UIDevice currentDevice] systemVersion]];

            NSArray *languages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
            NSString *currentLanguage = [languages objectAtIndex:0];
            [clientInfo appendFormat:@"Language: %@\n", currentLanguage];
            
            NSLocale *locale = [NSLocale currentLocale];
            NSString *countryCode = [locale objectForKey: NSLocaleCountryCode];
//            NSString *countryName = [locale displayNameForKey: NSLocaleCountryCode value:countryCode];
            [clientInfo appendFormat:@"Location: %@\n", countryCode];
            
            [clientInfo appendFormat:@"%@\n============================\n", NSLocalizedString(@"Please describe the bug below the line", nil)];

#ifdef _LITE_
            [self _composeMailTo:@"bugreport@cctsai.tw" withSubject:@"[Bug Report/BuyRecordLite]" andBody:clientInfo];
#else
            [self _composeMailTo:@"bugreport@cctsai.tw" withSubject:@"[Bug Report/BuyRecord]" andBody:clientInfo];
#endif
        } else if(indexPath.row == kRowFillForm) {
            FeedbackViewController *feedbackVC = [[FeedbackViewController alloc] init];
            feedbackVC.title = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;
            feedbackVC.delegate = self;
            [self.navigationController pushViewController:feedbackVC animated:YES];
        }
    }
//    else if(indexPath.section == kSectionChangeBackground) {
//        [self _changeBackground];
//    }
}
//--------------------------------------------------------------
//  [END] UITableViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] IBActions
#pragma mark -
#pragma mark IBActions (include actions in table)
//--------------------------------------------------------------
- (IBAction)done:(id)sender
{
    [[DataBackupRestoreAgent sharedSingleton] cancelLastOperation];
    [self.delegate flipsideViewControllerDidFinish:self];
}

- (void)_barcodeVibrationChange:(UISwitch *)sender
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Barcode Setting"
                   withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:sender.on] forKey:@"Vibration"]];
    }

    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:kSettingVibrateBarcodeDetection];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)_barcodeSoundChange:(UISwitch *)sender
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Barcode Setting"
                   withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:sender.on] forKey:@"Sound"]];
    }

    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:kSettingSoundBarcodeDetection];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)_expiredChange:(UISwitch *)sender
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Notification Setting"
                   withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:sender.on] forKey:@"Alert Expired"]];
    }

    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:kSettingNotifyExpired];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [self.table beginUpdates];
    
    BOOL alertNearlyExpire = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingNotifyNearExpired];
    int nInserAnimation = UITableViewRowAnimationFade;
    int nDeleteAnimation = UITableViewRowAnimationTop;

    if(sender.on) { //Off -> On
        if(alertNearlyExpire) {
            //Do nothing
        } else {
            //Add time rows
            [self.table insertRowsAtIndexPaths:[NSArray arrayWithObject:
                                                [NSIndexPath indexPathForRow:kRowDailyNotifyTime inSection:kSectionExpiredNotification]]
                              withRowAnimation:nInserAnimation];
        }
    } else {    //On -> Off
        if(alertNearlyExpire) {
            //Do nothing
        } else {
            //Delete time row
            [self.table deleteRowsAtIndexPaths:[NSArray arrayWithObject:
                                                [NSIndexPath indexPathForRow:kRowDailyNotifyTime inSection:kSectionExpiredNotification]]
                              withRowAnimation:nDeleteAnimation];
        }
    }
    
    [self.table endUpdates];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kExpirePreferenceChangeNotification object:nil userInfo:nil];
}

- (void)_nearExpiredChange:(UISwitch *)sender
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Notification Setting"
                   withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:sender.on] forKey:@"Alert Near-Expired"]];
    }

    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:kSettingNotifyNearExpired];
    [[NSUserDefaults standardUserDefaults] synchronize];

    BOOL notifyExpired = [[NSUserDefaults standardUserDefaults] boolForKey:kSettingNotifyExpired];
    int nInserAnimation = UITableViewRowAnimationFade;
    int nDeleteAnimation = UITableViewRowAnimationTop;
    
    if(sender.on) { //Off -> On
        NSArray *insertRows = nil;
        //Add day row
        if(notifyExpired) {
            //Do nothing
        } else {
            //Add time row
            insertRows = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:kRowDailyNotifyTime inSection:kSectionExpiredNotification]];
        }
        
        [self.table insertRowsAtIndexPaths:insertRows withRowAnimation:nInserAnimation];
    } else {    //On -> Off
        NSArray *deleteRows = nil;
        if(notifyExpired) {
            //Delete day row
        } else {
            //Delete day and time row
            //Delete time row
            [self.table deleteRowsAtIndexPaths:[NSArray arrayWithObject:
                                                [NSIndexPath indexPathForRow:kRowDailyNotifyTime inSection:kSectionExpiredNotification]]
                              withRowAnimation:nDeleteAnimation];
        }
        
        [self.table deleteRowsAtIndexPaths:deleteRows withRowAnimation:nDeleteAnimation];
    }
    
    [self.table endUpdates];
    [[NSNotificationCenter defaultCenter] postNotificationName:kExpirePreferenceChangeNotification object:nil userInfo:nil];
}

#pragma mark -
#pragma mark SetNotificationTimeViewControllerDelegate
- (void)setNotificationHour:(int)hh minute:(int)mm
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Notification Setting"
                   withParameters:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:
                                                                       [NSNumber numberWithInt:hh],
                                                                       [NSNumber numberWithInt:mm], nil]
                                                              forKeys:[NSArray arrayWithObjects:
                                                                       @"Alert Hour", @"Alert Minute", nil]]];
    }

    UITableViewCell *cell = [self.table cellForRowAtIndexPath:
                             [NSIndexPath indexPathForRow:kRowDailyNotifyTime inSection:kSectionExpiredNotification]];
    cell.detailTextLabel.text = [TimeUtil stringFromHour:hh minute:mm];
}

- (void)_changeNotificationTime
{
    SetNotificationTimeViewController *setTimeVC = [[SetNotificationTimeViewController alloc] init];
    setTimeVC.delegate = self;
    [self.navigationController pushViewController:setTimeVC animated:YES];
}

- (void)_changeBackground
{
    //TODO: switch to background selector view controller
    UIImagePickerController *pickImageVC = [[UIImagePickerController alloc] init];
    pickImageVC.delegate = self;
    pickImageVC.allowsEditing = YES;
    pickImageVC.editing = YES;
    
    pickImageVC.mediaTypes = [NSArray arrayWithObject:(NSString *)kUTTypeImage];
//    [self.navigationController pushViewController:pickImageVC animated:YES];
    [self presentModalViewController:pickImageVC animated:YES];
    //TODO: The view controller provides preview with folders of background choosing
}

- (void)_allowAnalysisChange:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:kSettingAllowAnalysis];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if(sender.on) {
        [FlurryAnalytics startSession:kFlurryKey];
    }
    
    [FlurryAnalytics logEvent:@"Flurry Log Status"
               withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:sender.on]
                                                          forKey:@"Status"]];
}
//--------------------------------------------------------------
//  [END] IBActions
//==============================================================

//==============================================================
//  [BEGIN] UIImagePickerControllerDelegate
#pragma mark -
#pragma mark UIImagePickerControllerDelegate Methods
//--------------------------------------------------------------
- (void) imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissModalViewControllerAnimated:YES];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissModalViewControllerAnimated:YES];
    
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    if(CFStringCompare((__bridge CFStringRef)mediaType, kUTTypeImage, 0) == kCFCompareEqualTo) {
//        UIImage *editImage = [info objectForKey:UIImagePickerControllerEditedImage];
        CGRect cropRect;
        [[info objectForKey:UIImagePickerControllerCropRect] getValue:&cropRect];
        NSLog(@"Crop rect: (%.2f, %.2f) %.2fx%.2f", cropRect.origin.x, cropRect.origin.y, cropRect.size.width, cropRect.size.height);

//        dispatch_queue_t loadImageQueue = dispatch_queue_create("PrepareThumbImage", NULL);
//        dispatch_async(loadImageQueue, ^(void) {
//            //=========== This may take a while ===========
//            CGFloat previewSize = ([UIScreen isRetina]) ? self.previewImageView.frame.size.width*2 : self.previewImageView.frame.size.width;
//            UIImage *displayImage = [editImage thumbnailImage:previewSize
//                                            transparentBorder:0
//                                                 cornerRadius:0
//                                         interpolationQuality:kCGInterpolationHigh];
//            //=============================================
//            
//            dispatch_async(dispatch_get_main_queue(), ^(void) {
//                [spinner stopAnimating];
//                [spinner removeFromSuperview];
//                
//                if(displayImage != nil &&
//                   !self.previewImageView.hidden)
//                {
//                    self.previewImageView.image = displayImage;
//                    [self.previewImageView setNeedsLayout];
//                }
//            });
//        });
//        dispatch_release(loadImageQueue);
    }
}
//--------------------------------------------------------------
//  [END] UIImagePickerControllerDelegate
//==============================================================

- (void)_setDayCell:(UITableViewCell *)cell withDays:(int)days
{
    if(days == 1) {
        cell.detailTextLabel.text = NSLocalizedString(@"1 day", nil);
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%d days", nil), days];
    }
}

//==============================================================
//  [BEGIN] TutorialViewControllerDelegate
#pragma mark - TutorialViewControllerDelegate
//--------------------------------------------------------------
- (void)endTutorial
{
    [self.navigationController popViewControllerAnimated:YES];
}
//--------------------------------------------------------------
//  [END] TutorialViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] FeedbackViewControllerDelegate
#pragma mark - FeedbackViewControllerDelegate
//--------------------------------------------------------------
- (void)endFeedback
{
    [self.navigationController popViewControllerAnimated:YES];
}
//--------------------------------------------------------------
//  [END] FeedbackViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] UIActionSheetDelegate
#pragma mark - UIActionSheetDelegate
//--------------------------------------------------------------
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }

    if(actionSheet == importDBSheet) {
        _restoreSource = buttonIndex;
        
        if(buttonIndex == 0) {
            //Import from iTunes
            iTunesBackupFilePicker *filePicker = [[iTunesBackupFilePicker alloc] init];
            filePicker.delegate = self;
            [self.navigationController pushViewController:filePicker animated:YES];
        } else if(buttonIndex == 1) {
            //Import from dropbox
            _isBackup = NO;
            
            if([_internetReachable currentReachabilityStatus] == ReachableViaWWAN) {
                if(!_cellularNetworkAlert) {
                    _cellularNetworkAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Network Status", nil)
                                                                       message:NSLocalizedString(@"You're using cellular network.\n"
                                                                                                  "Wi-Fi is recommended.\n"
                                                                                                  "Continue?", nil)
                                                                      delegate:self
                                                             cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                             otherButtonTitles:NSLocalizedString(@"Continue", nil), nil];
                }
                
                [_cellularNetworkAlert show];
            } else {
                if (![[DBSession sharedSession] isLinked]) {
                    _loggingInDropbox = YES;
                    [[DBSession sharedSession] linkFromController:self];
                } else {
                    DropboxBackupFilePicker *filePicker = [DropboxBackupFilePicker new];
                    filePicker.delegate = self;
                    [self.navigationController pushViewController:filePicker animated:YES];
                }
            }
        }
    } else if(actionSheet == exportDBSheet) {
        if(buttonIndex == 0) {
            //Export to iTunes
            if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                [FlurryAnalytics logEvent:@"Backup Database" timed:YES];
            }
            
            self.navigationItem.rightBarButtonItem.enabled = NO;
            _hud.labelText = NSLocalizedString(@"Backup Database", nil);
            _hud.detailsLabelText = NSLocalizedString(@"Please wait", nil);
            [_hud show:YES];
            
            DataBackupRestoreAgent *backupAgent = [DataBackupRestoreAgent sharedSingleton];
            backupAgent.delegate = self;
            [backupAgent backupToiTunes];
        } else if(buttonIndex == 1) {
            //Export to dropbox
            _isBackup = YES;
            
            if([_internetReachable currentReachabilityStatus] == ReachableViaWWAN) {
                if(!_cellularNetworkAlert) {
                    _cellularNetworkAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Network Status", nil)
                                                                       message:NSLocalizedString(@"You're using cellular network.\n"
                                                                                                  "Wi-Fi is recommended.\n"
                                                                                                  "Continue?", nil)
                                                                      delegate:self
                                                             cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                             otherButtonTitles:NSLocalizedString(@"Continue", nil), nil];
                }
                
                [_cellularNetworkAlert show];
            } else {
                if (![[DBSession sharedSession] isLinked]) {
                    _loggingInDropbox = YES;
                    [[DBSession sharedSession] linkFromController:self];
                } else {
                    [self _backupToDropbox];
                }
            }
        }
    }
}
//--------------------------------------------------------------
//  [END] UIActionSheetDelegate
//==============================================================

//==============================================================
//  [BEGIN] DataBackupRestorerDelegate
#pragma mark - DataBackupRestorerDelegate
//--------------------------------------------------------------
- (void)finishBackupToiTunesWithName:(NSString *)backupFileName
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics endTimedEvent:@"Database Backup"
                        withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"IsSuccess"]];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        self.navigationItem.rightBarButtonItem.enabled = YES;
        [_hud hide:YES];
        
        UIAlertView *sucessAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Backup Successfully", nil)
                                                              message:[NSString stringWithFormat:
                                                                       NSLocalizedString(@"Saved to\n%@\nYou can copy the file in iTunes.", nil), 
                                                                       backupFileName]
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"Dismiss", nil)
                                                    otherButtonTitles:nil];
        [sucessAlert show];
    });
}

- (void)failToBackupWithError:(NSError *)error
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics endTimedEvent:@"Database Backup"
                        withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"IsSuccess"]];
    }
    
    [DataBackupRestoreAgent recoverFromLastFailOperation];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.navigationItem.rightBarButtonItem.enabled = YES;
        [_hud hide:NO];
        
        UIAlertView *failAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Backup Failed", nil)
                                                            message:nil
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"Dismiss", nil)
                                                  otherButtonTitles:nil];
        [failAlert show];
    });
}

- (void)finishRestore
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics endTimedEvent:@"Database Restore"
                        withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"IsSuccess"]];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [CoreDataDatabase renewMainMOC];
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kLastExpiryListShowTime];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        void(^finishBlock)() = ^{
            NSString *notifVersion = [[NSUserDefaults standardUserDefaults] stringForKey:kNotificationVersion];
            if([VersionCompare compareVersion:kCurrentNotificationVersion toVersion:notifVersion] != NSOrderedSame ||
               ![[NSUserDefaults standardUserDefaults] boolForKey:kHasScheduledNotifications])
            {
                [ExpiryNotificationScheduler rescheduleAllNotifications];   //Will refresh badge
            } else {
                [[UIApplication sharedApplication] refreshApplicationBadgeNumber];
            }
            
            [self.delegate databaseRestored];
            
            self.navigationItem.rightBarButtonItem.enabled = YES;
            [_hud hide:YES];
            
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kCurrentPage];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            UIAlertView *failAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Restore Successfully", nil)
                                                                message:[NSString stringWithFormat:NSLocalizedString(@"Restore from:\n%@", nil),
                                                                         _restoreFileName]
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"Dismiss", nil)
                                                      otherButtonTitles:nil];
            [failAlert show];
            
            BOOL showExpiryList = [self _shouldShowExpiryList];
            if(kSectionShowExpiryList < 0) {
               if(showExpiryList) {
                   //Add section
                   kSectionShowExpiryList = kSectionExpiredNotification + 1;
                   kSectionEditLocation++;
                   kSectionImportExport++;
                   kSectionTutorial++;
                   kSectionUserFeedback++;
//                    kSectionAnaysis++;
                   
                   [self.table beginUpdates];
                   [self.table insertSections:[NSIndexSet indexSetWithIndex:kSectionShowExpiryList]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
                   [self.table endUpdates];
               }
            } else {
                if(!showExpiryList) {
                    //Remove section
                    int nRemovedSection = kSectionShowExpiryList;
                    kSectionShowExpiryList = -1;
                    kSectionEditLocation--;
                    kSectionImportExport--;
                    kSectionTutorial--;
                    kSectionUserFeedback--;
//                    kSectionAnaysis--;
                    
                    [self.table beginUpdates];
                    [self.table deleteSections:[NSIndexSet indexSetWithIndex:nRemovedSection]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
                    [self.table endUpdates];
                }
            }
        };
        
        if([CoreDataDatabase needToUpgradeDatabase]) {
            _hud.labelText = NSLocalizedString(@"Upgrading Database", nil);
            _hud.detailsLabelText = NSLocalizedString(@"Please wait", nil);
            
            [CoreDataDatabase resetDatabase];
            
            dispatch_queue_t upgradeQueue = dispatch_queue_create("UpgradeDBQueue", NULL);
            dispatch_async(upgradeQueue, ^{
                [CoreDataDatabase upgradeDatabase];
                
                dispatch_async(dispatch_get_main_queue(), finishBlock);
            });
        } else {
            [CoreDataDatabase renewMainMOC];
            [ExpiryNotificationScheduler rescheduleAllNotifications];
            
            finishBlock();
        }
    });
}

- (void)failToRestoreWithError:(NSError *)error
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics endTimedEvent:@"Database Restore"
                        withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"IsSuccess"]];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [CoreDataDatabase renewMainMOC];
        
        self.navigationItem.rightBarButtonItem.enabled = YES;
        [_hud hide:NO];
        
        UIAlertView *failAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Restore Failed", nil)
                                                            message:nil
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"Dismiss", nil)
                                                  otherButtonTitles:nil];
        [failAlert show];
    });
}

- (void)progressUpdated:(int)progress
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _hud.detailsLabelText = [NSString stringWithFormat:@"%@...%d%%", NSLocalizedString(@"Please wait", nil), progress];
    });
}

- (void)readyToUploadFile:(NSString *)name fromPath:(NSString *)path
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _hud.labelText = [NSString stringWithFormat:NSLocalizedString(@"Uploading to %@", nil), @"Dropbox"];
        
        [self._restClient uploadFile:name toPath:@"/" withParentRev:nil fromPath:path];
    });
}
//--------------------------------------------------------------
//  [END] DataBackupRestorerDelegate
//==============================================================

//==============================================================
//  [BEGIN] BackupFilePickerDelegate
#pragma mark - BackupFilePickerDelegate
//--------------------------------------------------------------
- (void)selectBackupFile:(BackupFileProperty *)file
{
    [self.navigationController popToRootViewControllerAnimated:YES];
    
    if([file.name length] > 0) {
        _restoreFileName = file.name;
        
        _restoreConfirmAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Ready to Restore?", nil)
                                                          message:[NSString stringWithFormat:@"%@\n\n%@\n%@",
                                                                   NSLocalizedString(@">> All data will be replaced <<", nil),
                                                                   NSLocalizedString(@"Restore from: ", nil), file.name]
                                                         delegate:self
                                                cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                otherButtonTitles:NSLocalizedString(@"Restore", nil), nil];
        [_restoreConfirmAlert show];
    }
}
//--------------------------------------------------------------
//  [END] BackupFilePickerDelegate
//==============================================================

//==============================================================
//  [BEGIN] UIAlertViewDelegate
#pragma mark - UIAlertViewDelegate
//--------------------------------------------------------------
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == alertView.cancelButtonIndex) {
        return;
    }
    
    if(alertView == _restoreConfirmAlert) {
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
            [FlurryAnalytics logEvent:@"Restore Database" timed:YES];
        }

        self.navigationItem.rightBarButtonItem.enabled = NO;
        
        _hud.detailsLabelText = NSLocalizedString(@"Please wait", nil);
        
        if(_restoreSource == kRestoreFromiTunes) {
            _hud.labelText = NSLocalizedString(@"Restoring Database", nil);
            DataBackupRestoreAgent *restorer = [DataBackupRestoreAgent sharedSingleton];
            restorer.delegate = self;
            [restorer restoreFromiTunes:_restoreFileName];
        } else if(_restoreSource == kRestoreFromDropbox) {
            _hud.labelText = NSLocalizedString(@"Download from Dropbox", nil);
            [_hud show:YES];
            
            NSString *downloadPath = [StringUtil fullPathInTemp:_restoreFileName];
            if([[NSFileManager defaultManager] fileExistsAtPath:downloadPath]) {
                [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:nil];
            }
            
            NSString *srcName = ([_restoreFileName hasPrefix:@"/"]) ? _restoreFileName : [NSString stringWithFormat:@"/%@", _restoreFileName];
            [self._restClient loadFile:srcName atRev:nil intoPath:downloadPath];
        }
        
        [_hud show:YES];
    } else if(alertView == _backupConfirmAlert) {
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
            [FlurryAnalytics logEvent:@"Backup Database" timed:YES];
        }

        self.navigationItem.rightBarButtonItem.enabled = NO;
        _hud.labelText = NSLocalizedString(@"Backup Database", nil);
        _hud.detailsLabelText = NSLocalizedString(@"Please wait", nil);
        [_hud show:YES];
        
        DataBackupRestoreAgent *backupAgent = [DataBackupRestoreAgent sharedSingleton];
        backupAgent.delegate = self;
        [backupAgent backupToiTunes];
    } else if(alertView == _cellularNetworkAlert) {
        if (![[DBSession sharedSession] isLinked]) {
            _loggingInDropbox = YES;
            [[DBSession sharedSession] linkFromController:self];
        } else {
            if(_isBackup) {
                [self _backupToDropbox];
            } else {
                DropboxBackupFilePicker *filePicker = [DropboxBackupFilePicker new];
                filePicker.delegate = self;
                [self.navigationController pushViewController:filePicker animated:YES];
            }
        }
    }
}
//--------------------------------------------------------------
//  [END] UIAlertViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] Notification Receivers
#pragma mark - Notification Receivers
//--------------------------------------------------------------
- (void)_applicationWillResignActive
{
    [[DataBackupRestoreAgent sharedSingleton] cancelLastOperation];
}

- (void)_receiveNetworkChangeNotification:(NSNotification *)notification
{
    [self _checkNetworkStatus];
}

- (void)_checkNetworkStatus
{
    switch ([_internetReachable currentReachabilityStatus]) {
        case NotReachable:
        {
            NSLog(@"The internet is down.");
            _footerLabelForDatabaseSection.text = NSLocalizedString(@"No Internet Connection", nil);
            break;
        }
        case ReachableViaWiFi:
        {
            NSLog(@"The internet is working via WIFI.");
            _footerLabelForDatabaseSection.text = NSLocalizedString(@"Internet Connection via Wi-Fi", nil);
            break;
        }
        case ReachableViaWWAN:
        {
            NSLog(@"The internet is working via WWAN.");
            _footerLabelForDatabaseSection.text = NSLocalizedString(@"Internet Connection via Cellular Network", nil);
            break;
        }
    }
}

- (void)_receiveDidBecomeActiveNotification:(NSNotification *)notification
{
    if(_loggingInDropbox) {
        _loggingInDropbox = NO;
        
        if ([[DBSession sharedSession] isLinked]) {
            [self.table beginUpdates];
            [self.table reloadSections:[NSIndexSet indexSetWithIndex:kSectionImportExport] withRowAnimation:UITableViewRowAnimationAutomatic];
            [self.table endUpdates];
            
            if(_isBackup) {
                [self _backupToDropbox];
            } else {
                DropboxBackupFilePicker *filePicker = [DropboxBackupFilePicker new];
                filePicker.delegate = self;
                [self.navigationController pushViewController:filePicker animated:NO];
            }
        }
    }
}
//--------------------------------------------------------------
//  [END] Notification Receivers
//==============================================================

- (void)_composeMailTo:(NSString *)receiver withSubject:(NSString *)subject andBody:(NSString *)body
{
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
	picker.mailComposeDelegate = self;
	
	[picker setSubject:subject];
    
	// Set up recipients
	NSArray *toRecipients = [NSArray arrayWithObject:receiver]; 
//	NSArray *ccRecipients = [NSArray arrayWithObjects:@"second@example.com", @"third@example.com", nil]; 
//	NSArray *bccRecipients = [NSArray arrayWithObject:@"fourth@example.com"]; 
	
	[picker setToRecipients:toRecipients];
//	[picker setCcRecipients:ccRecipients];	
//	[picker setBccRecipients:bccRecipients];
	
	// Attach an image to the email
//	NSString *path = [[NSBundle mainBundle] pathForResource:@"rainy" ofType:@"png"];
//    NSData *myData = [NSData dataWithContentsOfFile:path];
//	[picker addAttachmentData:myData mimeType:@"image/png" fileName:@"rainy"];
	
	// Fill out the email body text
//	NSString *emailBody = @"It is raining in sunny California!";
	[picker setMessageBody:body isHTML:NO];
	
	[self presentModalViewController:picker animated:YES];
}

//==============================================================
//  [BEGIN] MFMailComposeViewControllerDelegate
#pragma mark - MFMailComposeViewControllerDelegate
//--------------------------------------------------------------
- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error 
{	
	// Notifies users about errors associated with the interface
	switch (result)
	{
		case MFMailComposeResultCancelled:

			break;
		case MFMailComposeResultSaved:

			break;
		case MFMailComposeResultSent:

			break;
		case MFMailComposeResultFailed:

			break;
		default:

			break;
	}

	[self dismissModalViewControllerAnimated:YES];
}
//--------------------------------------------------------------
//  [END] MFMailComposeViewControllerDelegate
//==============================================================

- (BOOL)_shouldShowExpiryList
{
    int nExpiredCount = [CoreDataDatabase totalExpiredItemsBeforeAndIncludeDate:[TimeUtil today]];
    BOOL showExpiryList = (nExpiredCount > 0);
    
    if(!showExpiryList) {
        DBNotifyDate *notifyDate = [CoreDataDatabase getNotifyDateOfDate:[TimeUtil today]];
        
        for(DBFolderItem *item in notifyDate.expireItems) {
            if(!item.isArchived &&
               item.count > 0)
            {
                showExpiryList = YES;
                break;
            }
        }
        
        if(!showExpiryList) {
            for(DBFolderItem *item in notifyDate.nearExpireItems) {
                if(!item.isArchived &&
                   item.count > 0)
                {
                    showExpiryList = YES;
                    break;
                }
            }
        }
    }
    
    return showExpiryList;
}

//==============================================================
//  [BEGIN] ExpiryListViewControllerDelegate
#pragma mark - ExpiryListViewControllerDelegate
//--------------------------------------------------------------
- (void)expiryListShouldDismiss
{
    [self.navigationController popViewControllerAnimated:YES];
    if(![self _shouldShowExpiryList]) {
        int nRemovedSection = kSectionShowExpiryList;
        //All items are archived remove section
        kSectionShowExpiryList = -1;
        kSectionEditLocation--;
        kSectionImportExport--;
        kSectionTutorial--;
        kSectionUserFeedback--;
//        kSectionAnaysis--;
        
        [self.table beginUpdates];
        [self.table deleteSections:[NSIndexSet indexSetWithIndex:nRemovedSection]
                  withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.table endUpdates];
    }
}
//--------------------------------------------------------------
//  [END] ExpiryListViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] Dropbox
#pragma mark - Dropbox
//--------------------------------------------------------------
- (DBRestClient *)_restClient
{
    if (!_restClient) {
        _restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        _restClient.delegate = self;
    }
    
    return _restClient;
}

//Upload to Dropbox
- (void)_backupToDropbox
{
    self.navigationItem.rightBarButtonItem.enabled = NO;
    _hud.labelText = NSLocalizedString(@"Backup Database", nil);
    _hud.detailsLabelText = NSLocalizedString(@"Please wait", nil);
    [_hud show:YES];
    
    DataBackupRestoreAgent *backupAgent = [DataBackupRestoreAgent sharedSingleton];
    backupAgent.delegate = self;
    [backupAgent backupToDropbox];
}

- (void)restClient:(DBRestClient *)client uploadProgress:(CGFloat)progress forFile:(NSString *)destPath from:(NSString *)srcPath
{
    _hud.detailsLabelText = [NSString stringWithFormat:@"%@...%d%%", NSLocalizedString(@"Please wait", nil), (int)(progress*100.0f)];
}

- (void)restClient:(DBRestClient*)client uploadedFile:(NSString*)destPath
              from:(NSString*)srcPath metadata:(DBMetadata*)metadata
{
    
    NSLog(@"File uploaded successfully to path: %@", metadata.path);
    
    [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupRestoreOperation];
    [[NSUserDefaults standardUserDefaults] setValue:nil forKey:kLastBackupFileInProcess];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics endTimedEvent:@"Database Backup"
                        withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"IsSuccess"]];
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:srcPath error:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.navigationItem.rightBarButtonItem.enabled = YES;
        [_hud hide:YES];
        
        NSString *fileName = ([destPath hasPrefix:@"/"]) ? [destPath substringFromIndex:1] : destPath;
        UIAlertView *sucessAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Backup Successfully", nil)
                                                              message:[NSString stringWithFormat:
                                                                       NSLocalizedString(@"Save\n%@\nto Dropbox.", nil),
                                                                       fileName]
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"Dismiss", nil)
                                                    otherButtonTitles:nil];
        [sucessAlert show];
    });
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error
{
    NSLog(@"File upload failed with error - %@", error);
    [self failToBackupWithError:error];
}

//Restoring from Dropbox
- (void)restClient:(DBRestClient *)client loadProgress:(CGFloat)progress forFile:(NSString *)destPath
{
    _hud.detailsLabelText = [NSString stringWithFormat:@"%@...%d%%", NSLocalizedString(@"Please wait", nil), (int)(progress*100.0f)];
}

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)localPath {
    NSLog(@"File loaded into path: %@", localPath);
    _hud.labelText = NSLocalizedString(@"Restoring Database", nil);
    _hud.detailsLabelText = NSLocalizedString(@"Please wait", nil);
    
    DataBackupRestoreAgent *restorer = [DataBackupRestoreAgent sharedSingleton];
    restorer.delegate = self;
    [restorer restoreFromPath:localPath];
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error {
    NSLog(@"There was an error loading the file - %@", error);
    [_hud hide:YES];
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Dropbox Error"
                                                        message:@"Cannot get file from Dropbox"
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Dismiss", nil)
                                              otherButtonTitles:nil];
    [alertView show];
}
//--------------------------------------------------------------
//  [END] Dropbox
//==============================================================
@end
