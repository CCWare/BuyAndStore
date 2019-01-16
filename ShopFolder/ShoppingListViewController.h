//
//  ShoppingListViewController.h
//  ShopFolder
//
//  Created by Michael Tsai on 2012/04/11.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"
#import "ShoppingListCell.h"
#import "EditShoppingItemViewController.h"
#import <MessageUI/MessageUI.h>
#import <AddressBookUI/AddressBookUI.h>
#import "OutlineLabel.h"

#ifdef _LITE_
#import "InAppPurchaseViewController.h"
#endif

@protocol ShoppingListViewControllerDelegate;

@interface ShoppingListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate,
                                                          MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate,
                                                          ABPeoplePickerNavigationControllerDelegate, UIAlertViewDelegate,
                                                          MBProgressHUDDelegate, ShoppingListCellDelegate,
                                                          EditShoppingItemViewControllerDelegate
#ifdef _LITE_
                                                          ,InAppPurchaseViewControllerDelegate
#endif
                                                          >
{
    UIBarButtonItem *_editButton;
    UIBarButtonItem *_addButton;
    UIBarButtonItem *_doneButton;

    MBProgressHUD *_hud;
    UILabel *_noItemLabel;
    
    NSMutableArray *_shoppingList;
    NSMutableArray *_boughtList;
    
    BOOL isAddingNewItemInShoppingList;
    
    UIActionSheet *_askForSharingSheet;
    UIActionSheet *_askForDeletionSheet;
    UIActionSheet *_confirmDeletionSheet;
    int _deleteType;
    __block int _shareType;
    
    UILabel *_messageLabel;
    NSString *_receiverName;
    NSString *_receiverMailAddress;
    NSString *_receiverPhoneNumber;
    NSString *_composedSMSMessage;
    
    UIViewController *_superViewController;
    
    //For large image preview
    UIImageView *_largeImageView;
    UIControl *_largeImageBackgroundView;
    UIImage *_imageForNoImageLabel;
    UIView *_imageLabelBackgroundView;
    UILabel *_imageLabel;
    OutlineLabel *_tapToDismissLabel;

    CGRect _imageAnimateFromFrame;
    
    int _countTextMode; //%d/%d bought/unbought
    
    NSNumberFormatter *_currencyFormatter;
#ifdef _LITE_
    UIAlertView *_liteLimitAlert;
#endif
    
    NSMutableDictionary *_itemToDataMap;    //shoppingItem.objectID -> ShoppingItemData
    DBShoppingItem *_editShoppingItem;
    NSMutableSet *_updatedShoppingItems;
}

@property (nonatomic, strong) IBOutlet UITableView *table;

@property (nonatomic, strong) IBOutlet UIToolbar *toolbar;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *shareButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *countText;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *deleteButton;
@property (nonatomic, weak) id<ShoppingListViewControllerDelegate> shoppingListDelegate;

- (id)initWithSuperViewController:(UIViewController *)vc;   //for present modal views

- (IBAction)shareButtonPressed:(id)sender;
- (IBAction)deleteButtonPressed:(id)sender;
- (IBAction)changeCountTextMode:(id)sender;

- (void)leaveEditingShoppingItemAnimated:(BOOL)animate;
- (void)dismissImagePreviewAnimated:(BOOL)animate;
@end

@protocol ShoppingListViewControllerDelegate
- (void)shoppingItemBeginsToMove:(DBShoppingItem *)shoppingItem;
@end
