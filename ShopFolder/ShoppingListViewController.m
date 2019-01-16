//
//  ShoppingListViewController.m
//  ShopFolder
//
//  Created by Michael Tsai on 2012/04/11.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "ShoppingListViewController.h"
#import "CoreDataDatabase.h"
#import "StringUtil.h"
#import "NotificationConstant.h"
#import "LiteLimitations.h"
#import "ShoppingListComposer.h"
#import <QuartzCore/QuartzCore.h>
#import "FlurryAnalytics.h"
#import "PreferenceConstant.h"
#import "UIImage+Resize.h"
#import "UIImage+RoundedCorner.h"
#import "ImageParameters.h"
#import "UIView+ConverToImage.h"
#import "DBItemBasicInfo+SetAdnGet.h"
#import "ColorConstant.h"

#define kDeleteAllItems     0
#define kDeleteBoughtItems  1

#define kShareByEMail       0
#define kShareBySMS         1
#define kShareByFacebook    2

#define kMessageLabelHeight 20.0f

#define kItemNameLabelHeight    60.0f

#define kCountTextModeShowBought    0
#define kCountTextModeShowNotBought 1

@interface ShoppingItemData : NSObject
{
    UIImage *image;
    PriceStatistics *priceStatistics;
    int stock;
}

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) PriceStatistics *priceStatistics;
@property (nonatomic, assign) int stock;

@end

@implementation ShoppingItemData
@synthesize image;
@synthesize priceStatistics;
@synthesize stock;
@end

@interface ShoppingListViewController ()
- (void)_toggleEditMode:(id)sender;
- (void)_addButtonPressed:(id)sender;

- (void)_updateUIStatusByList;
- (void)_receiveShoppingItemChangeNotification:(UILocalNotification *)notif;
- (void)_receiveShoppingItemSaveNotification:(UILocalNotification *)notif;

//- (void)_loadImagesOfVisibleRows;

- (void)_composeMailTo:(NSString *)name
                 email:(NSString *)mailAddress
               subject:(NSString *)mailSubject
               content:(HTMLEmailHolder *)mailContent
                isHTML:(BOOL)html;
- (void)_composeSMSTo:(NSString *)phoneNumber body:(NSString *)smsBody;

- (void)_showMessage:(NSString *)message;

- (void)_tapOnLargeImagePreview:(UITapGestureRecognizer *)sender;

- (ShoppingItemData *)_updateShoppingItemData:(DBShoppingItem *)item;
- (void)_updateCell:(ShoppingListCell *)cell withShoppingItem:(DBShoppingItem *)shoppingItem;

- (void)_updateShoppingItemFromNotification;
@end

@implementation ShoppingListViewController
@synthesize table;
@synthesize toolbar;
@synthesize shareButton;
@synthesize countText;
@synthesize deleteButton;
@synthesize shoppingListDelegate;

- (void)_initInCommon
{
    // Custom initialization
    _itemToDataMap = [NSMutableDictionary dictionary];
    _shoppingList = [CoreDataDatabase getShoppingList];
    _boughtList = [NSMutableArray array];
    for(DBShoppingItem *item in _shoppingList) {
        if(item.hasBought) {
            [_boughtList addObject:item];
        }
    }
    
    _shareType = -1;
    
    //Precache
    [MFMailComposeViewController class];
    [MFMessageComposeViewController class];
    
    _currencyFormatter = [[NSNumberFormatter alloc] init];
    _currencyFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
    _currencyFormatter.minimumFractionDigits = 0;
    [_currencyFormatter setLenient:YES];
    
    _updatedShoppingItems = [NSMutableSet set];
}

- (id)initWithSuperViewController:(UIViewController *)vc
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _superViewController = vc;
        [self _initInCommon];
    }
    
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        [self _initInCommon];
    }
    return self;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    _editButton = nil;
    _addButton = nil;
    _doneButton = nil;

    self.table = nil;
    self.toolbar = nil;
    self.shareButton = nil;
    self.countText = nil;
    self.deleteButton = nil;
    
    _hud.delegate = nil;
    [_hud hide:NO];
    _hud = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSManagedObjectContextObjectsDidChangeNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSManagedObjectContextDidSaveNotification
                                                  object:nil];
    
    _messageLabel = nil;
    
    _largeImageView = nil;
    _largeImageBackgroundView = nil;
    _imageForNoImageLabel = nil;
    _imageLabelBackgroundView = nil;
    _imageLabel = nil;
    _tapToDismissLabel = nil;
    
    [_itemToDataMap removeAllObjects];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.title = NSLocalizedString(@"Shopping List", nil);
    self.table.rowHeight = kImageHeight;
    self.navigationController.navigationBar.tintColor = [UIColor colorWithHue:0.08 saturation:0.9f brightness:1.0f alpha:1.0f];
    self.toolbar.tintColor = self.navigationController.navigationBar.tintColor;
    _countTextMode = [[NSUserDefaults standardUserDefaults] integerForKey:kShoppingListCountTextMode];
    
    _hud = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
    _hud.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25f];
    _hud.removeFromSuperViewOnHide = NO;
    _hud.delegate = self;
    [self.navigationController.view addSubview:_hud];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_receiveShoppingItemChangeNotification:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_receiveShoppingItemSaveNotification:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:nil];
    
    _editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                target:self
                                                                action:@selector(_toggleEditMode:)];
    _addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                               target:self
                                                               action:@selector(_addButtonPressed:)];
    
    self.navigationItem.leftBarButtonItem = _editButton;
    self.navigationItem.rightBarButtonItem = _addButton;
    self.navigationItem.leftBarButtonItem.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = YES;
    [self _updateUIStatusByList];
    
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 372.0f, 320.0f, 0.001f)];
    _messageLabel.textColor = [UIColor blackColor];
    _messageLabel.backgroundColor = [UIColor colorWithRed:1.0f green:1.0f blue:0.7f alpha:0.9f];
    _messageLabel.font = [UIFont systemFontOfSize:16.0f];
    _messageLabel.textAlignment = UITextAlignmentCenter;
    
    int nViewPos = [[self.view subviews] indexOfObject:self.table];
    [self.view insertSubview:_messageLabel atIndex:nViewPos+1];

    for(DBShoppingItem *item in _shoppingList) {
        [self _updateShoppingItemData:item];
    }
    
    [self.table reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    isAddingNewItemInShoppingList = NO;
    
    if(_shareType == -1) {
        [_hud hide:NO];
        [[NSNotificationCenter defaultCenter] postNotificationName:kEnablePageScrollNotification object:nil];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _editShoppingItem = nil;
    
    if(_shareType == kShareByEMail) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDisablePageScrollNotification object:nil];
        dispatch_queue_t composeMailQueue = dispatch_queue_create("ComposeMailQueue", NULL);
        dispatch_async(composeMailQueue, ^{
            NSDate *beginTime = [NSDate date];
            ShoppingListComposer *composer = [[ShoppingListComposer alloc] initWithShoppingList:_shoppingList];
            HTMLEmailHolder *mailContent = [composer transformToHTML];

            NSTimeInterval ellapsedTime = [[NSDate date] timeIntervalSinceDate:beginTime];
            if(ellapsedTime < 0.5f) {
                [NSThread sleepForTimeInterval:0.5f-ellapsedTime];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self _composeMailTo:_receiverName
                               email:_receiverMailAddress
                             subject:NSLocalizedString(@"Shopping List", nil)
                             content:mailContent
                              isHTML:mailContent.isHTML];
            });
        });
        dispatch_release(composeMailQueue);
    } else if(_shareType == kShareBySMS) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDisablePageScrollNotification object:nil];
        
        dispatch_queue_t composeSMSQueue = dispatch_queue_create("ComposeSMSQueue", NULL);
        dispatch_async(composeSMSQueue, ^{
            [NSThread sleepForTimeInterval:0.5f];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self _composeSMSTo:_receiverPhoneNumber body:_composedSMSMessage];
            });
        });
        dispatch_release(composeSMSQueue);
    }

    _shareType = -1;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

