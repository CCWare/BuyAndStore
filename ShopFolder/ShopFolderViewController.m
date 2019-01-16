//
//  ShopFolderViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/09/07.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "ShopFolderViewController.h"
#import "CoreDataDatabase.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "UIImage+Resize.h"
#import "UIScreen+RetinaDetection.h"
#import "ZBarReaderView.h"
#import <AudioToolbox/AudioToolbox.h>   //For AudioServicesPlaySystemSound
#import "StringUtil.h"
#import "NSString+TruncateToSize.h"
#import "NotificationConstant.h"
#import "TimeUtil.h"
#import "UIApplication+BadgeUpdate.h"
#import "PreferenceConstant.h"
#import "HardwareUtil.h"
#import "ExpiryNotificationScheduler.h"
#import "VersionCompare.h"
#import "DataBackupRestoreAgent.h"
#import "NSString+TruncateToSize.h"
#import "FlurryAnalytics.h"
#import "ImageParameters.h"

#import "DBItemBasicInfo+SetAdnGet.h"
#import "DBFolderItem+ChangeLog.h"
#import "DBFolderItem+expiryOperations.h"
#import "DBFolder+isEmpty.h"
#import "DBFolder+SetAndGet.h"
#import "NSManagedObject+DeepCopy.h"
#import "SearchListViewController.h"
#import "ListSearchResultsViewController.h"
#import "UIImage+Resize.h"
#import "UIImage+RoundedCorner.h"

#import "SelectedFolderItem.h"

#import "FolderListViewController.h"

#import "ExpiryListViewController.h"

#ifdef _LITE_
#import "LiteLimitations.h"
#endif

#define kMovePageDelay (0.75f)
#define kMinHUDShowingTime 0.7f
#define kCenterViewEditAlpha 0.3f

#define kItemMoveViewBackgroundColor [UIColor colorWithWhite:0.0f alpha:0.35f]

enum InputType_E {Unknown_Input, Text_Input, Barcode_Input, Image_Input, Favorite_Input};

@interface ShopFolderViewController ()
- (void)_showHUDWithLabel:(NSString *)label subLabel:(NSString *)subLabel animated:(BOOL)animate;

- (void)_loadFolderPageViewWithPage:(int)page;
- (void)_addPage;
- (void)_removePageAtIndex: (int)page;
- (void)_removeLastPage;
- (void)_changeToPage:(int)page animated:(BOOL)animate;
- (void)_recoverCenterInputViewFromPreviewAnimated:(BOOL)animate;
- (void)_search;
- (void)_showSearchPopover;

- (void)_deleteFolder;

- (void)_beginSchedulingNotifications;
- (void)_notificationSchedulingFinished;

- (void)_showPreviewCellWithItem:(DBItemBasicInfo *)item;

- (void)_noticeBarcodeScanner;    //For iPhone 3G, iPod touch and iPad 2

- (void)_doMoveItems;
- (void)_prepareMoveLabel;

- (void)_showCandidateFolderAnimated:(BOOL)animate;
- (void)_hideCandidateFolderAnimated:(BOOL)animate;

- (void)_receiveApplicationWillResignActiveNotification:(NSNotification *)notif;
- (void)_receivePageScrollEnableNotification:(NSNotification *)notif;
- (void)_receivePageScrollDisableNotification:(NSNotification *)notif;
- (void)_receiveStatusFrameDidChangeNotification:(NSNotification *)notif;
- (void)_receiveManagedObjectDidChangeNotification:(NSNotification *)notif;
- (void)_receiveMoveItemNotification:(NSNotification *)notif;

- (void)_moveViewsWithOffset:(CGFloat)offset;
- (void)_displayPreviewForTextInput:(NSString *)text;
- (void)_displayPreviewForBarcodeInput:(Barcode *)barcode;

- (void)_addGradientToMoveImageView;

- (void)_refreshFolderImagesContinuously:(BOOL)continuously afterDelay:(NSTimeInterval)delay;
- (void)_stopLoadingFolderImages;

#ifdef _LITE_
- (void)_checkPurchaseAndAdjustUI;
#endif
@end

@implementation ShopFolderViewController

@synthesize centerInputView, scanBarcodeButton, takePhotoButton, pickImageButton, enterTextButton, previewImageView;
@synthesize pageScrollView;
@synthesize pageControl;
@synthesize infoButton;
@synthesize purchaseButton;
@synthesize pageVCs;
//#ifdef _LITE_
//@synthesize adView;
//@synthesize loadADLabel;
//#endif
@synthesize searchLabel;
@synthesize previewTextView;

@synthesize flipsidePopoverController;

- (void)viewDidUnload
{
    [self setFavoriteButton:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.centerInputView = nil;
    self.scanBarcodeButton = nil;
    self.takePhotoButton = nil;
    self.pickImageButton = nil;
    self.enterTextButton = nil;

    self.previewTextView = nil;
    _previewCell = nil;
    self.previewImageView = nil;
    _moveTitleForPreviewImage = nil;
    
    _moveItemNameLabel = nil;
    _moveItemCountLabel = nil;

    self.pageScrollView = nil;
    self.pageControl = nil;
    self.infoButton = nil;
    _currentPageVC = nil;
#ifdef _LITE_
//    self.adView.delegate = nil;
//    self.adView = nil;
//    self.loadADLabel = nil;
#endif
    self.purchaseButton = nil;
    self.searchLabel = nil;
    _popoverView = nil;
    
    _deleteFolderAlertView = nil;

    _hud.delegate = nil;
    [_hud hide:NO];
    _hud = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:kFinishSchedulingAlertsNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kEnablePageScrollNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kDisablePageScrollNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMoveItemsNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextObjectsDidChangeNotification object:nil];

    shoppingListNavCon = nil;

    _inputType = Unknown_Input;
    _inputBasicInfo = nil;
    
    [self.pageVCs removeAllObjects];
    self.pageVCs = nil;
    _viewDidUnload = YES;
}

- (void)dealloc
{
//#ifdef _LITE_
//    adView.delegate = nil;
//#endif
    
    _hud.delegate = nil;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
#ifdef DEBUG
    //Rest for testing
//    /*[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kPurchaseRemoveAD];*/
//    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kPurchaseUnlimitCount];
//    [[NSUserDefaults standardUserDefaults] synchronize];
#endif

    return (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]);
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)setFolderPageVC:(FolderPageViewController *)inFolderPageVC
{
    _currentPageVC = inFolderPageVC;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Main Screen", nil);
    self.infoButton.exclusiveTouch = YES;
    self.favoriteButton.exclusiveTouch = YES;
    
    //Get init position
    if(!self.centerInputView.hidden) {
        centerView = self.centerInputView;
    } else if(!previewTextView.hidden) {
        centerView = self.previewTextView;
    } else {
        centerView = self.previewImageView;
    }
    
    originCenterViewPos = centerView.center;
    originPageControlPos = self.pageControl.center;
    originInfoButtonPos = self.infoButton.center;
    originFavoriteButtonPos = self.favoriteButton.center;
    
#ifdef _LITE_
    originPurchaseButtonPos = self.purchaseButton.center;
    
//    if(m_isADRemoved) {
//        [self.loadADLabel removeFromSuperview];
//        self.loadADLabel = nil;
//
//        self.adView.delegate = nil;
//        [self.adView removeFromSuperview];
//        self.adView = nil;
//    }
#endif
    
    //Adjust for iPhone 4 and 4s
    CGFloat screenHeight = [[UIScreen mainScreen] bounds].size.height;
    if(screenHeight != 568) {
        const CGFloat heightDiff = 568 - screenHeight;
        originCenterViewPos.y -= heightDiff/2.0f;   //centered
        originPageControlPos.y -= heightDiff;       //bottom-aligned
        originInfoButtonPos.y -= heightDiff;        //bottom-aligned
        originFavoriteButtonPos.y -= heightDiff;    //bottom-aligned
#ifdef _LITE_
        originPurchaseButtonPos.y -= heightDiff;    //bottom-aligned
#endif
    }
    
    _previewCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PreviewCell"];
    _previewCell.frame = CGRectMake(0, 0, self.previewTextView.frame.size.width, kImageHeight);
    _previewCell.imageView.frame = CGRectMake(0, 0, kImageWidth, kImageHeight);
    _previewCell.backgroundColor = kItemMoveViewBackgroundColor;
    _previewCell.textLabel.textColor = [UIColor whiteColor];
    _previewCell.textLabel.backgroundColor = [UIColor clearColor];
    _previewCell.textLabel.numberOfLines = 2;
    _previewCell.textLabel.font = [UIFont boldSystemFontOfSize:20.0f];
    _previewCell.textLabel.textAlignment = UITextAlignmentCenter;
    _previewCell.layer.borderWidth = 1.0f;
    _previewCell.layer.borderColor = [UIColor colorWithWhite:0.85 alpha:1.0f].CGColor;
    _previewCell.userInteractionEnabled = YES;
    _previewCell.exclusiveTouch = YES;
    [self.previewTextView addSubview:_previewCell];
    
    self.previewImageView.layer.borderWidth = 1.0f;
    self.previewImageView.layer.borderColor = [UIColor colorWithWhite:0.85 alpha:1.0f].CGColor;
    
    //Add "Drag to folder" to preview image view
    UIFont *moveTitleFont = [UIFont boldSystemFontOfSize:16.0f];
    _moveTitleForPreviewImage = [[OutlineLabel alloc] initWithFrame:CGRectMake(0, 0,
                                                                               self.previewImageView.frame.size.width,
                                                                               moveTitleFont.lineHeight+10.0f)];
    _moveTitleForPreviewImage.textAlignment = UITextAlignmentCenter;
    _moveTitleForPreviewImage.font = [UIFont boldSystemFontOfSize:17.0f];
    _moveTitleForPreviewImage.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5f];
    _moveTitleForPreviewImage.textColor = [UIColor whiteColor];
    _moveTitleForPreviewImage.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.previewImageView addSubview:_moveTitleForPreviewImage];
    
    CGFloat labelSpace = 4.0f;
    UIFont *nameLabelFont = [UIFont boldSystemFontOfSize:15.0f];
    _moveItemNameLabel = [[OutlineLabel alloc] initWithFrame:CGRectMake(labelSpace, 0,
                                                                        self.previewImageView.bounds.size.width-labelSpace*2.0f,
                                                                        nameLabelFont.lineHeight*2.0f+labelSpace)];
    _moveItemNameLabel.numberOfLines = 2;
    _moveItemNameLabel.font = nameLabelFont;
    _moveItemNameLabel.backgroundColor = [UIColor clearColor];
    _moveItemNameLabel.textColor = [UIColor whiteColor];
    _moveItemNameLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
    _moveItemNameLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    _moveItemNameLabel.textAlignment = UITextAlignmentCenter;
    _moveItemNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    _moveItemNameLabel.outlineWidth = 2.0f;
    
    UIFont *countLabelFont = [UIFont boldSystemFontOfSize:12.0f];
    _moveItemCountLabel = [[OutlineLabel alloc] initWithFrame:CGRectMake(labelSpace, 0,
                                                                         self.previewImageView.bounds.size.width-labelSpace*2.0f,
                                                                         countLabelFont.lineHeight+labelSpace)];
    _moveItemCountLabel.numberOfLines = 1;
    _moveItemCountLabel.font = countLabelFont;
    _moveItemCountLabel.backgroundColor = [UIColor clearColor];
    _moveItemCountLabel.textColor = [UIColor whiteColor];
    _moveItemCountLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _moveItemCountLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    _moveItemCountLabel.textAlignment = UITextAlignmentCenter;
    _moveItemCountLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    [self.previewImageView addSubview:_moveItemNameLabel];
    [self.previewImageView addSubview:_moveItemCountLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_receiveApplicationWillResignActiveNotification:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_receivePageScrollEnableNotification:)
                                                 name:kEnablePageScrollNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_receivePageScrollDisableNotification:)
                                                 name:kDisablePageScrollNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_receiveStatusFrameDidChangeNotification:)
                                                 name:UIApplicationDidChangeStatusBarFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_receiveManagedObjectDidChangeNotification:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_receiveMoveItemNotification:)
                                                 name:kMoveItemsNotification
                                               object:nil];

    if([HardwareUtil hasRearCam]) {
        hasRearCam = YES;
    } else {
        hasRearCam = NO;

        self.scanBarcodeButton.hidden = YES;
        self.scanBarcodeButton = nil;
        self.takePhotoButton.hidden = YES;
        self.takePhotoButton = nil;
        
        CGRect centerInputViewFrame = self.centerInputView.frame;
        centerInputViewFrame.size.height /= 2.0;
        centerInputViewFrame.origin.y += centerInputViewFrame.size.height/2.0;
        self.centerInputView.frame = centerInputViewFrame;
        self.pickImageButton.frame = CGRectMake(0, 0, self.pickImageButton.frame.size.width, self.pickImageButton.frame.size.height);
        self.enterTextButton.frame = CGRectMake(66, 0, self.enterTextButton.frame.size.width, self.enterTextButton.frame.size.height);
    }
    
    dragScrollViewToScroll = YES;

    self.takePhotoButton.exclusiveTouch = YES;
    self.pickImageButton.exclusiveTouch = YES;
    self.enterTextButton.exclusiveTouch = YES;
    self.scanBarcodeButton.exclusiveTouch = YES;
    self.pageScrollView.exclusiveTouch = YES;
    self.previewImageView.userInteractionEnabled = YES;
    self.previewImageView.exclusiveTouch = YES;
    self.previewImageView.contentStretch = CGRectMake(0, 0, 0, 0);  //Not to resize to content
    
    //Add GRs to text preview view
    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panOnPreviewView:)];
    panGR.minimumNumberOfTouches = 1;
    panGR.maximumNumberOfTouches = 1;
    [_previewCell addGestureRecognizer:panGR];
    
    UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOnPreviewView:)];
    tapGR.numberOfTapsRequired = 1;
    [tapGR requireGestureRecognizerToFail:panGR];
    [_previewCell addGestureRecognizer:tapGR];
    
    //Add GR to image preview view
    panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panOnPreviewView:)];
    panGR.minimumNumberOfTouches = 1;
    panGR.maximumNumberOfTouches = 1;
    [self.previewImageView addGestureRecognizer:panGR];
    
    tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOnPreviewView:)];
    tapGR.numberOfTapsRequired = 1;
    [tapGR requireGestureRecognizerToFail:panGR];
    [self.previewImageView addGestureRecognizer:tapGR];
    
    if(_viewDidUnload) {
        [self reloadPages];
        _viewDidUnload = NO;
    }
}

