//
//  ShopFolderViewController.h
//  ShopFolder
//
//  Created by Michael on 2011/09/07.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "FolderPageViewController.h"
#import "EditFolderViewController.h"
#import "EditItemViewController.h"
#import "ClickOnFolderDelegate.h"
#import "NewFolderItemSwitcher.h"
//#import "ZBarReaderViewController.h"
#import "BarcodeScannerViewController.h"
#import "SearchLabel.h"
#import "WEPopoverController.h"
#import "AppSettingViewController.h"
#import "MBProgressHUD.h"
#import "EnterTextViewController.h"
#import "TutorialViewController.h"
#import "ShoppingListViewController.h"
#import "DBShoppingItem.h"
#import "ExpiryListViewController.h"
#import "FavoriteListViewController.h"

#ifdef _LITE_
//#import "AdWhirlView.h"
//#import "AdWhirlDelegateProtocol.h"
#endif
#import "InAppPurchaseViewController.h"

#define kMoveToRightPage @"MoveToRightPage"
#define kMoveToLeftPage @"MoveToLeftPage"

@interface ShopFolderViewController : UIViewController <UIScrollViewDelegate, UIGestureRecognizerDelegate,
                                                        UIImagePickerControllerDelegate, UINavigationControllerDelegate, 
                                                        UIAlertViewDelegate,
                                                        EditFolderViewControllerDelegate, EditItemViewControllerDelegate,
                                                        ClickOnFolderDelegate, FolderEditModeDelegate, ZBarReaderDelegate,
                                                        BarcodeScanDelegate,
                                                        InAppPurchaseViewControllerDelegate, ExpiryListViewControllerDelegate,
//#ifdef _LITE_
//                                                        AdWhirlDelegate,
//#endif
                                                        AppSettingViewControllerDelegate, MBProgressHUDDelegate,
                                                        EnterTextViewControllerDelegate, TutorialViewControllerDelegate,
                                                        ShoppingListViewControllerDelegate,
                                                        FavoriteListViewControllerDelegate>
{
    UITableViewCell *_previewCell;  //shows when user enter name or barcode

    OutlineLabel *_moveTitleForPreviewImage;
    CAGradientLayer *_itemMoveGradientLayer;    //inside previewImageView
    OutlineLabel *_moveItemNameLabel;    //inside previewImageView when move items
    OutlineLabel *_moveItemCountLabel;   //inside previewImageView when move items, below _moveItemNameLabel

    BOOL dragScrollViewToScroll;    // To be used when scrolls originate from the UIPageControl
    NSMutableArray *pageVCs;
    
    FolderPageViewController *_currentPageVC;

    NSString *movePageDirection;
    BOOL temporaryAddingPage;
    BOOL putItemIntoFolder;
    
    UIView *itemListView;
    NewFolderItemSwitcher *editFolderItemSwitcher;
    
    //Since views may be unload when low memory, we have to cache data
    int _inputType;
    UIImage *_inputImage;   //Need to keep this for showing preview image in _initAfterViewDiDLoad
//    DBFolderItem *_inputItem;
    DBItemBasicInfo *_inputBasicInfo;
    DBShoppingItem *_shoppingItem;
    BOOL _canSearch;

//#ifdef _LITE_
//    AdWhirlView *adView;
//    UILabel *loadADLabel;
//    BOOL m_isADRemoved;
//#endif
    BOOL m_isUnlimited;
    
    UILabel *popoverLabel;
    WEPopoverController *_popoverView;
    CGRect searchArea;
    BOOL prepareToShowSearchPopover;
    
    UIPopoverController *flipsidePopoverController;
    
    UIAlertView *_deleteFolderAlertView;
    MBProgressHUD *_hud;
    DBFolder *deleteFolder;
    FolderView *deleteFolderView;
    
    BOOL hasRearCam;
    
    NSMutableArray *_moveDataList;  //Array of SelectedFolderItem
    
    NSMutableArray *_candidateFolders;
    
    UINavigationController *shoppingListNavCon;
    ShoppingListViewController *_shoppingListVC;
    
    BOOL isViewMoved;
    BOOL shouldMoveViews;
    UIView *centerView;
    
    CGPoint originCenterViewPos; //could be inputView or previewView
    CGPoint originPageControlPos;
    CGPoint originInfoButtonPos;
    CGPoint originFavoriteButtonPos;
#ifdef _LITE_
    CGPoint originPurchaseButtonPos;
#endif

    BOOL isMovingItem;
    
    BOOL _refreshFolderImagesEnabled;
    
    BOOL _viewDidUnload;
    BOOL _viewDidDisappear; //for showing expiry list in this view controller
}

@property (nonatomic, strong) IBOutlet UIView *centerInputView;
@property (nonatomic, strong) IBOutlet UIButton *scanBarcodeButton;
@property (nonatomic, strong) IBOutlet UIButton *takePhotoButton;
@property (nonatomic, strong) IBOutlet UIButton *pickImageButton;
@property (nonatomic, strong) IBOutlet UIButton *enterTextButton;

@property (nonatomic, strong) IBOutlet UIView *previewTextView;
@property (nonatomic, strong) IBOutlet UIImageView *previewImageView;

@property (nonatomic, strong) IBOutlet UIScrollView *pageScrollView;
@property (nonatomic, strong) IBOutlet UIPageControl *pageControl;
@property (nonatomic, strong) IBOutlet UIButton *infoButton;
@property (nonatomic, strong) IBOutlet UIButton *purchaseButton;
@property (strong, nonatomic) IBOutlet UIButton *favoriteButton;

@property (nonatomic, strong) NSMutableArray *pageVCs;

//#ifdef _LITE_
//@property (nonatomic, strong) AdWhirlView *adView;
//@property (nonatomic, strong) IBOutlet UILabel *loadADLabel;
//#endif

@property (nonatomic, strong) IBOutlet SearchLabel *searchLabel;

@property (nonatomic, strong) UIPopoverController *flipsidePopoverController;   //For iPad if available

- (void)reloadPages;
- (BOOL)movePage: (NSString *)moveDirection;
- (void)movePageContinuously: (NSString *)moveDirection;

- (IBAction)changePage:(id)sender;
- (IBAction)scanBarcode:(UIButton *)sender;
- (IBAction)takePhoto: (UIButton *)sender;
- (IBAction)pickImage: (UIButton *)sender;
- (IBAction)enterText:(UIButton *)sender;
- (IBAction)showInfo:(id)sender;
- (IBAction)purchasePressed:(id)sender;
- (IBAction)favoriteButtonPressed:(id)sender;

- (BOOL)shouldShowExpiryList;
- (void)showExpireListAnimated:(BOOL)animate;
@end