//==============================================================
//  [BEGIN] IBActions
#pragma mark - IBActions
//--------------------------------------------------------------
- (IBAction)shareButtonPressed:(id)sender
{
    _shareType = -1;
    if([MFMessageComposeViewController canSendText]) {
        _askForSharingSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Share Shopping List Using:", nil)
                                                          delegate:self
                                                 cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                            destructiveButtonTitle:nil
                                                 otherButtonTitles:NSLocalizedString(@"Email", nil),
                                                                   NSLocalizedString(@"SMS", nil), nil];
    } else {
        _askForSharingSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Share Shopping List Using:", nil)
                                                          delegate:self
                                                 cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                            destructiveButtonTitle:nil
                                                 otherButtonTitles:NSLocalizedString(@"Email", nil), nil];
    }
    
    [_askForSharingSheet showInView:self.view];
}

- (IBAction)deleteButtonPressed:(id)sender
{
    if([_boughtList count] > 0) {
        _askForDeletionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Remove Shopping Items", nil)
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:NSLocalizedString(@"Remove All Items", nil),
                                                                    NSLocalizedString(@"Remove Bought Items", nil), nil];
    } else {
        _askForDeletionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Remove Shopping Items", nil)
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:NSLocalizedString(@"Remove All Items", nil), nil];
    }
    
    [_askForDeletionSheet showInView:self.view];
}

- (IBAction)changeCountTextMode:(id)sender
{
    if(_countTextMode == kCountTextModeShowBought) {
        _countTextMode = kCountTextModeShowNotBought;
    } else {
        _countTextMode = kCountTextModeShowBought;
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:_countTextMode forKey:kShoppingListCountTextMode];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self _updateUIStatusByList];
}
//--------------------------------------------------------------
//  [END] IBActions
//==============================================================

//==============================================================
//  [BEGIN] UIActionSheetDelegate
#pragma mark - UIActionSheetDelegate
//--------------------------------------------------------------
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if(actionSheet.cancelButtonIndex == buttonIndex) {
        return;
    }
    
    if(actionSheet == _askForDeletionSheet) {
        _deleteType = buttonIndex;
        
        if(!_confirmDeletionSheet) {
            _confirmDeletionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Confirm Removal", nil)
                                                                delegate:self
                                                       cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                  destructiveButtonTitle:NSLocalizedString(@"Remove Items", nil)
                                                       otherButtonTitles:nil];
        }
        
        [_confirmDeletionSheet showInView:self.view];
    } else if(actionSheet == _confirmDeletionSheet) {
        [FlurryAnalytics logEvent:@"Remove shopping items"
                   withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:_deleteType] forKey:@"Delete type"]];

        [[NSNotificationCenter defaultCenter] postNotificationName:kDisablePageScrollNotification object:nil];
        
        DBShoppingItem *item;
        if(_deleteType == kDeleteAllItems) {
            for(int nIndex = [_shoppingList count] - 1; nIndex >= 0; nIndex--) {
                item = [_shoppingList objectAtIndex:nIndex];
                [CoreDataDatabase removeShoppingItem:item updatePositionOfRestItems:NO];
            }
        } else {
            for(int nIndex = [_shoppingList count] - 1; nIndex >= 0; nIndex--) {
                item = [_shoppingList objectAtIndex:nIndex];
                if(item.hasBought) {
                    [CoreDataDatabase removeShoppingItem:item updatePositionOfRestItems:YES];
                }
            }
        }
        [_boughtList removeAllObjects];
        
        [CoreDataDatabase commitChanges:nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kEnablePageScrollNotification object:nil];
    } else if(actionSheet == _askForSharingSheet) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDisablePageScrollNotification object:nil];
        _shareType = buttonIndex;

        [FlurryAnalytics logEvent:@"Share shopping items"
                   withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:buttonIndex] forKey:@"Share type"]];

        if(buttonIndex == kShareByEMail) {
            ABPeoplePickerNavigationController *selectPersonVC = [[ABPeoplePickerNavigationController alloc] init];
            selectPersonVC.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;
            [selectPersonVC setDisplayedProperties:[NSArray arrayWithObjects:
                                                    [NSNumber numberWithInt:kABPersonEmailProperty],
                                                    [NSNumber numberWithInt:kABPersonNicknameProperty], nil]];
            selectPersonVC.peoplePickerDelegate = self;
            [_superViewController presentViewController:selectPersonVC
                                               animated:YES
                                             completion:NULL];
        } else if(buttonIndex == kShareBySMS) {
            ShoppingListComposer *composer = [[ShoppingListComposer alloc] initWithShoppingList:_shoppingList];
            _composedSMSMessage = [composer transformToSMS];
            
            if([_composedSMSMessage length] == 0) {
                [self _showMessage:NSLocalizedString(@"No shopping item has a name.", nil)];
                [_hud hide:YES];
            } else {
                ABPeoplePickerNavigationController *selectPersonVC = [[ABPeoplePickerNavigationController alloc] init];
                selectPersonVC.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;
                [selectPersonVC setDisplayedProperties:[NSArray arrayWithObject:[NSNumber numberWithInt:kABPersonPhoneProperty]]];
                selectPersonVC.peoplePickerDelegate = self;
                [_superViewController presentViewController:selectPersonVC
                                                   animated:YES
                                                 completion:NULL];
            }
        }
    }
}
//--------------------------------------------------------------
//  [END] UIActionSheetDelegate
//==============================================================