- (void)reloadPages
{
    for(FolderPageViewController *pageVC in self.pageVCs) {
        [pageVC.view removeFromSuperview];
    }
    
    //設PageController參數
    pageControl.numberOfPages = [CoreDataDatabase totalPages];
    pageControl.currentPage = [[NSUserDefaults standardUserDefaults] integerForKey:kCurrentPage];
    
    //設scrollview參數
    // a page is the width of the scroll view
    pageScrollView.pagingEnabled = YES;
    pageScrollView.contentSize = CGSizeMake(pageScrollView.frame.size.width * (pageControl.numberOfPages+1),
                                            pageScrollView.frame.size.height);
    pageScrollView.showsHorizontalScrollIndicator = NO;
    pageScrollView.showsVerticalScrollIndicator = NO;
    pageScrollView.scrollsToTop = NO;
    pageScrollView.delegate = self;
    
    //Add shopping list view controller
    _shoppingListVC = [[ShoppingListViewController alloc] initWithSuperViewController:self];
    _shoppingListVC.shoppingListDelegate = self;
    shoppingListNavCon = [[UINavigationController alloc] initWithRootViewController:_shoppingListVC];
    //Adjust for iPhone 4 and 4s
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    screenRect.size.height -= [[UIApplication sharedApplication] statusBarFrame].size.height;
    shoppingListNavCon.view.frame = screenRect;
    shoppingListNavCon.view.autoresizingMask = UIViewAutoresizingNone;// UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin;
    [pageScrollView addSubview:shoppingListNavCon.view];
    
    // pages are created on demand
    // load the visible page
    // load the page on either side to avoid flashes when the user starts scrolling
    //
    unsigned nViewIndex = 0;
    NSMutableArray *controllers = [[NSMutableArray alloc] init];
    for (nViewIndex = 0; nViewIndex < pageControl.numberOfPages; nViewIndex++) {
		[controllers addObject:[NSNull null]];
    }
    self.pageVCs = controllers;   //this will call dealloc of pages when receiving low memory warning

    for(nViewIndex = 0; nViewIndex < pageControl.numberOfPages; nViewIndex++) {
        [self _loadFolderPageViewWithPage:nViewIndex];
    }
    
    for(FolderPageViewController *pageVC in pageVCs) {
        [pageVC refreshFolderImagesAnimated:NO];
    }
    
    self.pageScrollView.hidden = NO;
    
    if(_inputImage) {
        self.previewImageView.image = _inputImage;
        self.previewImageView.hidden = NO;
        self.centerInputView.hidden = YES;
    } else if(_inputBasicInfo) {
        _previewCell.imageView.image = [_inputBasicInfo getDisplayImage];
        if([_inputBasicInfo.name length] > 0) {
            _previewCell.textLabel.text = _inputBasicInfo.name;
        } else {
            _previewCell.textLabel.text = _inputBasicInfo.barcodeData;
        }
    } else {
        self.centerInputView.hidden = NO;
    }
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:kIsInShoppingList]) {
        isViewMoved = YES;  //Prevent to modify originCenterViewPos (for UI issue of iPhone 4/4S)
        [self _moveViewsWithOffset:[[UIScreen mainScreen] bounds].size.width];
        [self.pageScrollView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
        
        _currentPageVC = [self.pageVCs objectAtIndex:0];
    } else {
        [self _changeToPage:pageControl.currentPage animated:NO];   //_currentPageVC will update here
    }
    
    if([pageVCs count] > 0) {
        //reloadPages will load image once, so we just continue to load images if not in shopping list
        BOOL isInShoppingList = [[NSUserDefaults standardUserDefaults] boolForKey:kIsInShoppingList];
        if(!isInShoppingList) {
            [self _refreshFolderImagesContinuously:!isInShoppingList afterDelay:5.0f];
        }
    }
}

- (void)_loadFolderPageViewWithPage:(int)page
{
    if (page < 0 || page >= [self.pageVCs count]) {
        return;
    }
    
    FolderPageViewController *controller = [self.pageVCs objectAtIndex:page];
    
    //初始化空的page
    if ((NSNull *)controller == [NSNull null])
    {
        //Page content is loaded here in FolderPageViewController
        controller = [[FolderPageViewController alloc] initWithPageNumber:page];
        [self.pageVCs replaceObjectAtIndex:page withObject:controller];
        controller.clickOnFolderDelegate = self;
        controller.folderEditModeDelegate = self;
    }
    
    [controller clearSelection];
    
    // add the controller's view to the scroll view
    if (controller.view.superview == nil)
    {
        CGRect frame = pageScrollView.frame;
        frame.origin.x = frame.size.width * (page+1);
        frame.origin.y = 0;
        controller.view.frame = frame;
        [pageScrollView addSubview:controller.view];
    }
}

static BOOL gDisplayNavigationBar = NO;
- (void) viewWillAppear:(BOOL)animated
{
#ifdef _LITE_
    [self _checkPurchaseAndAdjustUI];
#endif

    gDisplayNavigationBar = NO;
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    
    //May delete all items in list
    if(_currentPageVC.selectedFolderView &&
       [_moveDataList count] == 0)
    {
        _currentPageVC.selectedFolderView.imageView.isEmpty = [_currentPageVC isEmptyFolder:_currentPageVC.selectedFolder];
        [_currentPageVC clearSelection];
    }
    
    [self _hideCandidateFolderAnimated:NO];
    if(_inputBasicInfo) {
        if(_inputType == Text_Input) {
            [self _displayPreviewForTextInput:_inputBasicInfo.name];
        } else if(_inputType == Barcode_Input) {
            [self _displayPreviewForBarcodeInput:_inputBasicInfo.barcode];
        } else if(_inputType == Favorite_Input) {
            _candidateFolders = [NSMutableArray arrayWithArray:[CoreDataDatabase getFoldersContainsBasicInfo:_inputBasicInfo]];
            [self _showCandidateFolderAnimated:YES];
        }
    } else if([_moveDataList count] > 0) {
        if(_shoppingItem == nil) {
            //The moving items may be editted or deleted, so we need to update
            DBFolderItem *item;
            SelectedFolderItem *data;
            NSMutableArray *removeArray = [NSMutableArray array];
            for(int nIndex = [_moveDataList count]-1; nIndex >= 0; nIndex--) {
                data = [_moveDataList objectAtIndex:nIndex];
                item = (DBFolderItem *)[[CoreDataDatabase mainMOC] objectRegisteredForID:data.objectID];
                if(item == nil ||
                   [item isDeleted])
                {
                    [removeArray addObject:data];
                }
            }

            [_moveDataList removeObjectsInArray:removeArray];
        }
        
        if([_moveDataList count] > 0) {
            [self _prepareMoveLabel];
        } else {
            _moveDataList = nil;  //Do it here since moving item will recover input view and then move item
            [self _recoverCenterInputViewFromPreviewAnimated:NO];
        }
    }

    self.favoriteButton.enabled = ([CoreDataDatabase totalFavorites] > 0);
    
    [CoreDataDatabase removeImageOnlyItemBasicInfo];
    [CoreDataDatabase commitChanges:nil];
    
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    searchArea = [self.searchLabel convertRect:self.searchLabel.bounds toView:self.view];

    //We have mentioned that this part of code may run before reloadPages in simulator
    if([pageVCs count] > 0) {
        //reloadPages will load image once, so we just continue to load images if not in shopping list
        BOOL isInShoppingList = [[NSUserDefaults standardUserDefaults] boolForKey:kIsInShoppingList];
        if(!isInShoppingList) {
            [self _refreshFolderImagesContinuously:!isInShoppingList afterDelay:0.0f];
        }
    }
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingShowTutorial]) {
        //TODO: show tutorial
        
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kSettingShowTutorial];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        [self _noticeBarcodeScanner];
    }
    
    if(_viewDidDisappear) {
        _viewDidDisappear = NO;
        
        if([self shouldShowExpiryList]) {
            [self showExpireListAnimated:YES];
        }
    }
}

- (void) viewWillDisappear:(BOOL)animated
{
    if(gDisplayNavigationBar) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    }
    
    if(![[NSUserDefaults standardUserDefaults] boolForKey:kIsInShoppingList]) {
        [self _stopLoadingFolderImages];
    }

    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    _viewDidDisappear = YES;
}

//==============================================================
//  [BEGIN] ClickOnFolderDelegate
#pragma mark -
#pragma mark ClickOnFolderDelegate Methods
//--------------------------------------------------------------
-(void) clickOnFolder:(DBFolder *)folder
{
    BOOL isFolderEmpty = [folder isEmpty];
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Click folder"
                   withParameters:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:
                                                                       [NSNumber numberWithInt:folder.page],
                                                                       [NSNumber numberWithInt:folder.number],
                                                                       [NSNumber numberWithBool:isFolderEmpty], nil]
                                                              forKeys:[NSArray arrayWithObjects:
                                                                       @"Page", @"Number", @"IsEmpty", nil]]];
    }

    if(!isFolderEmpty) {
        //This will show as "Back" button in next navigation view
//        self.title = NSLocalizedString(@"Back", nil);
        gDisplayNavigationBar = YES;

        FolderListViewController *listItemVC = [[FolderListViewController alloc] initWithFolder:folder];
        [self.navigationController pushViewController:listItemVC animated:YES];
    }
}
//--------------------------------------------------------------
//  [END] ClickOnFolderDelegate
//==============================================================