//==============================================================
//  [BEGIN] ABPeoplePickerNavigationControllerDelegate
#pragma mark - ABPeoplePickerNavigationControllerDelegate
//--------------------------------------------------------------
- (void)_composeMailTo:(NSString *)name
                 email:(NSString *)mailAddress
               subject:(NSString *)mailSubject
               content:(HTMLEmailHolder *)mailContent
                isHTML:(BOOL)html
{
    NSString *receiver = nil;
    if([mailAddress length] > 0) {
        if([name length] > 0) {
            receiver = [NSString stringWithFormat:@"%40@ <%@>", name, mailAddress];
        } else {
            receiver = mailAddress;
        }
    }

    NSArray *toRecipients = (receiver) ? [NSArray arrayWithObject:receiver] : nil;
    
    MFMailComposeViewController *sendMailVC = [[MFMailComposeViewController alloc] init];
    sendMailVC.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;
    sendMailVC.mailComposeDelegate = self;
    [sendMailVC setToRecipients:toRecipients];
    [sendMailVC setSubject:mailSubject];
    [sendMailVC setMessageBody:mailContent.mailBody isHTML:html];
    
    for(HTMLAttachedData *data in mailContent.attachedDataList) {
        [sendMailVC addAttachmentData:data.content mimeType:data.mimeType fileName:data.cid];
    }

    [_superViewController presentViewController:sendMailVC
                                       animated:YES
                                     completion:NULL];
}

- (void)_composeSMSTo:(NSString *)phoneNumber body:(NSString *)smsBody
{
    if([smsBody length] == 0) {
        [self _showMessage:NSLocalizedString(@"No shopping item has a name.", nil)];
        [_hud hide:YES];
        return;
    }

    NSArray *toRecipients = (phoneNumber) ? [NSArray arrayWithObject:phoneNumber] : nil;
    
    MFMessageComposeViewController *sendSMSVC = [[MFMessageComposeViewController alloc] init];
    sendSMSVC.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;
    sendSMSVC.messageComposeDelegate = self;
    [sendSMSVC setRecipients:toRecipients];
    sendSMSVC.body = smsBody;
    [_superViewController presentViewController:sendSMSVC
                                       animated:YES
                                     completion:NULL];
}

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker
{
    if(_shareType == kShareByEMail) {
        _receiverName = nil;
        _receiverMailAddress = nil;
    } else if(_shareType == kShareBySMS) {
        _receiverPhoneNumber = nil;
    }

    [_hud show:NO];
    [_superViewController dismissViewControllerAnimated:YES completion:NULL];
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person
{
    //User just selects a person
    return YES;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
    [_hud show:NO];
    [_superViewController dismissViewControllerAnimated:YES completion:NULL];
    
    //User select detail column of a person
    if(_shareType == kShareByEMail) {
        _receiverName = nil;
        _receiverMailAddress = nil;
        if(property == kABPersonEmailProperty) {
            ABMultiValueRef emailAddresses = ABRecordCopyValue(person, kABPersonEmailProperty);
            _receiverMailAddress = nil;
            if(ABMultiValueGetCount(emailAddresses) > 0) {
                _receiverMailAddress = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(emailAddresses, 0);
            }
            CFRelease(emailAddresses);
            _receiverName = (__bridge_transfer NSString *)ABRecordCopyCompositeName(person);
        }
    } else if(_shareType == kShareBySMS) {
        _receiverPhoneNumber = nil;
        if(property == kABPersonPhoneProperty) {
            ABMultiValueRef phoneNumbers = ABRecordCopyValue(person, kABPersonPhoneProperty);
            if(ABMultiValueGetCount(phoneNumbers) > 0) {
                _receiverPhoneNumber = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(phoneNumbers, 0);
            }
            CFRelease(phoneNumbers);
        }
    }

    return NO;  //return YES will bring build-in apps
}
//--------------------------------------------------------------
//  [END] ABPeoplePickerNavigationControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] MFMailComposeViewControllerDelegate
#pragma mark - MFMailComposeViewControllerDelegate
//--------------------------------------------------------------
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    // Notifies users about errors associated with the interface
	switch (result)
	{
		case MFMailComposeResultCancelled:
//            [self _showMessage:NSLocalizedString(@"Mail cancelled.", nil)];
            [FlurryAnalytics logEvent:@"Mail shopping items"
                       withParameters:[NSDictionary dictionaryWithObject:@"Cancelled" forKey:@"Result"]];
			break;
		case MFMailComposeResultSaved:
//            [self _showMessage:NSLocalizedString(@"Mail draft saved.", nil)];
            [FlurryAnalytics logEvent:@"Mail shopping items"
                       withParameters:[NSDictionary dictionaryWithObject:@"Saved" forKey:@"Result"]];
			break;
		case MFMailComposeResultSent:
            [self _showMessage:NSLocalizedString(@"Sending email...", nil)];
            [FlurryAnalytics logEvent:@"Mail shopping items"
                       withParameters:[NSDictionary dictionaryWithObject:@"Success" forKey:@"Result"]];
			break;
		case MFMailComposeResultFailed:
            [self _showMessage:NSLocalizedString(@"Failed to send email.", nil)];
            [FlurryAnalytics logEvent:@"Mail shopping items"
                       withParameters:[NSDictionary dictionaryWithObject:@"Failed" forKey:@"Result"]];
			break;
		default:
            
			break;
	}
    
	[_superViewController dismissViewControllerAnimated:YES completion:NULL];
}
//--------------------------------------------------------------
//  [END] MFMailComposeViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] MFMessageComposeViewControllerDelegate
#pragma mark - MFMessageComposeViewControllerDelegate
//--------------------------------------------------------------
- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    switch (result)
	{
		case MessageComposeResultCancelled:
//            [self _showMessage:NSLocalizedString(@"SMS cancelled.", nil)];
            [FlurryAnalytics logEvent:@"SMS shopping items"
                       withParameters:[NSDictionary dictionaryWithObject:@"Cancelled" forKey:@"Result"]];
			break;
		case MessageComposeResultSent:
            [self _showMessage:NSLocalizedString(@"Sending SMS...", nil)];
            [FlurryAnalytics logEvent:@"SMS shopping items"
                       withParameters:[NSDictionary dictionaryWithObject:@"Success" forKey:@"Result"]];
			break;
		case MessageComposeResultFailed:
            [self _showMessage:NSLocalizedString(@"Failed to send SMS.", nil)];
            [FlurryAnalytics logEvent:@"SMS shopping items"
                       withParameters:[NSDictionary dictionaryWithObject:@"Failed" forKey:@"Result"]];
			break;
		default:
            
			break;
	}

    [_superViewController dismissViewControllerAnimated:YES completion:NULL];
}
//--------------------------------------------------------------
//  [END] MFMessageComposeViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] UITableViewDelegate
#pragma mark - UITableViewDelegate
//--------------------------------------------------------------
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    ShoppingListCell *cell = (ShoppingListCell *)[tableView cellForRowAtIndexPath:indexPath];
    DBShoppingItem *item = [_shoppingList objectAtIndex:indexPath.row];
    item.hasBought = !item.hasBought;
    
    if(![CoreDataDatabase commitChanges:nil]) {
        [CoreDataDatabase cancelUnsavedChanges];
    }

    //Scroll to show whole cell
    CGRect frame = [cell convertRect:cell.bounds toView:tableView];
    [tableView scrollRectToVisible:frame animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kShoppingItemCellHeight;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kDisablePageScrollNotification object:nil];
    _editShoppingItem = [_shoppingList objectAtIndex:indexPath.row];
    EditShoppingItemViewController *editVC = [[EditShoppingItemViewController alloc] initForEditingShoppingItem:_editShoppingItem];
    editVC.delegate = self;
    [self.navigationController pushViewController:editVC animated:YES];
}
//--------------------------------------------------------------
//  [END] UITableViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] UITableViewDataSource
#pragma mark - UITableViewDataSource
//--------------------------------------------------------------
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellTableIdentitifier = @"ShoppingListCell";
    ShoppingListCell *cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
    if(cell == nil) {
        cell = [[ShoppingListCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellTableIdentitifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
        cell.delegate = self;
    }
    
    DBShoppingItem *shoppingItem = [_shoppingList objectAtIndex:indexPath.row];
    [self _updateCell:cell withShoppingItem:shoppingItem];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_shoppingList count];
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    //Since this view controller is inside a scroll view,
    //therefore we cannot swipe to delete the item
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(tableView.editing) {
        return UITableViewCellEditingStyleDelete;
    }

    return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(editingStyle == UITableViewCellEditingStyleDelete) {
        DBShoppingItem *item = [_shoppingList objectAtIndex:indexPath.row];
        [CoreDataDatabase removeShoppingItem:item updatePositionOfRestItems:YES];
        [CoreDataDatabase commitChanges:nil];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    if(sourceIndexPath.row == destinationIndexPath.row) {
        return;
    }
    
    DBShoppingItem *movedItem = [_shoppingList objectAtIndex:sourceIndexPath.row];
    [CoreDataDatabase moveShoppingItem:movedItem to:destinationIndexPath.row];
    [CoreDataDatabase commitChanges:nil];

    //Sync position
    [_shoppingList removeObject:movedItem];
    [_shoppingList insertObject:movedItem atIndex:destinationIndexPath.row];
}
//--------------------------------------------------------------
//  [END] UITableViewDataSource
//==============================================================

//==============================================================
//  [BEGIN] MBProgressHUDDelegate
#pragma mark - MBProgressHUDDelegate
//--------------------------------------------------------------
- (void)hudWasHidden
{
}
//--------------------------------------------------------------
//  [END] MBProgressHUDDelegate
//==============================================================

//==============================================================
//  [BEGIN] ShoppingListCellDelegate
#pragma mark - ShoppingListCellDelegate
//--------------------------------------------------------------
- (void)shoppingItemCountChanged:(ShoppingListCell *)cell newCount:(int)count
{
    NSIndexPath *cellIndex = [self.table indexPathForCell:cell];
    if(cellIndex.row >= [_shoppingList count]) {
        [FlurryAnalytics logEvent:@"Error: Index exceeds _shoppingList size in shoppingItemCountChanged"];
        return;
    }

    DBShoppingItem *item = [_shoppingList objectAtIndex:cellIndex.row];
    item.count = count;
    if(![CoreDataDatabase commitChanges:nil]) {
        [CoreDataDatabase cancelUnsavedChanges];
    }
}

- (void)boughtStatusChanged:(ShoppingListCell *)cell bought:(BOOL)hasBought
{
    NSIndexPath *cellIndex = [self.table indexPathForCell:cell];
    if(cellIndex.row >= [_shoppingList count]) {
        [FlurryAnalytics logEvent:@"Error: Index exceeds _shoppingList size in boughtStatusChanged"];
        return;
    }

    DBShoppingItem *item = [_shoppingList objectAtIndex:cellIndex.row];
    item.hasBought = hasBought;
    if(![CoreDataDatabase commitChanges:nil]) {
        [CoreDataDatabase cancelUnsavedChanges];
    }
}

- (void)imageTouched:(ShoppingListCell *)cell
{
    NSIndexPath *indexPath = [self.table indexPathForCell:cell];
    DBFolderItem *item = [_shoppingList objectAtIndex:indexPath.row];
    DBItemBasicInfo *basicInfo = item.basicInfo;
    if([basicInfo getDisplayImage] == nil) {
        return;
    }
    
    [self.table scrollRectToVisible:[cell convertRect:cell.bounds toView:self.table] animated:YES];
    
    CGRect cellFrame = [cell convertRect:cell.bounds toView:[self.table superview]];
    
    //Get visible position related to table view
    CGRect cellImageFrame = [cell convertRect:cell.imageViewFrame toView:[self.table superview]];
    _imageAnimateFromFrame = cellImageFrame;
    
    //Calculate from and to frames
    CGFloat targetSize = [UIScreen mainScreen].bounds.size.width - kSpaceToImage * 2.0f;
    CGRect toFrame = CGRectMake(cell.imageViewFrame.origin.x, cell.imageViewFrame.origin.y, targetSize, targetSize);
    if(cellFrame.origin.y + cellFrame.size.height > self.table.frame.size.height) {
        //Cell exceeds bottom of table
        toFrame.origin.y = self.table.frame.size.height - targetSize;
    } else if(cellImageFrame.origin.y >= cell.imageViewFrame.origin.y) {
        //Cell is wholly visible
        if(cellImageFrame.origin.y < self.table.frame.size.height - targetSize) {
            //The image can enlarge at the original position
            toFrame.origin.y = cellImageFrame.origin.y;
        } else {
            //After enlarge, the iamge may exceed bottom
            toFrame.origin.y = self.table.frame.size.height - targetSize;
        }
    }
    
    //Prepare the view to cover table view
    if(!_largeImageBackgroundView) {
        _largeImageBackgroundView = [[UIControl alloc] initWithFrame:self.table.frame];
        _largeImageBackgroundView.userInteractionEnabled = YES;
        
        UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tapOnLargeImagePreview:)];
        [_largeImageBackgroundView addGestureRecognizer:tapGR];
    }
    _largeImageBackgroundView.hidden = NO;
    _largeImageBackgroundView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_largeImageBackgroundView];
    
    //Prepare "tap to return" label to show on the top of preview image
    if(!_tapToDismissLabel) {
        _tapToDismissLabel = [[OutlineLabel alloc] initWithFrame:CGRectMake(0, 0, targetSize, 50)];
        _tapToDismissLabel.textColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
        _tapToDismissLabel.backgroundColor = kLargeImageLabelBackgroundColor;
        _tapToDismissLabel.font = [UIFont systemFontOfSize:23.0f];
        _tapToDismissLabel.textAlignment = UITextAlignmentCenter;
        _tapToDismissLabel.contentMode = UIViewContentModeCenter;
        _tapToDismissLabel.text = NSLocalizedString(@"Tap To Narrow Down", nil);
    }
    _tapToDismissLabel.hidden = NO;
    
    //Prepare bottom label area to show item's name
    if(!_imageLabelBackgroundView) {
        _imageLabelBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, targetSize-kItemNameLabelHeight,
                                                                             targetSize, kItemNameLabelHeight)];
        _imageLabelBackgroundView.backgroundColor = kLargeImageLabelBackgroundColor;
    }
    
    if(!_imageLabel) {
        _imageLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 0, 240, _imageLabelBackgroundView.frame.size.height)];
        _imageLabel.backgroundColor = [UIColor clearColor];
        _imageLabel.textColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
        _imageLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
        _imageLabel.font = [UIFont boldSystemFontOfSize:21.0f];
        _imageLabel.numberOfLines = 2;
        _imageLabel.textAlignment = UITextAlignmentCenter;
        _imageLabel.contentMode = UIViewContentModeCenter;
        [_imageLabelBackgroundView addSubview:_imageLabel];
    }
    
    if([basicInfo.name length] == 0) {
        _imageLabelBackgroundView.hidden = YES;
    } else {
        _imageLabelBackgroundView.hidden = NO;
        _imageLabel.text = basicInfo.name;
    }
    
    //Prepare preview image view
    if(_largeImageView == nil) {
        _largeImageView = [[UIImageView alloc] initWithFrame:CGRectMake(kSpaceToImage, kSpaceToImage, targetSize, targetSize)];
        _largeImageView.layer.borderWidth = 1.0f;
        _largeImageView.layer.cornerRadius = 10.0f;
        _largeImageView.layer.borderColor = [UIColor colorWithWhite:0.67 alpha:0.75f].CGColor;
        _largeImageView.layer.masksToBounds = YES;
        [_largeImageBackgroundView addSubview:_largeImageView];
        
        [_largeImageView addSubview:_tapToDismissLabel];
        [_largeImageView addSubview:_imageLabelBackgroundView];
    }
    
    _largeImageView.alpha = 1.0f;
    _largeImageView.image = [basicInfo getDisplayImage];
    _largeImageView.frame = _imageAnimateFromFrame;
    
    _tapToDismissLabel.alpha = 0.0f;
    _imageLabelBackgroundView.alpha = 0.0f;
    
    [UIView animateWithDuration:0.001f
                     animations:^{
                         //We're doing this because system will cache last animation direction
                         _largeImageView.frame = _imageAnimateFromFrame;
                         
                         //Prepare for narrow down
                         if(cellFrame.origin.y + cellFrame.size.height > self.table.frame.size.height) {
                             //Cell exceeds bottom of table
                             _imageAnimateFromFrame = CGRectMake(cellImageFrame.origin.x,
                                                                 self.table.frame.size.height-cellFrame.size.height+cell.imageViewFrame.origin.y,
                                                                 kImageWidth, kImageHeight);
                         } else if(cellImageFrame.origin.y < cell.imageViewFrame.origin.y) {
                             //Cell exceeds top of the table
                             _imageAnimateFromFrame = cell.imageViewFrame;
                         } else {
                             //Cell is wholly visible
                             _imageAnimateFromFrame = CGRectMake(cellImageFrame.origin.x, cellImageFrame.origin.y,
                                                                 kImageWidth, kImageHeight);
                         }
                     } completion:^(BOOL finished) {
                         if(finished) {
                             //Animate to enlarge image
                             [UIView animateWithDuration:0.3f
                                                   delay:0.0f
                                                 options:UIViewAnimationCurveEaseIn|UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction
                                              animations:^{
                                                  _largeImageBackgroundView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
                                                  _largeImageView.frame = toFrame;
                                              } completion:^(BOOL finished) {
                                                  if(finished) {
                                                      //Show image labels
                                                      [UIView animateWithDuration:0.1f
                                                                            delay:0
                                                                          options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionCurveEaseIn
                                                                       animations:^{
                                                                           _tapToDismissLabel.alpha = 1.0f;
                                                                           _imageLabelBackgroundView.alpha = 1.0f;
                                                                       } completion:^(BOOL finished) {
                                                                           
                                                                       }];
                                                  }
                                              }];
                         }
                     }];
    
    self.navigationItem.leftBarButtonItem.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.shareButton.enabled = NO;
    self.deleteButton.enabled = NO;
    self.countText.enabled = NO;
}
//--------------------------------------------------------------
//  [END] ShoppingListCellDelegate
//==============================================================