//==============================================================
//  [BEGIN] UIScrollViewDelegate
#pragma mark - UIScrollViewDelegate Methods
//--------------------------------------------------------------
- (void)_moveViewsWithOffset:(CGFloat)offset
{
    self.pageScrollView.bounces = NO;
    
    if(!isViewMoved) {
        isViewMoved = YES;
        
        if(!self.centerInputView.hidden) {
            centerView = self.centerInputView;
        } else if(!previewTextView.hidden) {
            centerView = self.previewTextView;
        } else {
            centerView = self.previewImageView;
        }
        
        originCenterViewPos = centerView.center;
    }
    
    CGPoint pos = originCenterViewPos;
    pos.x += offset;
    centerView.center = pos;
    
    pos = originPageControlPos;
    pos.x += offset;
    self.pageControl.center = pos;
    
    pos = originInfoButtonPos;
    pos.x += offset;
    self.infoButton.center = pos;
    
    pos = originFavoriteButtonPos;
    pos.x += offset;
    self.favoriteButton.center = pos;
#ifdef _LITE_
    pos = originPurchaseButtonPos;
    pos.x += offset;
    self.purchaseButton.center = pos;
#endif
    
    if(offset >= 320.0f) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kIsInShoppingList];
        [[NSUserDefaults standardUserDefaults] synchronize];

        [self didLeaveFolderEditMode];
        [self _stopLoadingFolderImages];
    } else {
        if(!_refreshFolderImagesEnabled) {
            [self _refreshFolderImagesContinuously:YES afterDelay:0.0f];
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)sender
{
    // We don't want a "feedback loop" between the UIPageControl and the scroll delegate in
    // which a scroll event generated from the user hitting the page control triggers updates from
    // the delegate method. We use a boolean to disable the delegate logic when the page control is used.
    if (!dragScrollViewToScroll)
    {
        // do nothing - the scroll was initiated from the page control, not the user dragging
        return;
    }
	
    CGFloat pageWidth = pageScrollView.frame.size.width;
    if(pageScrollView.contentOffset.x < pageWidth) {
        CGFloat offset = pageWidth - pageScrollView.contentOffset.x;
        CGFloat listAlpha;
        if(offset < 0.0f) {
            listAlpha = 0.0f;
        } else if(offset >= 160.0f) {
            listAlpha = 1.0f;
        } else {
            listAlpha = offset/160.0f;
        }
        
        shoppingListNavCon.view.alpha = listAlpha;

        if(shouldMoveViews) {
            [self _moveViewsWithOffset:offset];
        }
    } else {
        self.pageScrollView.bounces = YES;
        if(isViewMoved) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kIsInShoppingList];
            [[NSUserDefaults standardUserDefaults] synchronize];
            isViewMoved = NO;
            
            [_shoppingListVC dismissImagePreviewAnimated:NO];
            
            centerView.center = originCenterViewPos;
            self.pageControl.center = originPageControlPos;
            self.infoButton.center = originInfoButtonPos;
            self.favoriteButton.center = originFavoriteButtonPos;
#ifdef _LITE_
            self.purchaseButton.center = originPurchaseButtonPos;
#endif
        }
        
        // Switch the indicator when more than 50% of the previous/next page is visible
        int page = floor((pageScrollView.contentOffset.x - pageWidth / 2) / pageWidth);// + 1;
        if(page != pageControl.currentPage &&
           page < [self.pageVCs count])
        {
            pageControl.currentPage = page;
            _currentPageVC = [self.pageVCs objectAtIndex:page];
            
            // load the visible page and the page on either side of it (to avoid flashes when the user starts scrolling)
            [self _loadFolderPageViewWithPage:page - 1];
            [self _loadFolderPageViewWithPage:page];
            [self _loadFolderPageViewWithPage:page + 1];
            // A possible optimization would be to unload the views+controllers which are no longer visible
            
            [[NSUserDefaults standardUserDefaults] setInteger:page forKey:kCurrentPage];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
}

// At the begin of scroll dragging, reset the boolean used when scrolls originate from the UIPageControl
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    dragScrollViewToScroll = YES;

    //Since page may be removed, so we update contentSize here to prevent dragging to empty scrollview
    pageScrollView.contentSize = CGSizeMake(pageScrollView.frame.size.width * (pageControl.numberOfPages+1),
                                            pageScrollView.frame.size.height);

    if(scrollView.contentOffset.x < scrollView.frame.size.width) {
        isViewMoved = YES;
    } else {
        isViewMoved = NO;
    }

    if(scrollView.contentOffset.x >= scrollView.frame.size.width*2.0f) {
        shouldMoveViews = NO;
        shoppingListNavCon.view.hidden = YES;
    } else {
        shouldMoveViews = YES;
        shoppingListNavCon.view.hidden = NO;
    }
}

// At the end of scroll animation, reset the boolean used when scrolls originate from the UIPageControl
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    dragScrollViewToScroll = YES;
}
//--------------------------------------------------------------
//  [END] UIScrollViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] Page Operations
#pragma mark -
#pragma mark Page Operations
//--------------------------------------------------------------
-(void) _addPage
{
    int page = pageControl.numberOfPages;
    pageControl.numberOfPages++;
    
    //Update full size of scrollview
    pageScrollView.contentSize = CGSizeMake(pageScrollView.frame.size.width * (pageControl.numberOfPages+1),
                                            pageScrollView.frame.size.height);
    
    //Add new FolderPageViewController to viewController array
    FolderPageViewController *controller = [[FolderPageViewController alloc] initWithPageNumber:page];
    [self.pageVCs addObject:controller];
    controller.clickOnFolderDelegate = self;
    controller.folderEditModeDelegate = self;
    
    // add the controller's view to the scroll view
    CGRect frame = pageScrollView.frame;
    frame.origin.x = frame.size.width * (page+1);
    frame.origin.y = 0;
    controller.view.frame = frame;
    [pageScrollView addSubview:controller.view];
}

//Must do this in main thread
-(void) _removePageAtIndex: (int)page
{
    if(pageControl.numberOfPages <= 1 ||
       page >= pageControl.numberOfPages)
    {
        return;
    }
    
    if(pageControl.currentPage == page &&
       page > 0)
    {
        //pageControl.currentPage will minus 1 here
        [self movePage:kMoveToLeftPage];
    }
    
    pageControl.numberOfPages--;
    
    //Calculate start frame position to adjust
    CGRect frame = pageScrollView.frame;
    if(1 == pageControl.numberOfPages) {
        frame.origin.x = frame.size.width;
    } else if(page == pageControl.numberOfPages) {
        frame.origin.x = frame.size.width * page;
    } else {
        frame.origin.x = frame.size.width * (page+1);
    }
    
    //Don't adjust "pageScrollView.contentSize" here since movePage animation will reference to contentSize
    //We do this in scrollViewWillBeginDragging instead just for dragging
    
    FolderPageViewController *adjustViewController = nil;
    int adjustPage = page;
    if(page == 0 && pageControl.currentPage == page) { //delete page 0
        //Shift page 0 and 1 to left, it looks like page 0 disappears and page 1 replaces page 0
        FolderPageViewController *firstPage = [self.pageVCs objectAtIndex:0];
        adjustViewController = [self.pageVCs objectAtIndex:1];
        [adjustViewController changePageNumber:0];

        [UIView animateWithDuration:0.25
                         animations:^{
                             firstPage.view.center = CGPointMake(-firstPage.view.center.x, firstPage.view.center.y);
                             adjustViewController.view.frame = frame;
                         } completion:^(BOOL finished) {
                             [firstPage.view removeFromSuperview];
                             [self _changeToPage:0 animated:NO];   //Fix bug that folders do not animate when focused after deleting page 0
                         }];

        [self.pageVCs removeObjectAtIndex:0];
        frame.origin.x += frame.size.width;
        adjustPage = 1;
    } else {
        FolderPageViewController *controller = [self.pageVCs objectAtIndex:page];
        [controller.view removeFromSuperview];
        [self.pageVCs removeObjectAtIndex:page];
    }
    
    //Adjust frames of rest pages
    for(; adjustPage < pageControl.numberOfPages; adjustPage++) {
        adjustViewController = [self.pageVCs objectAtIndex:adjustPage];
        adjustViewController.view.frame = frame;
        frame.origin.x += frame.size.width;

        //Adjust page field of folders
        [adjustViewController changePageNumber:adjustPage];
    }
    
    //Keep this code for deleting page which is not current page
    if(pageControl.currentPage >= pageControl.numberOfPages) {
        pageControl.currentPage = pageControl.numberOfPages - 1;
    }
}

-(void) _removeLastPage
{
    [self _removePageAtIndex:(pageControl.numberOfPages-1)];
}

-(void) _changeToPage:(int)page animated:(BOOL)animate
{
    if(page < 0 ||
       page >= [pageVCs count])
    {
        return;
    }

    if(isViewMoved) {
        isViewMoved = NO;
        
        void(^moveBlock)() = ^{
            centerView.center = originCenterViewPos;
            self.pageControl.center = originPageControlPos;
            self.infoButton.center = originInfoButtonPos;
            self.favoriteButton.center = originFavoriteButtonPos;
#ifdef _LITE_
            self.purchaseButton.center = originPurchaseButtonPos;
#endif            
        };
        
        if(animate) {
            [UIView animateWithDuration:0.33f
                             animations:moveBlock
                             completion:^(BOOL finished) {
                                 [_shoppingListVC leaveEditingShoppingItemAnimated:NO];
                             }];
        } else {
            moveBlock();
            [_shoppingListVC leaveEditingShoppingItemAnimated:NO];
        }
    }

    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kIsInShoppingList];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _currentPageVC = [self.pageVCs objectAtIndex:page];
	
    // load the visible page and the page on either side of it (to avoid flashes when the user starts scrolling)
    [self _loadFolderPageViewWithPage:page - 1];
    [self _loadFolderPageViewWithPage:page];
    [self _loadFolderPageViewWithPage:page + 1];

	// update the scroll view to the appropriate page
    CGRect frame = pageScrollView.frame;
    frame.origin.x = frame.size.width * (page+1);
    frame.origin.y = 0;
    dragScrollViewToScroll = NO;
    [pageScrollView scrollRectToVisible:frame animated:animate];
}

- (BOOL)movePage: (NSString *)moveDirection
{
    movePageDirection = moveDirection;
    
    bool doMovePage = NO;
    if(moveDirection == kMoveToLeftPage) {
        if(pageControl.currentPage > 0) {
            pageControl.currentPage--;
            doMovePage = YES;
        }
    } else if(moveDirection == kMoveToRightPage) {
        if(pageControl.currentPage < pageControl.numberOfPages - 1) {
            pageControl.currentPage++;
            doMovePage = YES;
        }
    }
    
    if(doMovePage) {
        [self _changeToPage:pageControl.currentPage animated:YES];
    }
    
    return doMovePage;
}

- (void)movePageContinuously: (NSString *)moveDirection
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(movePageContinuously:) object:movePageDirection];
    
    if([self movePage:moveDirection]) {
        [FlurryAnalytics logEvent:@"Drag preview to change page"];
        //Continue to move to next page while holding
        [self performSelector:@selector(movePageContinuously:) withObject:moveDirection afterDelay:kMovePageDelay];
    }
}

//--------------------------------------------------------------
//  [END] Page Operations
//==============================================================