//==============================================================
//  [BEGIN] EditShoppingItemViewControllerDelegate
#pragma mark - EditShoppingItemViewControllerDelegate
//--------------------------------------------------------------
- (void)cancelEditingShoppingItem
{
    [_superViewController dismissViewControllerAnimated:YES completion:NULL];
}

- (void)finishEditingShoppingItem:(DBShoppingItem *)shoppingItem
{
    isAddingNewItemInShoppingList = NO;
    if(!shoppingItem.hasBought) {
        [_boughtList removeObject:shoppingItem];
    }

    [self _updateShoppingItemData:shoppingItem];
    [_superViewController dismissViewControllerAnimated:YES completion:NULL];

    [self.table beginUpdates];
    int nIndex = [_shoppingList indexOfObject:shoppingItem];
    if(nIndex == NSNotFound) {
        [_shoppingList insertObject:shoppingItem atIndex:0];
        [self.table insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        [self.table reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:nIndex inSection:0]]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
    [self.table endUpdates];
    [self _updateUIStatusByList];
}

- (void)shoppingItemWillBeginToMove:(DBShoppingItem *)shoppingItem
{
    [self.shoppingListDelegate shoppingItemBeginsToMove:shoppingItem];
}

//--------------------------------------------------------------
//  [END] EditShoppingItemViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] UIAlertViewDelegate
#pragma mark - UIAlertViewDelegate
//--------------------------------------------------------------
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == alertView.cancelButtonIndex) {
        return;
    }

#ifdef _LITE_
    if(alertView == _liteLimitAlert) {
        if(buttonIndex == 1) {
            InAppPurchaseViewController *iapVC = [[InAppPurchaseViewController alloc] init];
            iapVC.delegate = self;
            [self presentModalViewController:iapVC animated:YES];
        }
    }
#endif
}
//--------------------------------------------------------------
//  [END] UIAlertViewDelegate
//==============================================================

- (void)leaveEditingShoppingItemAnimated:(BOOL)animate
{
    [self.navigationController popViewControllerAnimated:animate];
}

#ifdef _LITE_
//==============================================================
//  [BEGIN] InAppPurchaseViewControllerDelegate
#pragma mark - InAppPurchaseViewControllerDelegate
//--------------------------------------------------------------
- (void)finishIAP
{
    [self dismissModalViewControllerAnimated:YES];
}
//--------------------------------------------------------------
//  [END] InAppPurchaseViewControllerDelegate
//==============================================================
#endif

//==============================================================
//  [BEGIN] Private Methods
#pragma mark - Private Methods
//--------------------------------------------------------------
- (void)_toggleEditMode:(id)sender
{
    if(self.table.editing) {
        self.navigationItem.leftBarButtonItem = _editButton;
    } else {
        if(!_doneButton) {
            _doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                        target:self
                                                                        action:@selector(_toggleEditMode:)];
        }
        self.navigationItem.leftBarButtonItem = _doneButton;
    }
    
    [self.table setEditing:!self.table.editing animated:YES];
}

- (void)_addButtonPressed:(id)sender
{
#ifdef _LITE_
    BOOL isUnlimit = [[NSUserDefaults standardUserDefaults] boolForKey:kPurchaseUnlimitCount];
    if(!isUnlimit &&
       [CoreDataDatabase totalShoppingItems] >= kLimitShoppingItems)
    {
        _liteLimitAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Limited Shopping Item Count", nil)
                                                            message:NSLocalizedString(@"Would you like to remove the limitation?", nil)
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"No, thanks", nil)
                                                  otherButtonTitles:NSLocalizedString(@"Yes", nil), nil];
        [_liteLimitAlert show];
        return;
    }
#endif

    [[NSNotificationCenter defaultCenter] postNotificationName:kDisablePageScrollNotification object:nil];
    isAddingNewItemInShoppingList = YES;
    
    EditShoppingItemViewController *editVC = [[EditShoppingItemViewController alloc] init];
    editVC.delegate = self;
    UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:editVC];
    navCon.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;
    [_superViewController presentViewController:navCon
                                       animated:YES
                                     completion:NULL];
}