//==============================================================
//  [BEGIN] UIGestureRecognizerDelegate
#pragma mark -
#pragma mark UIGestureRecognizerDelegate Methods
//--------------------------------------------------------------
- (void)_recoverCenterInputViewFromPreviewAnimated:(BOOL)animate
{
    UIView *previewView = nil;
    if(!previewTextView.hidden) {
        previewView = self.previewTextView;
    } else {
        previewView = self.previewImageView;
        _inputImage = nil;
    }
    
    _inputBasicInfo = nil;
    _inputType = Unknown_Input;
    
    self.centerInputView.center = centerView.center;
    self.centerInputView.hidden = NO;
    centerView = self.centerInputView;

    if(!animate) {
        previewView.hidden = YES;
    } else {
        const static int kButtonAnimateOffset = 20;
        //Disable scrollview while animating
        pageScrollView.scrollEnabled = NO;
        self.view.userInteractionEnabled = NO;
        
        [UIView animateWithDuration:0.25
                              delay:0
                            options:UIViewAnimationCurveEaseOut
                         animations:^{
                             previewView.transform = CGAffineTransformMakeScale(0.001, 0.001);
                             previewView.alpha = 0;
                         } completion:^(BOOL finished) {
                             self.previewImageView.image = nil;
                             _moveItemNameLabel.text = nil;
                             _moveItemCountLabel.text = nil;
                             
                             previewView.hidden = YES;
                             previewView.alpha = 1;
                             previewView.transform = CGAffineTransformIdentity;
                         }];
        
        //Init hidden input views' positions
        CGPoint topLeftCenter = self.scanBarcodeButton.center;
        CGPoint topRightCenter = self.takePhotoButton.center;
        CGPoint bottomLeftCenter = self.pickImageButton.center;
        CGPoint bottomRightCenter = self.enterTextButton.center;
        
        self.centerInputView.alpha = 0;
        
        if(hasRearCam) {
            self.scanBarcodeButton.center = CGPointMake(topLeftCenter.x-kButtonAnimateOffset, topLeftCenter.y-kButtonAnimateOffset);
            self.takePhotoButton.center = CGPointMake(topRightCenter.x+kButtonAnimateOffset, topRightCenter.y-kButtonAnimateOffset);
            self.pickImageButton.center = CGPointMake(bottomLeftCenter.x-kButtonAnimateOffset, bottomLeftCenter.y+kButtonAnimateOffset);
            self.enterTextButton.center = CGPointMake(bottomRightCenter.x+kButtonAnimateOffset, bottomRightCenter.y+kButtonAnimateOffset);
        } else {
            self.pickImageButton.center = CGPointMake(bottomLeftCenter.x-kButtonAnimateOffset, bottomLeftCenter.y);
            self.enterTextButton.center = CGPointMake(bottomRightCenter.x+kButtonAnimateOffset, bottomRightCenter.y);
        }
        
        [UIView animateWithDuration:0.25
                              delay:0.05
                            options:UIViewAnimationCurveEaseIn
                         animations:^{
                             self.scanBarcodeButton.center = topLeftCenter;
                             self.takePhotoButton.center = topRightCenter;
                             self.pickImageButton.center = bottomLeftCenter;
                             self.enterTextButton.center = bottomRightCenter;
                             self.centerInputView.alpha = 1;
                         } completion:^(BOOL finished) {
                             self.view.userInteractionEnabled = YES;
                             self.pageScrollView.scrollEnabled = YES;
                         }];
    }
    
    [self _hideCandidateFolderAnimated:YES];
}

- (void)tapOnPreviewView:(UITapGestureRecognizer *)sender
{
    if(sender.state == UIGestureRecognizerStateChanged ||
       sender.state == UIGestureRecognizerStateEnded)
    {
        _shoppingItem = nil;    //Prevent recover center view before testing _shoppingItem
        _moveDataList = nil;  //Do it here since moving item will recover input view and then move item
        [self _recoverCenterInputViewFromPreviewAnimated:YES];
    }
}

- (void)panOnPreviewView:(UIPanGestureRecognizer *)sender
{
//    [sender.view.layer removeAllAnimations];

	[self.view bringSubviewToFront:sender.view];
	CGPoint translatedPoint = [sender translationInView:self.pageScrollView];
    CGPoint fingerPos = [sender locationInView:self.pageScrollView];
    fingerPos.x -= (pageControl.currentPage+1) * pageScrollView.frame.size.width;
    
    static CGFloat firstX;
    static CGFloat firstY;
    static BOOL snapToFolder = NO;

    // Save position before moving
	if([(UIPanGestureRecognizer*)sender state] == UIGestureRecognizerStateBegan) {
        if(!temporaryAddingPage) {
            temporaryAddingPage = YES;
            [self _addPage];
        }
        
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
            [FlurryAnalytics logEvent:@"First finger position of dragging"
                       withParameters:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:
                                                                           [NSNumber numberWithInt:fingerPos.x],
                                                                           [NSNumber numberWithInt:fingerPos.y], nil]
                                                                  forKeys:[NSArray arrayWithObjects:
                                                                           @"X", @"Y", nil]]];
        }

		firstX = [[sender view] center].x;
		firstY = [[sender view] center].y;
        if(sender.view == self.previewImageView) {
            [UIView animateWithDuration:0.1
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut
                                        | UIViewAnimationOptionBeginFromCurrentState
                                        | UIViewAnimationOptionAllowUserInteraction
                             animations:^(void) {
                                 sender.view.alpha = 0.5;
                             }
                             completion:NULL];
        } else if(sender.view == _previewCell) {
            CGRect rectToParent = [_previewCell convertRect:_previewCell.bounds toView:self.view];
            firstX = rectToParent.size.width/2;
            firstY = rectToParent.size.height/2;
            [UIView animateWithDuration:0.1
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionAllowUserInteraction
                             animations:^(void) {
                                 _previewCell.alpha = 0.5;
                             }
                             completion:NULL];
        }
	}

    // Calculate current position
	translatedPoint = CGPointMake(firstX+translatedPoint.x, firstY+translatedPoint.y);
	[sender.view setCenter:translatedPoint];
    
    if(sender.state == UIGestureRecognizerStateChanged ||
       sender.state == UIGestureRecognizerStateBegan)
    {
//        CGPoint fingerPos = [sender locationInView:self.pageScrollView];
//        fingerPos.x -= pageControl.currentPage * pageScrollView.frame.size.width;
        
        if([_currentPageVC isOverlapToFolder:fingerPos]) {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_showSearchPopover) object:nil];
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(movePageContinuously:) object:movePageDirection];
            movePageDirection = nil;
            snapToFolder = YES;
        } else {
            snapToFolder = NO;

            if(fingerPos.x < 30) {
                if(!movePageDirection) {
                    movePageDirection = kMoveToLeftPage;
                    [self performSelector:@selector(movePageContinuously:) withObject:movePageDirection afterDelay:kMovePageDelay];
                }
            } else if(fingerPos.x >= 290) {
                if(!movePageDirection) {
                    movePageDirection = kMoveToRightPage;
                    [self performSelector:@selector(movePageContinuously:) withObject:movePageDirection afterDelay:kMovePageDelay];
                }
            } else if(sender.view == _previewCell && _canSearch && CGRectContainsPoint(searchArea, fingerPos)) {
                if(!prepareToShowSearchPopover) {
                    prepareToShowSearchPopover = YES;
                    [self performSelector:@selector(_showSearchPopover) withObject:nil afterDelay:0.25];
                }
            } else {
                self.searchLabel.textColor = [UIColor colorWithWhite:1 alpha:1];
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_showSearchPopover) object:nil];
                prepareToShowSearchPopover = NO;
                if(self.searchLabel.highlighted) {
                    self.searchLabel.highlighted = NO;
                    [_popoverView dismissPopoverAnimated:NO];
                }

                [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                         selector:@selector(movePageContinuously:)
                                                           object:movePageDirection];
                movePageDirection = nil;
            }
        }
    } else if(sender.state == UIGestureRecognizerStateEnded ||
              sender.state == UIGestureRecognizerStateCancelled)    //Show lite version alert will cancel GR
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_showSearchPopover) object:nil];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(movePageContinuously:) object:movePageDirection];
        movePageDirection = nil;

        if(sender.state == UIGestureRecognizerStateEnded) {
            if(temporaryAddingPage) {
                if(pageControl.currentPage == pageControl.numberOfPages - 1 &&
                   !self.searchLabel.highlighted)
                {
                    snapToFolder = YES;
                    [_currentPageVC selectEmptyFolder];
                } else {
                    [self _removeLastPage];
                    temporaryAddingPage = NO;
                }
            }

#ifdef _LITE_
            if(snapToFolder && !m_isUnlimited) {
                int nAddCount = 0;
                if(_moveDataList == nil ||
                   _shoppingItem != nil)
                {
                    nAddCount = 1;
                } else {
                    nAddCount = [_moveDataList count];
                }
                
                int itemCount = [CoreDataDatabase totalItems] + nAddCount;
                if(itemCount > kLimitTotalItems) {
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Limited Item Count", nil)
                                                                        message:NSLocalizedString(@"Would you like to remove the limitation?", nil)
                                                                       delegate:self
                                                              cancelButtonTitle:NSLocalizedString(@"No, thanks", nil)
                                                              otherButtonTitles:NSLocalizedString(@"Yes", nil), nil];
                    [alertView show];
                    snapToFolder = NO;
                }
            }
#endif

            // Move to position before with animation when GR ended
            if(snapToFolder) {
                if([_moveDataList count] > 0) {
                    isMovingItem = YES;

                    if(_shoppingItem == nil) {
                        //Move items to another folder
                        if(_currentPageVC.selectedFolder == nil) {
                            DBFolder *newFolder = [CoreDataDatabase obtainTempFolder];
                            newFolder.page = _currentPageVC.page;
                            newFolder.number = [_currentPageVC.folderViews indexOfObject:_currentPageVC.selectedFolderView];
                            
                            EditFolderViewController *newFolderVC = [[EditFolderViewController alloc] initToCreateFolderOnly:newFolder];
                            newFolderVC.delegate = self;
                            UINavigationController *navcon = [[UINavigationController alloc] initWithRootViewController:newFolderVC];
                            [self presentModalViewController:navcon animated:YES];
                        } else {
                            [self _doMoveItems];
                        }
                    } else {
                        UINavigationController *navcon = nil;
                        //Add shopping item to a folder
                        if(_currentPageVC.selectedFolder == nil) {
                            navcon = [[UINavigationController alloc] init];
                            DBFolder *newFolder = [CoreDataDatabase obtainTempFolder];
                            newFolder.page = _currentPageVC.page;
                            newFolder.number = [_currentPageVC.folderViews indexOfObject:_currentPageVC.selectedFolderView];

                            editFolderItemSwitcher = [[NewFolderItemSwitcher alloc] initWithNavigationController:navcon
                                                                                                          folder:newFolder
                                                                                                    shoppingItem:_shoppingItem];
                            editFolderItemSwitcher.delegate = self;
                        } else {
                            EditItemViewController *editItemController = [[EditItemViewController alloc]
                                                                          initWithShoppingItem:_shoppingItem
                                                                          folder:_currentPageVC.selectedFolder];
                            editItemController.delegate = self;
                            
                            navcon = [[UINavigationController alloc] initWithRootViewController:editItemController];
                        }
                        
                        [self presentModalViewController:navcon animated:YES];
                    }
                } else {
                    UINavigationController *navcon = nil;
                    //Add new folder item
                    DBFolderItem *newItem = [CoreDataDatabase obtainTempFolderItem];
                    
                    if(_currentPageVC.selectedFolder == nil) {
                        navcon = [[UINavigationController alloc] init];
                        DBFolder *newFolder = [CoreDataDatabase obtainTempFolder];
                        newFolder.page = _currentPageVC.page;
                        newFolder.number = [_currentPageVC.folderViews indexOfObject:_currentPageVC.selectedFolderView];
                        
                        editFolderItemSwitcher = [[NewFolderItemSwitcher alloc] initWithNavigationController:navcon
                                                                                                      folder:newFolder
                                                                                                        item:newItem
                                                                                                   basicInfo:_inputBasicInfo];
                        editFolderItemSwitcher.delegate = self;
                    } else {
                        EditItemViewController *editItemController = [[EditItemViewController alloc] initWithFolderItem:newItem
                                                                                                              basicInfo:_inputBasicInfo
                                                                                                                 folder:_currentPageVC.selectedFolder];
                        editItemController.delegate = self;
                        
                        navcon = [[UINavigationController alloc] initWithRootViewController:editItemController];
                    }
                    
                    [self presentModalViewController:navcon animated:YES];
                }
            } else if(self.searchLabel.highlighted) {
                [self _search];
            }
        }

        BOOL presentAnotherViewController = snapToFolder || self.searchLabel.highlighted;
        NSTimeInterval animationDuration = (presentAnotherViewController) ? 0    : 0.35;
        NSTimeInterval animationDelay    = (presentAnotherViewController) ? 0.75 : 0;
        
        [UIView animateWithDuration:animationDuration
                              delay:animationDelay
                            options:UIViewAnimationOptionCurveEaseOut
                                    | UIViewAnimationOptionBeginFromCurrentState
                                    | UIViewAnimationOptionAllowUserInteraction
                         animations:^(void) {
                             [sender.view setCenter:CGPointMake(firstX, firstY)];
                             sender.view.alpha = 1;
                         }
                         completion:^(BOOL isComplete) {
                             //De-focus after modal view presents
                             [_currentPageVC.selectedFolderView setFocused:NO animated:NO];

                             self.searchLabel.highlighted = NO;
                             self.searchLabel.textColor = [UIColor colorWithWhite:1 alpha:1];
                             prepareToShowSearchPopover = NO;
                             [_popoverView dismissPopoverAnimated:NO];
                         }];

        if(!presentAnotherViewController) {
            self.searchLabel.highlighted = NO;
            self.searchLabel.textColor = [UIColor colorWithWhite:1 alpha:1];
        }
        snapToFolder = NO;
	}
}