- (void)_updateUIStatusByList
{
    if([_shoppingList count] > 0) {
        _noItemLabel.hidden = YES;
        _editButton.enabled = YES;
        self.shareButton.enabled = YES;
        self.deleteButton.enabled = YES;
        self.table.hidden = NO;
        self.table.alpha = 1.0f;
        
        self.countText.enabled = YES;
        if(_countTextMode == kCountTextModeShowBought) {
            if([_boughtList count] == [_shoppingList count]) {
                self.countText.title = NSLocalizedString(@"All Bought", nil);
            } else if([_boughtList count] == 0) {
                self.countText.title = NSLocalizedString(@"None Bought", nil);
            } else {
                self.countText.title = [NSString stringWithFormat:@"%d/%d %@",
                                        [_boughtList count],
                                        [_shoppingList count],
                                        NSLocalizedString(@"Bought", nil)];
            }
        } else {
            if([_boughtList count] == [_shoppingList count]) {
                self.countText.title = NSLocalizedString(@"None Not Bought", nil);
            } else if([_boughtList count] == 0) {
                self.countText.title = NSLocalizedString(@"All Not Bought", nil);
            } else {
                self.countText.title = [NSString stringWithFormat:@"%d/%d %@",
                                        [_shoppingList count]-[_boughtList count],
                                        [_shoppingList count],
                                        NSLocalizedString(@"Not Bought", nil)];
            }
        }
    } else {
        _editButton.enabled = NO;
        if(self.table.editing) {
            [self.table setEditing:NO animated:NO];
            self.navigationItem.leftBarButtonItem = _editButton;
        }

        self.shareButton.enabled = NO;
        self.deleteButton.enabled = NO;
        self.countText.enabled = NO;
        self.countText.title = nil;

        if(!_noItemLabel) {
            _noItemLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 50, 300, 44)];
            _noItemLabel.textAlignment = UITextAlignmentCenter;
            _noItemLabel.contentMode = UIViewContentModeCenter;
            _noItemLabel.font = [UIFont boldSystemFontOfSize:20.0f];
            _noItemLabel.lineBreakMode = UILineBreakModeWordWrap;
            _noItemLabel.backgroundColor = [UIColor clearColor];
            _noItemLabel.numberOfLines = 2;
            _noItemLabel.text = NSLocalizedString(@"No shopping item.", nil);
            [self.view addSubview:_noItemLabel];
        }
        _noItemLabel.hidden = NO;
        _noItemLabel.alpha = 0.0f;
        
        [UIView animateWithDuration:0.3f
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             self.table.alpha = 0.0f;
                             _noItemLabel.alpha = 1.0f;
                         } completion:^(BOOL finished) {
                             self.table.hidden = YES;
                             self.table.alpha = 1.0f;
                         }];
    }
}

- (void)_reloadShoppingList
{
    //The returned list has been sorted by listPosition
    _shoppingList = [CoreDataDatabase getShoppingList];
    
    DBShoppingItem *shoppingItem;
    for(int nIndex = [_shoppingList count]-1; nIndex >= 0; nIndex--) {
        shoppingItem = [_shoppingList objectAtIndex:nIndex];
        if(nIndex != shoppingItem.listPosition) {
            shoppingItem.listPosition = nIndex;
            [CoreDataDatabase commitChanges:nil];
        }
    }
    
    [_boughtList removeAllObjects];
    for(DBShoppingItem *shoppingItem in _shoppingList) {
        if(shoppingItem.hasBought) {
            [_boughtList addObject:shoppingItem];
        }
        
        [self _updateShoppingItemData:shoppingItem];
    }
    
    self.navigationItem.rightBarButtonItem.enabled = YES;
    [self _updateUIStatusByList];
    [self.table reloadData];
}

- (void)_updateShoppingItemFromNotification
{
    @synchronized(_updatedShoppingItems) {
        [_updatedShoppingItems enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
            DBShoppingItem *shoppingItem = (DBShoppingItem *)obj;
            int nIndex = [_shoppingList indexOfObject:shoppingItem];
            if(nIndex != NSNotFound) {
                [self _updateShoppingItemData:shoppingItem];
                
                ShoppingListCell *cell = (ShoppingListCell *)[self.table cellForRowAtIndexPath:
                                                              [NSIndexPath indexPathForRow:nIndex
                                                                                 inSection:0]];
                [self _updateCell:cell withShoppingItem:shoppingItem];
            }
        }];
        
        [_updatedShoppingItems removeAllObjects];
    }
}

- (void)_receiveShoppingItemChangeNotification:(UILocalNotification *)notif
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateShoppingItemFromNotification) object:nil];
    
    NSDictionary *userInfo = notif.userInfo;
    DBShoppingItem *shoppingItem;
    DBItemBasicInfo *basicInfo;
    DBFolderItem *folderItem;
    BOOL needUpdateUI = NO;
    
    NSSet *deletedObjects = [userInfo objectForKey:NSDeletedObjectsKey];
    for(NSManagedObject *object in deletedObjects) {
        if([object class] == [DBShoppingItem class]) {
            shoppingItem = (DBShoppingItem *)object;
            int nIndex = [_shoppingList indexOfObject:shoppingItem];
            if(nIndex != NSNotFound) {
                [self.table beginUpdates];
                [_shoppingList removeObject:shoppingItem];
                [self.table deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:nIndex inSection:0]]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
                [self.table endUpdates];
                
                if(_editShoppingItem == shoppingItem) {
                    _editShoppingItem = nil;
                    [self.navigationController popToRootViewControllerAnimated:YES];
                }
                needUpdateUI = YES;
            }
        } else if([object class] == [DBFolderItem class]) {
            folderItem = (DBFolderItem *)object;
            if((folderItem.count > 0 ||
                folderItem.price != 0.0f) &&
                folderItem.basicInfo.shoppingItem)
            {
                shoppingItem = folderItem.basicInfo.shoppingItem;
                if(shoppingItem) {
                    [_updatedShoppingItems addObject:shoppingItem];
                }
            }
        }
    }
    
    NSSet *updatedObjects = [userInfo objectForKey:NSUpdatedObjectsKey];
    for(NSManagedObject *object in updatedObjects) {
        if([object class] == [DBShoppingItem class]) {
            shoppingItem = (DBShoppingItem *)object;
            if(shoppingItem) {
                [_updatedShoppingItems addObject:shoppingItem];
            }
        } else if([object class] == [DBItemBasicInfo class]) {
            basicInfo = (DBItemBasicInfo *)object;
            shoppingItem = basicInfo.shoppingItem;
            if(shoppingItem) {
                [_updatedShoppingItems addObject:shoppingItem];
            }
        } else if([object class] == [DBFolderItem class]) {
            folderItem = (DBFolderItem *)object;
            shoppingItem = folderItem.basicInfo.shoppingItem;
            if(shoppingItem) {
                [_updatedShoppingItems addObject:shoppingItem];
            }
        }
    }
    
    [self performSelector:@selector(_updateShoppingItemFromNotification) withObject:nil afterDelay:0.1f];
    
    if(needUpdateUI) {
        [self _updateUIStatusByList];
    }
}

- (void)_receiveShoppingItemSaveNotification:(UILocalNotification *)notif
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateShoppingItemFromNotification) object:nil];
    
    NSDictionary *userInfo = notif.userInfo;
    DBShoppingItem *shoppingItem = nil;
    BOOL needUpdateUI = NO;
    
    NSSet *insertedObjects = [userInfo objectForKey:NSInsertedObjectsKey];
    for(NSManagedObject *object in insertedObjects) {
        if([object class] != [DBShoppingItem class] ||
           isAddingNewItemInShoppingList)
        {
            continue;
        }
        
        //Only handle when user presses cart button to add shopping item
        shoppingItem = (DBShoppingItem *)object;
        [self.table beginUpdates];
        [self _updateShoppingItemData:shoppingItem];
        
        //Always append shopping item at the end of list
        const int SHOPPINGLIST_COUNT = [_shoppingList count];
        if(SHOPPINGLIST_COUNT != shoppingItem.listPosition) {
            shoppingItem.listPosition = SHOPPINGLIST_COUNT;
        }
        
        [_shoppingList insertObject:shoppingItem atIndex:shoppingItem.listPosition];
        [self.table insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:shoppingItem.listPosition inSection:0]]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.table endUpdates];
        
        needUpdateUI = YES;
    }
    
    //Since we won't get changeValues here, so we detect basicInfo change in _receiveShoppingItemChangeNotification
    NSSet *updatedObjects = [userInfo objectForKey:NSUpdatedObjectsKey];
    for(NSManagedObject *object in updatedObjects) {
        if([object class] == [DBShoppingItem class]) {
            shoppingItem = (DBShoppingItem *)object;
            int nIndex = [_shoppingList indexOfObject:object];
            if(nIndex != NSNotFound) {
                [_updatedShoppingItems addObject:shoppingItem];
                
                if(shoppingItem.hasBought) {
                    if(![_boughtList containsObject:shoppingItem]) {
                        [_boughtList addObject:shoppingItem];
                    }
                } else {
                    [_boughtList removeObject:shoppingItem];
                }
                needUpdateUI = YES;
            }
        } else if([object class] == [DBFolderItem class]) {
            shoppingItem = ((DBFolderItem *)object).basicInfo.shoppingItem;
            if(shoppingItem) {
                [_updatedShoppingItems addObject:shoppingItem];
            }
        }
    }
    
    [self performSelector:@selector(_updateShoppingItemFromNotification) withObject:nil afterDelay:0.1f];
    
    if(needUpdateUI) {
        [self _updateUIStatusByList];
    }
}

- (void)_showMessage:(NSString *)message
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_hideMessage) object:nil];

    _messageLabel.text = message;
    [UIView animateWithDuration:0.3f
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         _messageLabel.frame = CGRectMake(0, 372.0f-kMessageLabelHeight, 320.0f, kMessageLabelHeight);
                     } completion:^(BOOL finished) {
                         if(finished) {
                             [UIView animateWithDuration:0.75f
                                                   delay:2.0f
                                                 options:UIViewAnimationOptionAllowUserInteraction |
                                                         UIViewAnimationOptionBeginFromCurrentState |
                                                         UIViewAnimationOptionCurveEaseOut
                                              animations:^{
                                                  _messageLabel.frame = CGRectMake(0, 372.0f, 320.0f, kMessageLabelHeight);
                                              } completion:^(BOOL finished) {
                                              }];
                         }
                     }];
}

- (void)_tapOnLargeImagePreview:(UITapGestureRecognizer *)sender
{
    [self dismissImagePreviewAnimated:YES];
}

- (void)dismissImagePreviewAnimated:(BOOL)animate
{
    _tapToDismissLabel.hidden = YES;
    _imageLabelBackgroundView.hidden = YES;

    void(^animateBlock)() = ^{
        _largeImageBackgroundView.backgroundColor = [UIColor clearColor];
        _largeImageView.frame = _imageAnimateFromFrame;
    };
    
    void(^finishBlock)(BOOL finished) = ^(BOOL finished) {
        [_largeImageBackgroundView removeFromSuperview];
        self.table.scrollEnabled = YES;
        
        self.navigationItem.rightBarButtonItem.enabled = YES;
        [self _updateUIStatusByList];
    };
    
    if(animate) {
        [UIView animateWithDuration:0.3
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionBeginFromCurrentState
                         animations:animateBlock
                         completion:finishBlock];
    } else {
        animateBlock();
        finishBlock(YES);
    }
}

- (ShoppingItemData *)_updateShoppingItemData:(DBShoppingItem *)item
{
    ShoppingItemData *data = [_itemToDataMap objectForKey:item.objectID];
    if(data == nil) {
        data = [ShoppingItemData new];
        [_itemToDataMap setObject:data forKey:item.objectID];
    }
    
    data.stock = [CoreDataDatabase stockOfBasicInfo:item.basicInfo];
    data.priceStatistics = [CoreDataDatabase getPriceStatisticsOfBasicInfo:item.basicInfo];
    
    UIImage *resizedImage = [[item.basicInfo getDisplayImage] resizedImage:CGSizeMake(kImageWidth<<1, kImageHeight<<1)
                                                      interpolationQuality:kCGInterpolationHigh];
    data.image = [resizedImage roundedCornerImage:18 borderSize:1];
    
    return data;
}

//Caller should update ShoppingItemData first if needed
- (void)_updateCell:(ShoppingListCell *)cell withShoppingItem:(DBShoppingItem *)shoppingItem
{
    cell.name = shoppingItem.basicInfo.name;
    cell.barcode = shoppingItem.basicInfo.barcode;
    cell.count = shoppingItem.count;
    cell.price = shoppingItem.price;
    cell.hasBought = shoppingItem.hasBought;

    ShoppingItemData *data = [_itemToDataMap objectForKey:shoppingItem.objectID];
    cell.priceStatistics = data.priceStatistics;
    cell.stock = data.stock;
    cell.thumbImage = data.image;
    
    [cell updateUI];
}
//--------------------------------------------------------------
//  [END] Private Methods
//==============================================================
@end