//--------------------------------------------------------------
//  [END] UIGestureRecognizerDelegate
//==============================================================

//==============================================================
//  [BEGIN] IBActions
#pragma mark -
#pragma mark IBAction methods
//--------------------------------------------------------------
- (IBAction)changePage:(id)sender
{
    [self _changeToPage: pageControl.currentPage animated:YES];
    
    // Set the boolean used when scrolls originate from the UIPageControl. See scrollViewDidScroll: above.
    dragScrollViewToScroll = NO;
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Change page by page control"];
    }
}

- (IBAction)takePhoto: (UIButton *)sender
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Begin Input"
                   withParameters:[NSDictionary dictionaryWithObject:@"From Camera" forKey:@"Input Method"]];
    }

    UIImagePickerController *pickImageVC = [[UIImagePickerController alloc] init];
    //Don't do this, otherwise you cannot dismiss the view controller
    //[[[UIApplication sharedApplication] keyWindow] setRootViewController:pickImageVC];
    pickImageVC.delegate = self;
    pickImageVC.allowsEditing = YES;
    pickImageVC.sourceType = UIImagePickerControllerSourceTypeCamera;
    [self presentViewController:pickImageVC animated:YES completion:NULL];
}

-(IBAction)pickImage: (UIButton *)sender
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Begin Input"
                   withParameters:[NSDictionary dictionaryWithObject:@"From Album" forKey:@"Input Method"]];
    }

    UIImagePickerController *pickImageVC = [[UIImagePickerController alloc] init];
    //Don't do this, otherwise you cannot dismiss the view controller
    //[[[UIApplication sharedApplication] keyWindow] setRootViewController:pickImageVC];
    pickImageVC.delegate = self;
    pickImageVC.allowsEditing = YES;
    pickImageVC.mediaTypes = [NSArray arrayWithObject:(NSString *)kUTTypeImage];
    [self presentViewController:pickImageVC animated:YES completion:NULL];
}

- (IBAction)scanBarcode:(UIButton *)sender
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Begin Input"
                   withParameters:[NSDictionary dictionaryWithObject:@"From Barcode" forKey:@"Input Method"]];
    }

    BarcodeScannerViewController *barcodeScanVC = [BarcodeScannerViewController new];
    barcodeScanVC.barcodeScanDelegate = self;
    [self presentModalViewController:barcodeScanVC animated:YES];
}

- (IBAction)enterText:(id)sender
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Begin Input"
                   withParameters:[NSDictionary dictionaryWithObject:@"From Text" forKey:@"Input Method"]];
    }

    EnterTextViewController *enterTextVC = [[EnterTextViewController alloc] init];
    enterTextVC.title = NSLocalizedString(@"Enter Item Name", nil);
    enterTextVC.delegate = self;
    
    [self presentModalViewController:enterTextVC animated:YES];
}

- (void)_search
{
    gDisplayNavigationBar = YES;
    
    int searchInputType = _inputType;
    if(_inputType == Favorite_Input) {
        if([_inputBasicInfo.barcodeData length] > 0) {
            searchInputType = Barcode_Input;
        } else if([_inputBasicInfo.name length] > 0) {
            searchInputType = Text_Input;
        }
    }
    
    if(searchInputType == Barcode_Input) {
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
            [FlurryAnalytics logEvent:@"Search"
                       withParameters:[NSDictionary dictionaryWithObject:@"Barcode" forKey:@"Source"]];
        }
        
        DBItemBasicInfo *basicInfo = [CoreDataDatabase getItemBasicInfoByBarcode:_inputBasicInfo.barcode];
        if(basicInfo) {
            //Prepare statistics
            LoadedBasicInfoData *info = [LoadedBasicInfoData new];
            info.name = basicInfo.name;
            
            UIImage *resizedImage = [[basicInfo getDisplayImage] resizedImage:CGSizeMake(kImageWidth<<1, kImageHeight<<1)
                                                         interpolationQuality:kCGInterpolationHigh];
            info.image = [resizedImage roundedCornerImage:18 borderSize:1];
            
            info.stock = [CoreDataDatabase stockOfBasicInfo:basicInfo];
            info.priceStatistics = [CoreDataDatabase getPriceStatisticsOfBasicInfo:basicInfo];
            info.expiredCount = [CoreDataDatabase totalExpiredItemsOfBasicInfo:basicInfo];
            info.nearExpiredCount = [CoreDataDatabase totalNearExpiredOfBasicInfo:basicInfo];
            info.nextExpiryDate = [CoreDataDatabase getNextExpiryDateOfBasicInfo:basicInfo];
            info.isInShoppingList = (basicInfo.shoppingItem != nil);
            info.isFavorite = basicInfo.isFavorite;
            info.barcode = _inputBasicInfo.barcode;
            
            ListSearchResultsViewController *listSearchVC = [[ListSearchResultsViewController alloc] initToSearchBarcode:info.barcode
                                                                                                           WithBasicInfo:basicInfo
                                                                                                             preloadData:info];
            [self.navigationController pushViewController:listSearchVC animated:YES];
        } else {
            SearchListViewController *searchListVC = [[SearchListViewController alloc] initToSearchBarcode:_inputBasicInfo.barcode];
            [self.navigationController pushViewController:searchListVC animated:YES];
        }
    } else if(searchInputType == Text_Input) {
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
            [FlurryAnalytics logEvent:@"Search"
                       withParameters:[NSDictionary dictionaryWithObject:@"Text" forKey:@"Source"]];
        }

        SearchListViewController *searchListVC = [[SearchListViewController alloc] initToSearchName:_inputBasicInfo.name];
        [self.navigationController pushViewController:searchListVC animated:YES];
    }
}

//==============================================================
//  [BEGIN] AppSettingViewControllerDelegate
#pragma mark - AppSettingViewControllerDelegate
//--------------------------------------------------------------
- (void)flipsideViewControllerDidFinish:(AppSettingViewController *)controller
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self dismissViewControllerAnimated:YES completion:NULL];
    }
}

- (void)databaseRestored
{
    _moveDataList = nil; //Do it here since moving item will recover input view and then move item
    [self _recoverCenterInputViewFromPreviewAnimated:NO];
    
    for(FolderPageViewController *pageVC in self.pageVCs) {
        [pageVC.view removeFromSuperview];
    }
    [self.pageVCs removeAllObjects];
    [shoppingListNavCon.view removeFromSuperview];
    shoppingListNavCon = nil;
    _shoppingListVC = nil;
    
    [self reloadPages];
}
//--------------------------------------------------------------
//  [END] AppSettingViewControllerDelegate
//==============================================================

- (IBAction)showInfo:(id)sender
{
    //Leave edit mode before entering Settings to enhance performance of flip animation
    _currentPageVC.editing = NO;
    [self didLeaveFolderEditMode];
    
    AppSettingViewController *controller = [[AppSettingViewController alloc] initWithNibName:@"AppSettingViewController" bundle:nil];
    controller.delegate = self;
    controller.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    
    UINavigationController *navcon = [[UINavigationController alloc] initWithRootViewController:controller];
    navcon.navigationBar.barStyle = UIBarStyleBlack;
    [self presentModalViewController:navcon animated:YES];
}
//--------------------------------------------------------------
//  [END] IBActions
//==============================================================

//==============================================================
//  [BEGIN] BarcodeScanDelegate Methods
#pragma mark -
#pragma mark BarcodeScanDelegate Methods
//--------------------------------------------------------------
- (void)barcodeScanCancelled
{
    [self dismissModalViewControllerAnimated:YES];
}

- (void)barcodeScanned:(Barcode *)barcode
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Input Data Type"
                   withParameters:[NSDictionary dictionaryWithObject:@"Barcode" forKey:@"Type"]];
    }

    _inputType = Unknown_Input;
    _inputImage = nil;
    _inputBasicInfo = nil;
    _shoppingItem = nil;

    if(barcode != nil &&
       [barcode.barcodeData length] > 0)
    {
        _inputType = Barcode_Input;
        _inputBasicInfo = [CoreDataDatabase obtainTempItemBasicInfo];
        _inputBasicInfo.barcode = barcode;
//        [self _displayPreviewForBarcodeInput:barcode];    //viewWillAppear will do this
    }
    
    [self dismissModalViewControllerAnimated:YES];
}

- (void)_displayPreviewForBarcodeInput:(Barcode *)barcode
{
    if([barcode.barcodeData length] == 0) {
        return;
    }
    
    DBItemBasicInfo *basicInfo = [CoreDataDatabase getItemBasicInfoByBarcode:barcode];
    if(basicInfo == nil) {
        _inputBasicInfo.barcode = barcode;
    } else {
        _inputBasicInfo = basicInfo;
        _candidateFolders = [NSMutableArray arrayWithArray:[CoreDataDatabase getFoldersContainsItemBarcode:barcode]];
        [self _showCandidateFolderAnimated:YES];
    }

    [self _showPreviewCellWithItem:_inputBasicInfo];
}
//--------------------------------------------------------------
//  [END] BarcodeScanDelegate
//==============================================================

//==============================================================
//  [BEGIN] UIImagePickerControllerDelegate
#pragma mark -
#pragma mark UIImagePickerControllerDelegate Methods
//--------------------------------------------------------------
- (void) imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    BOOL isFail = YES;
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    _inputType = Unknown_Input;
    if(CFStringCompare((__bridge CFStringRef)mediaType, kUTTypeImage, 0) == kCFCompareEqualTo) {
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
            [FlurryAnalytics logEvent:@"Input Data Type"
                       withParameters:[NSDictionary dictionaryWithObject:@"Image" forKey:@"Type"]];
        }

        _inputType = Image_Input;
        _shoppingItem = nil;
        _inputBasicInfo = [CoreDataDatabase obtainTempItemBasicInfo];
        
        UIImage *editImage = [info objectForKey:UIImagePickerControllerEditedImage];
        [_inputBasicInfo setUIImage:[editImage thumbnailImage:kImageSaveSize
                                            transparentBorder:0
                                                 cornerRadius:0
                                     interpolationQuality:kCGInterpolationHigh]];
        
        if([_inputBasicInfo getDisplayImage]) {
            self.previewImageView.image = _inputBasicInfo.displayImage;
            _moveTitleForPreviewImage.text = NSLocalizedString(@"Drag To Add", nil);
            self.previewImageView.hidden = NO;
            self.centerInputView.hidden = YES;
            isFail = NO;
        } else {
            [FlurryAnalytics logEvent:@"Fail to input image"];
        }
    } else {
        [FlurryAnalytics logEvent:@"Fail to take image"
                   withParameters:[NSDictionary dictionaryWithObject:mediaType forKey:@"MediaType"]];
    }
    
    if(isFail) {
        UIAlertView *alertImageFail = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot Take Image", nil)
                                                                 message:NSLocalizedString(@"Please try again. If the problem remains, please turn off the app and run again.", nil)
                                                                delegate:nil
                                                       cancelButtonTitle:NSLocalizedString(@"Dismiss", nil)
                                                       otherButtonTitles:nil];
        [alertImageFail show];
    }

    [self dismissModalViewControllerAnimated:YES];
}
//--------------------------------------------------------------
//  [END] UIImagePickerControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] EditFolderViewControllerDelegate
#pragma mark -
#pragma mark EditFolderViewControllerDelegate Methods
//--------------------------------------------------------------
- (void)cancelEditFolder:(id)sender
{
    [_currentPageVC clearSelection];

    if(editFolderItemSwitcher) {
        editFolderItemSwitcher = nil;
        if(temporaryAddingPage) {
            temporaryAddingPage = NO;
            if([_currentPageVC isEmptyPage]) {
                [self _removeLastPage];
            }
        }
    }
    
    [self dismissModalViewControllerAnimated:YES];
}

- (void)finishEditFolder:(id)sender withFolderData:(DBFolder *)folderData
{
    [_currentPageVC addFolder:folderData];
    
    _currentPageVC.selectedFolderView.label.text = folderData.name;
//    _currentPageVC.selectedFolderView.imageView.layer.borderColor = folderData.color.CGColor;
    _currentPageVC.selectedFolderView.imageView.image = [folderData getDisplayImage];
    _currentPageVC.selectedFolderView.imageView.isEmpty = ([CoreDataDatabase totalItemsInFolder:folderData] == 0);
    _currentPageVC.selectedFolderView.locked = ([folderData.password length] > 0);
    _currentPageVC.selectedFolderView.expiredBadgeNumber = [CoreDataDatabase totalExpiredItemsInFolder:folderData within:0];
    _currentPageVC.selectedFolderView.nearExpiredBadgeNumber = [CoreDataDatabase totalNearExpiredItemsInFolder:folderData];

    if([_moveDataList count] == 0) {
        [_currentPageVC clearSelection];
        if(temporaryAddingPage) {
            temporaryAddingPage = NO;
            if([_currentPageVC isEmptyPage] &&
               [folderData.name length] == 0)
            {
                [self _removeLastPage];
            }
        }
        
        if(editFolderItemSwitcher) {
            //Create a new folder
            [self _recoverCenterInputViewFromPreviewAnimated:YES];
        }
    } else if(isMovingItem) {
        //Shopping item has been added to a new folder, remove it from database and list
        if(_shoppingItem) {
            [CoreDataDatabase removeShoppingItem:_shoppingItem updatePositionOfRestItems:NO];
            [CoreDataDatabase commitChanges:nil];
            _shoppingItem = nil;
            [self _recoverCenterInputViewFromPreviewAnimated:YES];
        } else {
            if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                [FlurryAnalytics logEvent:@"Move items to new folder"];
            }

            [self _doMoveItems];
        }
        
        isMovingItem = NO;
    }

    editFolderItemSwitcher = nil;
    
    //Dismiss at last since viewWillAppear may do something else, e.g. clear selection
    [self dismissModalViewControllerAnimated:YES];
}
//--------------------------------------------------------------
//  [END] EditFolderViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] EditItemViewControllerDelegate
#pragma mark -
#pragma mark EditItemViewControllerDelegate Methods
//--------------------------------------------------------------
- (void)cancelEditItem:(id)sender
{
    [self dismissModalViewControllerAnimated:YES];
}

- (void)finishEditItem:(id)sender
{
    //Shopping item has been moved, remove it from database and list
    if(_shoppingItem) {
        [CoreDataDatabase removeShoppingItem:_shoppingItem updatePositionOfRestItems:NO];
        [CoreDataDatabase commitChanges:nil];
        _shoppingItem = nil;
    }

    [self _recoverCenterInputViewFromPreviewAnimated:NO];
    
    if(_currentPageVC.selectedFolderView) {
        _currentPageVC.selectedFolderView.imageView.isEmpty = [_currentPageVC isEmptyFolder:_currentPageVC.selectedFolder];
        [_currentPageVC clearSelection];
    }
    
    [self dismissModalViewControllerAnimated:YES];
}
//--------------------------------------------------------------
//  [END] EditItemViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] FolderEditModeDelegate
#pragma mark -
#pragma mark FolderEditModeDelegate Methods
//--------------------------------------------------------------
const static NSTimeInterval kCenterViewAnimateDuration = 0.25; 
- (void) didEnterFolderEditMode
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Enter folder edit mode"];
    }
    
    centerView = nil;
    if(!self.centerInputView.hidden) {
        centerView = self.centerInputView;
    } else if(!self.previewTextView.hidden) {
        centerView = self.previewTextView;
    } else {
        centerView = self.previewImageView;
    }
    
    centerView.userInteractionEnabled = NO;
    [UIView animateWithDuration:kCenterViewAnimateDuration
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionAllowUserInteraction
                     animations:^(void) {
                         centerView.alpha = kCenterViewEditAlpha;
                     }
                     completion:NULL];
    
    for(FolderPageViewController *pageVC in self.pageVCs) {
        pageVC.editing = YES;
    }
}

- (void) didLeaveFolderEditMode
{
    centerView = nil;
    if(!self.centerInputView.hidden) {
        centerView = self.centerInputView;
    } else if(!self.previewTextView.hidden) {
        centerView = self.previewTextView;
    } else {
        centerView = self.previewImageView;
    }
    
    centerView.userInteractionEnabled = YES;
    [UIView animateWithDuration:kCenterViewAnimateDuration
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionAllowUserInteraction
                     animations:^(void) {
                         centerView.alpha = 1;
                     }
                     completion:NULL];

    
    for(FolderPageViewController *pageVC in self.pageVCs) {
        pageVC.editing = NO;
    }
}

- (void)shouldEditFolder:(DBFolder *)folderData
{
    isMovingItem = NO;
    EditFolderViewController *editFodlerVC = [[EditFolderViewController alloc] initWithFolderData:folderData];
    editFodlerVC.delegate = self;
    
    UINavigationController *navcon = [[UINavigationController alloc] initWithRootViewController:editFodlerVC];
    
    [self presentModalViewController:navcon animated:YES];
}

- (void)shouldCreateFolderInPage:(int)page withNumber:(int)number
{
    isMovingItem = NO;
    
    DBFolder *newFolder = [CoreDataDatabase obtainTempFolder];
    newFolder.page = page;
    newFolder.number = number;
    EditFolderViewController *editFodlerVC = [[EditFolderViewController alloc] initToCreateFolderOnly:newFolder];
    editFodlerVC.delegate = self;
    
    UINavigationController *navcon = [[UINavigationController alloc] initWithRootViewController:editFodlerVC];
    
    [self presentModalViewController:navcon animated:YES];
}

- (void) askToDeleteFolder:(DBFolder *)folder view:(FolderView *)deleteView
{
    deleteFolderView = deleteView;
    deleteFolder = folder;
    
    if(!_deleteFolderAlertView) {
        _deleteFolderAlertView = [[UIAlertView alloc] initWithTitle:nil
                                                                 message:nil
                                                                delegate:self
                                                       cancelButtonTitle:NSLocalizedString(@"Delete", nil)
                                                       otherButtonTitles:NSLocalizedString(@"Cancel", nil), nil];
    }
    
    _deleteFolderAlertView.title = [NSString stringWithFormat:NSLocalizedString(@"Delete \"%@\"", nil), folder.name];
    _deleteFolderAlertView.message = [NSString stringWithFormat:
                                           NSLocalizedString(@"Delete \"%@\" will also delete all items inside.", nil), folder.name];
    [_deleteFolderAlertView show];
}
//--------------------------------------------------------------
//  [END] FolderEditModeDelegate
//==============================================================

//#ifdef _LITE_
////==============================================================
////  [BEGIN] AdWhirl Delegate
//#pragma mark -
//#pragma mark AdWhirl Delegate
////--------------------------------------------------------------
//- (NSString *)adWhirlApplicationKey
//{
//    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
//        return @"dcf7e421f3e342d69fd32f9d53e30aa8";
//    } else {
//        return nil;
//    }
//}
//
//- (UIViewController *)viewControllerForPresentingModalView
//{
//    return self;
//}
//
//- (void)adWhirlDidReceiveAd:(AdWhirlView *)adWhirlView
//{
//    self.loadADLabel.text = nil;
//    [UIView animateWithDuration:0.7
//                          delay:0
//                        options:UIViewAnimationOptionAllowUserInteraction
//                     animations:^{
//                         CGSize adSize = [adView actualAdSize];
//                         CGRect newFrame = adView.frame;
//                         newFrame.size.height = adSize.height; // fit the ad
//                         newFrame.size.width = adSize.width;
//                         newFrame.origin.x = (self.view.bounds.size.width - adSize.width)/2; // center
//                         adView.frame = newFrame;
//                         // ... adjust surrounding views here ...
//                     } completion:NULL];
//}
//
////TODO: return NO before released
//- (BOOL)adWhirlTestMode
//{
//    return NO;
//}
////--------------------------------------------------------------
////  [END] AdWhirl Delegate
////==============================================================
//#endif

//==============================================================
//  [BEGIN] Popover methods
#pragma mark -
#pragma mark Popover methods
//--------------------------------------------------------------
- (void)_showSearchPopover
{
    self.searchLabel.textColor = [UIColor colorWithWhite:1 alpha:0.25];
    self.searchLabel.highlighted = YES;
    static CGRect popoverFrame;
    if(_popoverView == nil) {
        popoverLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, popoverFrame.size.width, popoverFrame.size.height)];
        popoverLabel.lineBreakMode = UILineBreakModeTailTruncation;
        popoverLabel.numberOfLines = 2;
        popoverLabel.textAlignment = UITextAlignmentCenter;
        popoverLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
        popoverLabel.backgroundColor = [UIColor clearColor];
        popoverLabel.textColor = [UIColor whiteColor];
        
        UIFont *font = [UIFont systemFontOfSize:18];
        popoverLabel.font = font;
        
        UIViewController *viewCon = [[UIViewController alloc] init];
        viewCon.view = popoverLabel;
        
        popoverFrame = CGRectMake(searchArea.origin.x + 5, searchArea.origin.y,
                                  searchArea.size.width - 10,
                                  font.lineHeight * 2 + 10);    //Left 10 points space
        viewCon.contentSizeForViewInPopover = popoverFrame.size;
        
        _popoverView = [[WEPopoverController alloc] initWithContentViewController:viewCon];
    }
    
    NSString *searchTarget = ([_inputBasicInfo.name length] > 0) ? _inputBasicInfo.name : _inputBasicInfo.barcodeData;
    popoverLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Release finger to search:\n%@", nil), searchTarget];
    [_popoverView presentPopoverFromRect:popoverFrame
                                      inView:self.view
                    permittedArrowDirections:UIPopoverArrowDirectionDown
                                    animated:NO];
}
//--------------------------------------------------------------
//  [END] Popover methods
//==============================================================

//==============================================================
//  [BEGIN] UIAlertViewDelegate
#pragma mark -
#pragma mark UIAlertViewDelegate
//--------------------------------------------------------------
- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if(alertView == _deleteFolderAlertView) {
        if(buttonIndex == 1) {          //Cancel
            [_currentPageVC clearSelection];
            deleteFolder = nil;
            deleteFolderView = nil;
        } else if (buttonIndex == 0) {  //Delete
            [self _deleteFolder];
        }
    }
#ifdef _LITE_
    else {    //Lite version alerts
        if(temporaryAddingPage) {
            [self _removeLastPage];
            temporaryAddingPage = NO;
        }

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

//==============================================================
//  [BEGIN] Folder delete methods
#pragma mark -
#pragma mark Folder delete methods
//--------------------------------------------------------------
- (void)hudWasHidden
{
    _hud.delegate = nil;
    _hud = nil;
}

- (void)_deleteFolder
{
    [self _stopLoadingFolderImages];
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Delete folder" timed:YES];
    }

    self.view.userInteractionEnabled = NO;

    FolderView *folderView = [_currentPageVC.folderViews objectAtIndex:deleteFolder.number];
    [folderView.imageView hideShadowAnimated:NO];
    [_currentPageVC removeFolder:deleteFolder];
    [_candidateFolders removeObject:deleteFolder];
    [CoreDataDatabase removeFolderAndClearItems:deleteFolder];
    [CoreDataDatabase commitChanges:nil];
    
    if([_currentPageVC isEmptyPage]) {
        [self _removePageAtIndex:pageControl.currentPage];
    }
    
    [deleteFolderView reset];
    
    self.view.userInteractionEnabled = YES;
    [self.view setNeedsDisplay];
    
    deleteFolder = nil;
    deleteFolderView = nil;
    
    if(!self.previewImageView.hidden &&
       _shoppingItem == nil)
    {
        _moveDataList = nil; //Do it here since moving item will recover input view and then move item
        [self _recoverCenterInputViewFromPreviewAnimated:NO];
        self.centerInputView.alpha = kCenterViewEditAlpha;
    }
    
    [self _refreshFolderImagesContinuously:YES afterDelay:2.5f];
}
//--------------------------------------------------------------
//  [END] Folder delete methods
//==============================================================

//==============================================================
//  [BEGIN] Notification selectors
#pragma mark - Notification selectors
//--------------------------------------------------------------
- (void)_beginSchedulingNotifications
{
    [self _showHUDWithLabel:NSLocalizedString(@"Scheduling notifications", nil)
                   subLabel:NSLocalizedString(@"Please wait", nil)
                   animated:YES];
}

- (void)_notificationSchedulingFinished
{
    [_hud hide:YES];
}
//--------------------------------------------------------------
//  [END] Notification selectors
//==============================================================

//==============================================================
//  [BEGIN] EnterTextViewController delegate
#pragma mark -
#pragma mark EnterTextViewController delegate
//--------------------------------------------------------------
- (void)cancelEnteringText
{
    [self dismissModalViewControllerAnimated:YES];
}

- (void)finishEnteringText:(NSString *)text
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Input Data Type"
                   withParameters:[NSDictionary dictionaryWithObject:@"Text" forKey:@"Type"]];
    }

    _inputType = Unknown_Input;
    _inputBasicInfo = nil;
    _inputImage = nil;
    _shoppingItem = nil;

    if([text length] > 0) {
        _inputType = Text_Input;
        _inputBasicInfo = [CoreDataDatabase obtainTempItemBasicInfo];
        _inputBasicInfo.name = text;
//        [self _displayPreviewForTextInput:text];  //viewWillAppear will do this
    }

    [self dismissModalViewControllerAnimated:YES];
}

- (void)_displayPreviewForTextInput:(NSString *)text
{
    if([text length] == 0) {
        return;
    }
    
    DBItemBasicInfo *basicInfo = [CoreDataDatabase getItemBasicInfoByName:text shouldExcludeBarcode:NO];
    if(basicInfo != nil) {
        _inputBasicInfo = basicInfo;
    }

    [self _showPreviewCellWithItem:_inputBasicInfo];
    
    _candidateFolders = [NSMutableArray arrayWithArray:[CoreDataDatabase getFoldersContainsItemName:text]];
    [self _showCandidateFolderAnimated:YES];
}
//--------------------------------------------------------------
//  [END] EnterTextViewController delegate
//==============================================================
- (void)_showPreviewCellWithItem:(DBItemBasicInfo *)basicInfo
{
    if(basicInfo == nil) {
        return;
    }

    self.centerInputView.hidden = YES;
    
    _previewCell.imageView.image = [basicInfo getDisplayImage];

    if([basicInfo.name length] > 0) {
        _previewCell.textLabel.text = basicInfo.name;
    } else {
        _previewCell.textLabel.text = [StringUtil formatBarcode:basicInfo.barcode];
    }
    [_previewCell layoutSubviews];
    
    self.searchLabel.searchText = _previewCell.textLabel.text;
    self.previewTextView.hidden = NO;
    
    _canSearch = YES;//NO;
//    if(_inputType == Text_Input) {
//        _canSearch = ([CoreDataDatabase numberOfItemsContainName:_inputItem.name] > 0);
//    } else if(_inputType == Barcode_Input) {
//        _canSearch = ([CoreDataDatabase numberOfItemsWithBarcode:_inputItem.barcode] > 0);
//    }

    self.searchLabel.hidden = !_canSearch;
}

//==============================================================
//  [BEGIN] TutorialViewControllerDelegate delegate
#pragma mark - TutorialViewControllerDelegate delegate
//--------------------------------------------------------------
- (void)endTutorial
{
    [self dismissModalViewControllerAnimated:YES];
    [self _noticeBarcodeScanner];
}
//--------------------------------------------------------------
//  [END] TutorialViewControllerDelegate delegate
//==============================================================

- (void)_prepareMoveLabel
{
    if([_moveDataList count] == 0) {
        return;
    }

    SelectedFolderItem *data = [_moveDataList objectAtIndex:0];
    DBFolderItem *item = data.folderItem;

    if([item.basicInfo.name length] > 0) {
        _moveItemNameLabel.text = item.basicInfo.name;
    } else if(item.basicInfo.imageRawData == nil) {
        _moveItemNameLabel.text = [StringUtil formatBarcode:item.basicInfo.barcode];
    }
    
    _moveItemCountLabel.text = nil;
    int nMoveCount = 0;
    for(SelectedFolderItem *selectItem in _moveDataList) {
        nMoveCount += selectItem.selectCount;
    }
    
    if(nMoveCount > 0) {
        _moveItemCountLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Count: %d", nil), nMoveCount];
        CGRect frame = _moveItemCountLabel.frame;
        frame.origin.y = self.previewImageView.bounds.size.height - frame.size.height - 1;
        _moveItemCountLabel.frame = frame;
        
        frame.size.height = _moveItemNameLabel.frame.size.height;
        frame.origin.y = frame.origin.y - frame.size.height;
        _moveItemNameLabel.frame = frame;
    } else {
        CGRect frame = _moveItemNameLabel.frame;
        frame.origin.y = self.previewImageView.bounds.size.height - frame.size.height - 1;  //1 is for border
        _moveItemNameLabel.frame = frame;
    }
    
    [_itemMoveGradientLayer removeFromSuperlayer];
    if([_moveItemNameLabel.text length] > 0 ||
       [_moveItemCountLabel.text length] > 0)
    {
        [self _addGradientToMoveImageView];
    }
    
    [self _hideCandidateFolderAnimated:NO];
    
    //Hide other views
    self.centerInputView.hidden = YES;
    
    _inputBasicInfo = nil;
    self.previewTextView.hidden = YES;
    
    _inputImage = nil;
    _moveTitleForPreviewImage.text = NSLocalizedString(@"Drag To Move", nil);
    //If the item has an image, show cell or imageView
    self.previewImageView.image = [item.basicInfo getDisplayImage];
    if(self.previewImageView.image == nil) {
        self.previewImageView.image = [UIImage imageNamed:@"empty_move_image"];
    }
    self.previewImageView.hidden = NO;
}

- (void)moveItems:(NSArray *)movedData
{
    _shoppingItem = nil;
    [self _recoverCenterInputViewFromPreviewAnimated:NO];
    if([movedData count] == 0) {
        return;
    }
    
    _moveDataList = [NSMutableArray arrayWithArray:movedData];
    [self _prepareMoveLabel];
    
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)_noticeBarcodeScanner
{
    if(![HardwareUtil hasRearCam] ||
       [HardwareUtil canAutoFocus])
    {
        return;
    }

    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingShowTutorial] ||
       ![[NSUserDefaults standardUserDefaults] boolForKey:kSettingNoticeBarcodeScanner])
    {
        return;
    }
    
    UIAlertView *barcodeScannerAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Barcode Scanner Notice", nil)
                                                                  message:NSLocalizedString(@"The barcode scanner requires:\n\"Autofocus Camera.\"\nJust to notice that it may not work perfectly on this device.", nil)
                                                                 delegate:self
                                                        cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                                        otherButtonTitles:nil];
    [barcodeScannerAlert show];
    
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kSettingNoticeBarcodeScanner];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)_showHUDWithLabel:(NSString *)label subLabel:(NSString *)subLabel animated:(BOOL)animate
{
    if(_hud == nil) {
//#ifdef _LITE_
//        if(m_isADRemoved) {
//            _hud = [[MBProgressHUD alloc] initWithFrame:CGRectMake(0, 0, 320, 414)];
//        } else {
//            _hud = [[MBProgressHUD alloc] initWithFrame:CGRectMake(0, 0, 320, 364)];
//        }
//#else
//        _hud = [[MBProgressHUD alloc] initWithFrame:CGRectMake(0, 0, 320, 414)];
//#endif
        CGRect frame = self.centerInputView.frame;
        frame.size.width = 320.0f;
        frame.origin.x = 0.0f;
        _hud = [[MBProgressHUD alloc] initWithFrame:frame];
        _hud.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
        _hud.removeFromSuperViewOnHide = YES;
        _hud.delegate = self;
        [self.view addSubview:_hud];
    }

    _hud.labelText = label;
    _hud.detailsLabelText = subLabel;
    [_hud show:animate];
}

- (void)_doMoveItems
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Move items"
                   withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:[_moveDataList count]]
                                                              forKey:@"Count"]
                            timed:YES];
    }

    BOOL hasPartialMove = NO;
    NSMutableSet *modifiedFolders = [NSMutableSet set];
    [modifiedFolders addObject:_currentPageVC.selectedFolder];
    
    DBFolderItem *item;
    for(SelectedFolderItem *data in _moveDataList) {
        item = data.folderItem;
        [modifiedFolders addObject:item.folder];
        
        if(data.selectCount != item.count) {
            hasPartialMove = YES;
        }
        
        [CoreDataDatabase moveItem:item toFolder:_currentPageVC.selectedFolder withCount:data.selectCount];
    }
    [CoreDataDatabase commitChanges:nil];
    
    [FlurryAnalytics logEvent:@"Move Items - Has Partital"
               withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:hasPartialMove]
                                                          forKey:@"Has Partital Move"]];

    //We'll update this part in notification receiver.
    _moveDataList = nil;
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics endTimedEvent:@"Move items" withParameters:nil];
    }
    
    _currentPageVC.selectedFolderView.imageView.isEmpty = [_currentPageVC isEmptyFolder:_currentPageVC.selectedFolder];
    [_currentPageVC clearSelection];
    [self _refreshFolderImagesContinuously:YES afterDelay:0.0f];
    
    [self _recoverCenterInputViewFromPreviewAnimated:YES];
}

- (void)_showCandidateFolderAnimated:(BOOL)animate
{
    FolderPageViewController *pageVC;
    FolderView *folderView;
    for(DBFolder *folder in _candidateFolders) {
        pageVC = [self.pageVCs objectAtIndex:folder.page];
        folderView = [pageVC.folderViews objectAtIndex:folder.number];
        [folderView.imageView showShadowAnimated:animate];
    }
}

- (void)_hideCandidateFolderAnimated:(BOOL)animate
{
    FolderPageViewController *pageVC;
    FolderView *folderView;
    for(DBFolder *folder in _candidateFolders) {
        pageVC = [self.pageVCs objectAtIndex:folder.page];
        folderView = [pageVC.folderViews objectAtIndex:folder.number];
        [folderView.imageView hideShadowAnimated:animate];
    }
    _candidateFolders = nil;
}

- (void)_addGradientToMoveImageView
{
    [_itemMoveGradientLayer removeFromSuperlayer];
    _itemMoveGradientLayer = [CAGradientLayer layer];
    _itemMoveGradientLayer.frame = previewImageView.bounds;
    _itemMoveGradientLayer.colors = [NSArray arrayWithObjects:
                                     (id)[UIColor clearColor].CGColor,
                                     (id)[UIColor clearColor].CGColor,
                                     (id)[UIColor colorWithWhite:0.0f alpha:0.5f].CGColor,
                                     nil];

    float moveNameRatio = (_moveItemNameLabel.frame.size.height + _moveItemCountLabel.frame.size.height)/self.previewImageView.bounds.size.height;
    _itemMoveGradientLayer.locations = [NSArray arrayWithObjects:
                                        [NSNumber numberWithFloat:0.0f],
                                        [NSNumber numberWithFloat:(1.0f - moveNameRatio)*0.9f],
                                        [NSNumber numberWithFloat:1.0f],
                                        nil];
    [previewImageView.layer insertSublayer:_itemMoveGradientLayer atIndex:0];
    [self.previewImageView.layer insertSublayer:_itemMoveGradientLayer below:_moveItemNameLabel.layer];
}

- (void)_refreshFolderImagesContinuously:(BOOL)continuously afterDelay:(NSTimeInterval)delay
{
    _refreshFolderImagesEnabled = YES;
    NSNumber *isContinue = [NSNumber numberWithBool:continuously];
    for(FolderPageViewController *pageVC in pageVCs) {
        [pageVC stopLoadingImages];
        
        if(delay > 0.0f) {
            [pageVC performSelector:@selector(refreshFolderImagesContinuously:) withObject:isContinue afterDelay:delay];
        } else {
            [pageVC refreshFolderImagesContinuously:isContinue];
        }
    }
}

- (void)_stopLoadingFolderImages
{
    _refreshFolderImagesEnabled = NO;
    for(FolderPageViewController *pageVC in pageVCs) {
        [pageVC stopLoadingImages];
    }
}
//==============================================================
//  [BEGIN] Notification Handlers
#pragma mark - Notification Handlers
//--------------------------------------------------------------
- (void)_receiveApplicationWillResignActiveNotification:(NSNotification *)notif
{
    if((int)self.pageScrollView.contentOffset.x % 320 != 0) {
        // Switch the indicator when more than 50% of the previous/next page is visible
        CGFloat pageWidth = pageScrollView.frame.size.width;
        int page = floor((pageScrollView.contentOffset.x - pageWidth / 2) / pageWidth);// + 1;
        
        CGPoint offset = self.pageScrollView.contentOffset;
        offset.x = pageWidth * (page+1);
        self.pageScrollView.contentOffset = offset;
        
        // load the visible page and the page on either side of it (to avoid flashes when the user starts scrolling)
        if(page < 0) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kIsInShoppingList];
            [[NSUserDefaults standardUserDefaults] synchronize];
        } else {
            pageControl.currentPage = page;
            _currentPageVC = [self.pageVCs objectAtIndex:pageControl.currentPage];
            
            [[NSUserDefaults standardUserDefaults] setInteger:page forKey:kCurrentPage];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
}

- (void)_receivePageScrollEnableNotification:(NSNotification *)notif
{
    self.pageScrollView.scrollEnabled = YES;
}

- (void)_receivePageScrollDisableNotification:(NSNotification *)notif
{
    self.pageScrollView.scrollEnabled = NO;
}

- (void)_receiveStatusFrameDidChangeNotification:(NSNotification *)notif
{
    searchArea = [self.searchLabel convertRect:self.searchLabel.bounds toView:self.view];
}

- (void)_receiveManagedObjectDidChangeNotification:(NSNotification *)notif
{
    NSDictionary *userInfo = notif.userInfo;
    DBFolderItem *folderItem;
    NSDictionary *changedValues;
    
    //ATTENTION PLEASE!!
    //DO NOT change folder status includes expiry badges and images, they will be handled in each page
    
//    NSSet *insertedObjects = [userInfo objectForKey:NSInsertedObjectsKey];
//    for(NSManagedObject *object in insertedObjects) {
//        if([object class] == [DBFolderItem class]) {
//            folderItem = (DBFolderItem *)object;
//        }
//    }
    
    NSSet *deletedObjects = [userInfo objectForKey:NSDeletedObjectsKey];
    for(NSManagedObject *object in deletedObjects) {
        if([object class] == [DBShoppingItem class]) {
            if(_shoppingItem != nil &&
               _shoppingItem == object)
            {
                [self _recoverCenterInputViewFromPreviewAnimated:NO];
            }
        }
    }
    
    NSSet *updatedObjects = [userInfo objectForKey:NSUpdatedObjectsKey];
    BOOL needUpdateMoveLabel = NO;
    for(NSManagedObject *object in updatedObjects) {
        if([object class] == [DBFolderItem class]) {
            folderItem = (DBFolderItem *)object;
            changedValues = [object changedValues];
            
            //Update count of moving items
            needUpdateMoveLabel = NO;
            if([changedValues valueForKey:kAttrCount] &&
               [_moveDataList count] > 0 &&
               _shoppingItem == nil)
            {
                for(SelectedFolderItem *movingItem in _moveDataList) {
                    if([movingItem.folderItem.objectID.URIRepresentation isEqual:folderItem.objectID.URIRepresentation] &&
                       movingItem.selectCount > folderItem.count)
                    {
                        movingItem.selectCount = folderItem.count;
                        needUpdateMoveLabel = YES;
                    }
                }
            }
        } else if([object class] == [DBItemBasicInfo class]) {
            if(_shoppingItem != nil &&
               _shoppingItem.basicInfo == object)
            {
                [self _prepareMoveLabel];   //Update UI
            }
        }
    }

    if(needUpdateMoveLabel) {
        [self _prepareMoveLabel];
    }
}

- (void)_receiveMoveItemNotification:(NSNotification *)notif
{
    [self.navigationController popToRootViewControllerAnimated:YES];
    
    NSArray *selectedItems = [notif.userInfo objectForKey:kSelectedItemsToMove];
    [self moveItems:selectedItems];
}
//--------------------------------------------------------------
//  [END] Notification Handlers
//==============================================================

- (IBAction)purchasePressed:(id)sender
{
    InAppPurchaseViewController *iapVC = [[InAppPurchaseViewController alloc] init];
    iapVC.delegate = self;
    [self presentModalViewController:iapVC animated:YES];
}

- (IBAction)favoriteButtonPressed:(id)sender
{
    FavoriteListViewController *favoriteVC = [FavoriteListViewController new];
    favoriteVC.delegate = self;
    
    UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:favoriteVC];
    [self presentViewController:navCon animated:YES completion:NULL];
}

- (void)_checkPurchaseAndAdjustUI
{
    m_isUnlimited = [[NSUserDefaults standardUserDefaults] boolForKey:kPurchaseUnlimitCount];
//    if(!m_isADRemoved) {
//        m_isADRemoved = [[NSUserDefaults standardUserDefaults] boolForKey:kPurchaseRemoveAD];
//        if(m_isADRemoved) {
//            for(FolderPageViewController *pageVC in self.pageVCs) {
//                [pageVC.view removeFromSuperview];
//            }
//            [self.pageVCs removeAllObjects];
//            [shoppingListNavCon.view removeFromSuperview];
//            shoppingListNavCon = nil;
//            _shoppingListVC = nil;
//            
//            self.pageScrollView.frame = CGRectMake(0, 0, 320, 460);
//
//            self.itemMoveView.frame = CGRectMake(60, 154, 200, 124);
//            [self _addGradientToMoveImageView];
//
//            self.previewTextView.frame = CGRectMake(40, 151, 240, 130);
//                self.searchLabel.frame = CGRectMake(0, 76, 240, 54);
//            searchArea = [self.searchLabel convertRect:self.searchLabel.bounds toView:self.view];
//
//            self.previewImageView.frame = CGRectMake(80, 136, 160, 160);
//            CGRect frame = _moveTitleForPreviewImage.frame;
//            frame.size.width = self.previewImageView.frame.size.width;
//            _moveTitleForPreviewImage.frame = frame;
//
//            self.centerInputView.frame = CGRectMake(90, 146, 146, 146);
//                self.scanBarcodeButton.frame = CGRectMake(0, 0, 64, 64);
//                self.takePhotoButton.frame = CGRectMake(76, 0, 64, 64);
//                self.pickImageButton.frame = CGRectMake(0, 76, 64, 64);
//                self.enterTextButton.frame = CGRectMake(76, 76, 64, 64);
//
//            self.pageControl.frame = CGRectMake(141, 424, 38, 36);
//            self.infoButton.frame = CGRectMake(282, 421, 18, 18);
//            if(!m_isUnlimited) {
//                self.purchaseButton.frame = CGRectMake(20, 419, 22, 22);
//            }
//            
//            [self.loadADLabel removeFromSuperview];
//            self.loadADLabel = nil;
//            self.adView.delegate = nil;
//            [self.adView removeFromSuperview];
//            self.adView = nil;
//            
//            _previewCell.frame = CGRectMake(0, 0, self.previewTextView.frame.size.width, kFolderViewSizeNoAD);
//            _moveCell.frame = CGRectMake(0, self.itemMoveView.frame.size.height-kFolderViewSizeNoAD,
//                                         self.itemMoveView.frame.size.width, kFolderViewSizeNoAD);
//            [self reloadPages];
//            if([_moveDataList count] > 0) {
//                [self _prepareMoveLabel];
//            }
//        }
//    }
    
    if(/*m_isADRemoved && */m_isUnlimited) {
        //Remove purchase button
        [self.purchaseButton removeFromSuperview];
        self.purchaseButton = nil;
    } else {
        self.purchaseButton.hidden = NO;
    }
}

//==============================================================
//  [BEGIN] InAppPurchaseViewControllerDelegate
#pragma mark - InAppPurchaseViewControllerDelegate
//--------------------------------------------------------------
- (void)finishIAP
{
    [self _checkPurchaseAndAdjustUI];
    
    [self dismissModalViewControllerAnimated:YES];
}
//--------------------------------------------------------------
//  [END] InAppPurchaseViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] ShoppingListViewControllerDelegate
#pragma mark - ShoppingListViewControllerDelegate
//--------------------------------------------------------------
- (void)shoppingItemBeginsToMove:(DBShoppingItem *)shoppingItem
{
    _shoppingItem = shoppingItem;
    DBFolderItem *item = [CoreDataDatabase obtainTempFolderItemFromShoppingItem:_shoppingItem];
    
    SelectedFolderItem *data = [[SelectedFolderItem alloc] initWithFolderItem:item];
    _moveDataList = [NSMutableArray arrayWithObject:data];
    [self _prepareMoveLabel];
    
    UIView *animateView = nil;
    if(!self.previewImageView.hidden &&
       centerView != self.previewImageView)
    {
        animateView = self.previewImageView;
    }
    
    animateView.alpha = 0.0f;
    animateView.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
    [UIView animateWithDuration:0.5f
                     animations:^{
                         animateView.transform = CGAffineTransformIdentity;
                         animateView.alpha = 1.0f;
                     }];
    
    self.pageScrollView.scrollEnabled = YES;
    self.pageScrollView.bounces = YES;
    [self _changeToPage:0 animated:YES];
    
    if(!_refreshFolderImagesEnabled) {
        [self _refreshFolderImagesContinuously:YES afterDelay:0.0f];
    }
}
//--------------------------------------------------------------
//  [END] ShoppingListViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] FavoriteListViewControllerDelegate
#pragma mark - FavoriteListViewControllerDelegate
//--------------------------------------------------------------
- (void)didSelectItemBasicInfo:(DBItemBasicInfo *)basicInfo
{
    _moveDataList = nil;
    _shoppingItem = nil;
    [self _recoverCenterInputViewFromPreviewAnimated:NO];
    
    _inputType = Favorite_Input;
    _inputBasicInfo = basicInfo;
    UIView *animateView = nil;
    if([_inputBasicInfo.name length] > 0 ||
       [_inputBasicInfo.barcodeData length] > 0)
    {
        [self _showPreviewCellWithItem:_inputBasicInfo];
        animateView = self.previewTextView;
    } else {
        self.previewImageView.image = [_inputBasicInfo getDisplayImage];
        _moveTitleForPreviewImage.text = NSLocalizedString(@"Drag To Add", nil);
        self.previewImageView.hidden = NO;
        self.centerInputView.hidden = YES;
        animateView = self.previewImageView;
    }
    
    if(!self.previewImageView.hidden &&
       centerView != self.previewImageView)
    {
        animateView = self.previewImageView;
    }
    
    animateView.alpha = 0.0f;
    animateView.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
    [UIView animateWithDuration:0.5f
                     animations:^{
                         animateView.transform = CGAffineTransformIdentity;
                         animateView.alpha = 1.0f;
                     }];
    
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)shouldDismissFavoriteList
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}
//--------------------------------------------------------------
//  [END] FavoriteListViewControllerDelegate
//==============================================================

- (BOOL)shouldShowExpiryList
{
    if([[NSUserDefaults standardUserDefaults] integerForKey:kLastExpiryListShowTime] >= [[TimeUtil today] timeIntervalSinceReferenceDate]) {
        //Expiry list has been shown today
        return NO;
    }
    
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

- (void)showExpireListAnimated:(BOOL)animate
{
    ExpiryListViewController *listVC = [ExpiryListViewController new];
    listVC.delegate = self;
    UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:listVC];
    [self presentViewController:navCon animated:animate completion:nil];
}

//==============================================================
//  [BEGIN] ExpiryListViewControllerDelegate
#pragma mark - ExpiryListViewControllerDelegate
//--------------------------------------------------------------
- (void)expiryListShouldDismiss
{
    [self dismissViewControllerAnimated:YES completion:nil];
}
//--------------------------------------------------------------
//  [END] ExpiryListViewControllerDelegate
//==============================================================

@end
