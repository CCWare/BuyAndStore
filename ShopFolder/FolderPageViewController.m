//
//  FolderViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/09/12.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import "FolderPageViewController.h"
#import "CoreDataDatabase.h"
#import "StringUtil.h"
#import "NotificationConstant.h"
#import "TimeUtil.h"
#import "UIApplication+BadgeUpdate.h"
#import "PreferenceConstant.h"
#import "FlurryAnalytics.h"
#import "DBItemBasicInfo+SetAdnGet.h"

#import "DBFolder+isEmpty.h"
#import "DBFolder+SetAndGet.h"
#import "DBFolderItem+expiryOperations.h"

#define kLongPressDuration          1.0
#define kLongPressDurationInEditing 0.25

#define kLoadImageInterval          5.0f

@interface FolderPageViewController ()
- (void)_handleLongPress:(UILongPressGestureRecognizer *)sender;
- (void)_handleTap:(UITapGestureRecognizer *)sender;
- (void)_handleTapForPage:(UITapGestureRecognizer *)sender;
- (void)_tapOnDeleteBadge:(UITapGestureRecognizer *)sender;

- (void)_showUnlockAlert;
- (void)_showItemListInFolder:(DBFolder *)folder;
- (void)_updateEmptynessOfFolder:(DBFolder *)folder;

- (void)_refreshExpireCountOfAllFolders;
- (void)_refreshExpireCountOfChangedFolders;
- (void)_refreshExpireCountOfFolder:(NSNumber *)folderNunmber;

- (void)_receiveSignificantTimeChangeNotification:(NSNotification *)notification;
- (void)_receiveMangedObjectDidChangeNotification:(NSNotification *)notification;

- (void)_genLoadImageQueue;
@end

@implementation FolderPageViewController

@synthesize folder1;
@synthesize folder2;
@synthesize folder3;
@synthesize folder4;
@synthesize folder5;
@synthesize folder6;
@synthesize folderViews;

@synthesize page=_page;
@synthesize selectedFolderView=_selectedFolderView;
@synthesize selectedFolder;

@synthesize editing;

@synthesize clickOnFolderDelegate;
@synthesize folderEditModeDelegate;
@synthesize pageTappedDelegate;

- (id)initWithPageNumber:(int)page
{
    CGFloat screenHeight = [[UIScreen mainScreen] bounds].size.height;
    if(screenHeight == 568) {
        self = [super initWithNibName:@"FolderPageViewController-568h" bundle:nil];
    } else {
        self = [super initWithNibName:@"FolderPageViewController" bundle:nil];
    }
    
    if(self) {
        _page = page;
        _changedFolderNumbers = [NSMutableIndexSet indexSet];
    }
    
    return self;
}

- (DBFolder *)selectedFolder
{
    if(self.selectedFolderView == nil ||
       self.selectedFolderView.tag < 0 ||
       self.selectedFolderView.tag > kFolderPerPage)
    {
        return nil;
    }
 
    return folderDataArray[self.selectedFolderView.tag];
}

- (void)viewDidUnload
{
    [super viewDidUnload];

    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    dispatch_release(_loadImageQueue);
    _loadImageQueue = nil;
    
    self.folder1 = nil;
    self.folder2 = nil;
    self.folder3 = nil;
    self.folder4 = nil;
    self.folder5 = nil;
    self.folder6 = nil;

    _passwordAlertView = nil;
    _passwordField = nil;
    _folderPositions = nil;
    _folderImageFrames = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationSignificantTimeChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextObjectsDidChangeNotification object:nil];
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
    
    // Do any additional setup after loading the view from its nib.
    folderViews = [NSArray arrayWithObjects:folder1, folder2, folder3, folder4, folder5, folder6, nil];
    memset(folderDataArray, 0, sizeof(DBFolder *)*kFolderPerPage);
    
    _folderPositions = [NSMutableArray array];
    _folderImageFrames = [NSMutableArray array];
    
    UITapGestureRecognizer *editModeTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTapForPage:)];
    editModeTapGR.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:editModeTapGR];

    NSUInteger nFolderNumber = 0;
    DBFolder *folder = nil;
    for(FolderView *folderView in folderViews) {
        folderView.imageView.exclusiveTouch = YES;
        folderView.tag = nFolderNumber;
        folderView.imageView.isEmpty = YES; //check later
        
        [_folderPositions addObject:[NSValue valueWithCGPoint:folderView.frame.origin]];
        [_folderImageFrames addObject:[NSValue valueWithCGRect:
                                            [folderView.imageView convertRect:folderView.imageView.frame toView:self.view]]];

        folder = [CoreDataDatabase getFolderInPage:self.page withNumber:nFolderNumber];
        folderDataArray[nFolderNumber] = folder;
        if(folder != nil) {
            folderView.label.text = folder.name;
            folderView.locked = ([folder.password length] > 0);
            folderView.imageView.isEmpty = [folder isEmpty];
            folderView.expiredBadgeNumber = [CoreDataDatabase totalExpiredItemsInFolder:folder within:0];
            folderView.nearExpiredBadgeNumber = [CoreDataDatabase totalNearExpiredItemsInFolder:folder];
        }
        
        UILongPressGestureRecognizer *longPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                                  action:@selector(_handleLongPress:)];
        longPressGR.minimumPressDuration = kLongPressDuration;
        longPressGR.cancelsTouchesInView = NO;
        [folderView.imageView addGestureRecognizer:longPressGR];
        
        UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTap:)];
        tapGR.cancelsTouchesInView = NO;
        tapGR.numberOfTapsRequired = 1;
        [folderView.imageView addGestureRecognizer:tapGR];
        
        tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tapOnDeleteBadge:)];
        tapGR.cancelsTouchesInView = NO;
        tapGR.numberOfTapsRequired = 1;
        [folderView.deleteBadge addGestureRecognizer:tapGR];
        
        nFolderNumber++;
    }
    
    //Add notofication listerner
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_receiveSignificantTimeChangeNotification:)
                                                 name:UIApplicationSignificantTimeChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_receiveMangedObjectDidChangeNotification:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:nil];
    
    [self _genLoadImageQueue];
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [_folderImageFrames removeAllObjects];
    for(FolderView *folderView in folderViews) {
        [_folderImageFrames addObject:[NSValue valueWithCGRect:
                                       [folderView.imageView convertRect:folderView.imageView.frame toView:self.view]]];
    }
}

- (void)stopLoadingImages
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshFolderImagesContinuously:) object:_isContinueToLoadImages];
    _stopLoadingImages = YES;
}

- (void)refreshFolderImagesAnimated:(BOOL)animate
{
#ifdef DEBUG
    if(animate &&
       dispatch_get_current_queue() == dispatch_get_main_queue())
    {
        NSLog(@"[WARNING] Animate folder images in main thread may freeze.");
    }
#endif
    
    NSMutableArray *folderObjectIDs = [NSMutableArray array];
    for(int nIndex = 0; nIndex < kFolderPerPage; nIndex++) {
        if(folderDataArray[nIndex].objectID) {
            [folderObjectIDs addObject:folderDataArray[nIndex].objectID];
        } else {
            [folderObjectIDs addObject:[NSNull null]];
        }
    }
    
    //Get MOC everytime here for getting most recently updated contents
    NSManagedObjectContext *moc = [CoreDataDatabase getContextForCurrentThread];
    
    NSManagedObjectID *folderObjectID;
    DBFolder *folder;
    int nImageIndex;
    NSArray *circledFolderViews = [NSArray arrayWithObjects:folder1, folder2, folder3, folder6, folder5, folder4, nil];
    NSMutableArray *images = [NSMutableArray array];
    NSMutableArray *shouldAnimate = [NSMutableArray array];
    for(int nIndex = 0; nIndex < kFolderPerPage; nIndex++) {
        [images addObject:[NSNull null]];
        [shouldAnimate addObject:[NSNumber numberWithBool:NO]];
    }
    
    FolderView *folderView;
    _stopLoadingImages = NO;
    NSManagedObjectID *objectID;
    NSURL *newBasicInfoURLOfImages[kFolderPerPage] = {NULL};    //Save new image URL when it takes effect later
    UIImage *image;
    DBItemBasicInfo *basicInfo;
    
    //Here we collect all images and display later
    for(folderView in circledFolderViews) {
        @autoreleasepool {
            folderObjectID = [folderObjectIDs objectAtIndex:folderView.tag];
            if([folderObjectID isEqual:[NSNull null]]) {
                continue;
            }
            
            folder = (DBFolder *)[CoreDataDatabase getObjectByID:folderObjectID inContext:moc];
            if([folder getDisplayImage] != nil) {
                [images replaceObjectAtIndex:folderView.tag withObject:folder.displayImage];
                continue;
            }
            
            //Only use item image when the folder is not locked or has no image
            if(folder == nil ||
               [folder.items count] == 0)
            {
                continue;
            }
            
            if([folder.password length] == 0) {
                NSArray *basicInfoObjectIDs = nil;
                if(folderView.expiredBadgeNumber > 0) {
                    basicInfoObjectIDs = [CoreDataDatabase getImagesOfExpiredItemsInFolder:folder];
                }
                
                if([basicInfoObjectIDs count] == 0) {
                    basicInfoObjectIDs = [CoreDataDatabase getBasicInfoIDsWithImageInFolder:folder];
                }
                
                if([basicInfoObjectIDs count] == 0) {
                    folderView.imageView.image = nil;
                    continue;
                }
                
                if([basicInfoObjectIDs count] == 1) {
                    objectID = [basicInfoObjectIDs objectAtIndex:0];
                } else {
                    if(animate) {
                        [shouldAnimate replaceObjectAtIndex:folderView.tag withObject:[NSNumber numberWithBool:YES]];
                    }
                    
                    nImageIndex = rand() % [basicInfoObjectIDs count];
                    objectID = [basicInfoObjectIDs objectAtIndex:nImageIndex];
                    
                    //"isEqual" cannot compare objectID
                    if([[objectID URIRepresentation] isEqual:_currentBasicInfoURLOfImages[folderView.tag]]) {
                        nImageIndex++;
                        if(nImageIndex >= [basicInfoObjectIDs count]) {
                            nImageIndex = 0;
                        }
                        
                        objectID = [basicInfoObjectIDs objectAtIndex:nImageIndex];
                    }
                }
                
                newBasicInfoURLOfImages[folderView.tag] = [objectID URIRepresentation];
                basicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:objectID inContext:moc];
                
                //Image may be nil for thread
                image = [basicInfo getDisplayImage];
                if(image) {
                    [images replaceObjectAtIndex:folderView.tag withObject:image];
                }
            }
            
            if(_stopLoadingImages) {
                return;
            }
        }   //end of @autoreleasepool
    }   //end of for(folderView...
    
    //Display images
    for(folderView in circledFolderViews) {
        if(_stopLoadingImages) {
            return;
        }
        
        if(![[images objectAtIndex:folderView.tag] isEqual:[NSNull null]]) {
            folderView = [folderViews objectAtIndex:folderView.tag];
            
            [folderView.imageView exchangeImage:[images objectAtIndex:folderView.tag]
                                       animated:[[shouldAnimate objectAtIndex:folderView.tag] boolValue]];
            
            //Save new image URL only when it takes effect
            _currentBasicInfoURLOfImages[folderView.tag] = newBasicInfoURLOfImages[folderView.tag];
        }
        
        if(animate) {
            [NSThread sleepForTimeInterval:0.1f];
        }
    }
}

- (void)refreshFolderImagesContinuously:(NSNumber *)isContinue
{
    [self stopLoadingImages];
    
    if(!self.view.window) {
        //Not to animate if not visible
        return;
    }
    
    dispatch_async(_loadImageQueue, ^(void) {
        [self refreshFolderImagesAnimated:YES];
    });
    
    _isContinueToLoadImages = isContinue;
    if([isContinue boolValue]) {
        [self performSelector:@selector(refreshFolderImagesContinuously:) withObject:_isContinueToLoadImages afterDelay:kLoadImageInterval];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (BOOL)isOverlapToFolder:(CGPoint)position
{
    static int nLastOverlapIndex = kNoFolderSelectedNumber;

    BOOL hasOverlapped = NO;
    NSUInteger folderIndex = 0;
    FolderView *folderView = nil;
    for (NSValue *imagFrame in _folderImageFrames) {
        folderView = [folderViews objectAtIndex:folderIndex];

        if(hasOverlapped) {
            [folderView setFocused:NO animated:YES];
        } else {
            if(CGRectContainsPoint([imagFrame CGRectValue], position)) {
                hasOverlapped = YES;
                if(nLastOverlapIndex < 0 ||
                   nLastOverlapIndex != folderIndex)
                {
                    nLastOverlapIndex = folderIndex;
                    _selectedFolderView = folderView;
                    [folderView setFocused:YES animated:YES];
                }
            } else {
                [folderView setFocused:NO animated:YES];
            }
        }
        
        folderIndex++;
    }

    if(!hasOverlapped) {
        nLastOverlapIndex = kNoFolderSelectedNumber;
        [self clearSelection];
    }

    return hasOverlapped;
}

- (BOOL)isEmptyPage
{
    for(int nIndex = 0; nIndex < kFolderPerPage; nIndex++) {
        if([CoreDataDatabase getFolderInPage:self.page withNumber:nIndex]) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)isEmptyFolder:(DBFolder *)folder
{
    return (folder == nil || [folder isEmpty]);
}

- (void)selectEmptyFolder
{
    //If user has select another folder then ignores the request
    if(self.selectedFolderView != nil) {
        return;
    }
    
    for(int nIndex = 0; nIndex < kFolderPerPage; nIndex++) {
        if(folderDataArray[nIndex] == nil) {
            _selectedFolderView = [folderViews objectAtIndex:nIndex];
            break;
        }
    }
}

- (void)clearSelection
{
    if(self.selectedFolderView) {
        [self.selectedFolderView setFocused:NO animated:YES];
    }
    
    _selectedFolderView = nil;
}

- (void)changePageNumber:(int)newPage
{
    _page = newPage;
    DBFolder *folder;
    for(int nIndex = 0; nIndex < kFolderPerPage; nIndex++) {
        folder = folderDataArray[nIndex];
        if(folder) {
            folder.page = newPage;
        }
    }

    [CoreDataDatabase commitChanges:nil];
    
    [self _genLoadImageQueue];
}

- (void)addFolder:(DBFolder *)folder
{
    if(folder == nil ||
       folder.page != self.page ||
       folder.number < 0 ||
       folder.number >= kFolderPerPage)
    {
        return;
    }
    
    folderDataArray[folder.number] = folder;
}

- (void)removeFolder:(DBFolder *)folder
{
    if(folder == nil ||
       folder.page != self.page ||
       folder.number < 0 ||
       folder.number >= kFolderPerPage)
    {
        return;
    }
    
    folderDataArray[folder.number] = nil;
    _currentBasicInfoURLOfImages[folder.number] = NULL;
}

//==============================================================
//  [BEGIN] UIGestureRecognizerDelegate
//--------------------------------------------------------------
#pragma mark -
#pragma mark UIGestureRecognizerDelegate
- (void)setEditing:(BOOL)isEditing
{
    if(editing == isEditing) {
        return;
    }
    editing = isEditing;
    
    DBFolder *folder;
    FolderView *folderView;
    for(int nIndex = 0; nIndex < kFolderPerPage; nIndex++) {
        folder = folderDataArray[nIndex];
        
//        if(folder) {  //We comment this for user to create a new folder directly
            folderView = [folderViews objectAtIndex:nIndex];
            folderView.editing = editing;
            
            if(editing) {
                if(folder) {
                    folderView.deleteBadge.hidden = NO;
                }
            } else {
                [folderView.deleteBadge setHidden:YES animated:YES];
            }
            
            NSArray *GRs = folderView.gestureRecognizers;
            for(UIGestureRecognizer *gr in GRs) {
                if([gr isKindOfClass:[UILongPressGestureRecognizer class]]) {
                    ((UILongPressGestureRecognizer *)gr).minimumPressDuration = (isEditing) ? kLongPressDurationInEditing : kLongPressDuration;
                    break;
                }
            }
//        }
    }
}

- (void) _handleLongPress: (UILongPressGestureRecognizer *)sender
{
    if(!self.editing) {
        [self.folderEditModeDelegate didEnterFolderEditMode];
        self.editing = YES;
    }

    FolderView *folderView = (FolderView *)[sender.view superview];
    if(sender.state == UIGestureRecognizerStateBegan) {
        _selectedFolderView = folderView;
        [folderView setFocused:YES animated:YES];
    } else if(sender.state == UIGestureRecognizerStateEnded) {
        [self clearSelection];
        [folderView setFocused:NO animated:YES];
    }
}

- (void)_handleTap:(UITapGestureRecognizer *)sender
{
    if(sender.state != UIGestureRecognizerStateRecognized) {
        return;
    }
    
    FolderView *folderView = (FolderView *)[sender.view superview];
    _selectedFolderView = folderView;
    DBFolder *folder = folderDataArray[folderView.tag];
    
    if(folder) {
        if([folder.password length] > 0) {
            [self _showUnlockAlert];
        } else {
            if(folderView.editing) {
                [self.folderEditModeDelegate shouldEditFolder:folder];
            } else if(![folder isEmpty]) {
                [self _showItemListInFolder:folder];
            }
            //[self clearSelection]; DO NOT clearSelection here since the folder may be updated by its content
        }
    } else if(self.editing) {
        [self.folderEditModeDelegate shouldCreateFolderInPage:self.page withNumber:folderView.tag];
    }
}

- (void)_tapOnDeleteBadge:(UITapGestureRecognizer *)sender
{
    if(sender.state != UIGestureRecognizerStateRecognized) {
        return;
    }
    
    FolderView *folderView = (FolderView *)[sender.view superview];
    folderView.deleteBadge.highlighted = YES;
    DBFolder *folder = folderDataArray[folderView.tag];
    [self.folderEditModeDelegate askToDeleteFolder:folder view:folderView];
}

- (void)_handleTapForPage:(UITapGestureRecognizer *)sender
{
    if(self.editing) {
        self.editing = NO;
        [self.folderEditModeDelegate didLeaveFolderEditMode];
    } else {
        [self.pageTappedDelegate pageDidTapped:self];
    }
}
//--------------------------------------------------------------
//  [END] UIGestureRecognizerDelegate
//==============================================================

//==============================================================
//  [BEGIN] UIAlertViewDelegate
//--------------------------------------------------------------
#pragma mark -
#pragma mark UIAlertViewDelegate
- (void) alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    //Make kayboard disappears earlier
    [_passwordField resignFirstResponder];
}

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if(alertView == _passwordAlertView) {
        if(buttonIndex == 0) {          //Cancel
            [self clearSelection];
            _passwordField = nil;
            _passwordAlertView = nil;
        } else if (buttonIndex == 1) {  //Enter
            DBFolder *folder = self.selectedFolder;
            if([folder.password isEqualToString:_enteredPassword]) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kIsInProtectedFolder];
                [[NSUserDefaults standardUserDefaults] synchronize];

                if(self.selectedFolderView.editing) {
                    [self.folderEditModeDelegate shouldEditFolder:folder];
                } else {
                    [self _showItemListInFolder:folder];
                }
                //[self clearSelection]; DO NOT clearSelection here since the folder may be updated by its content

                _passwordField = nil;
                _passwordAlertView = nil;
            } else {
                UIAlertView *alertNotMatch = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Wrong Password", nil)
                                                                        message:NSLocalizedString(@"Try again?", nil)
                                                                       delegate:self
                                                              cancelButtonTitle:NSLocalizedString(@"No", nil)
                                                              otherButtonTitles:NSLocalizedString(@"Yes", nil), nil];
                [alertNotMatch show];
            }
        }

        _passwordField.text = nil;
        _enteredPassword = nil;
    } else {    //From Retry alert view
        if(buttonIndex == 1) {
            [_passwordField becomeFirstResponder];
            [_passwordAlertView show];
        } else {
            _passwordField = nil;
            _passwordAlertView = nil;
        }
    }
}

//--------------------------------------------------------------
//  [END] UIAlertViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] UITextFieldDelegate
#pragma mark -
#pragma mark UITextFieldDelegate Methods
//--------------------------------------------------------------
- (BOOL) textFieldShouldEndEditing:(UITextField *)textField
{
    _enteredPassword = textField.text;
    return YES;
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField
{
    [_passwordAlertView dismissWithClickedButtonIndex:1 animated:YES];
    return YES;
}
//--------------------------------------------------------------
//  [END] UITextFieldDelegate
//==============================================================

//==============================================================
//  [BEGIN] Private Methods
//--------------------------------------------------------------
#pragma mark -
#pragma mark Private Methods
- (void) _showUnlockAlert
{
    _passwordAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Enter Password", nil)
                                                          message:@"\n\n\n" //Leave space for text field
                                                         delegate:self
                                                cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                otherButtonTitles:NSLocalizedString(@"Enter", nil), nil];
    
    UILabel *passwordLabel = [[UILabel alloc] initWithFrame:CGRectMake(12,40,260,25)];
    passwordLabel.font = [UIFont systemFontOfSize:16];
    passwordLabel.textColor = [UIColor whiteColor];
    passwordLabel.backgroundColor = [UIColor clearColor];
    passwordLabel.shadowColor = [UIColor blackColor];
    passwordLabel.shadowOffset = CGSizeMake(0,-1);
    passwordLabel.textAlignment = UITextAlignmentCenter;
    DBFolder *folder = self.selectedFolder;
    passwordLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Folder: %@", nil), folder.name];
    [_passwordAlertView addSubview:passwordLabel];
    
    _passwordField = [[UITextField alloc] initWithFrame:CGRectMake(16, 78, 252, 28)];
    _passwordField.font = [UIFont systemFontOfSize:18];
    _passwordField.secureTextEntry = YES;
    _passwordField.borderStyle = UITextBorderStyleRoundedRect;
    _passwordField.keyboardAppearance = UIKeyboardAppearanceAlert;
    _passwordField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _passwordField.delegate = self;
    [_passwordField becomeFirstResponder];
    [_passwordAlertView addSubview:_passwordField];
    //_passwordField will be released in didDismissWithButtonIndex:, so DO NOT release here
    
    [_passwordAlertView show];
    //_passwordAlertView will be released in didDismissWithButtonIndex:, so DO NOT release here
}

- (void) _showItemListInFolder:(DBFolder *)folder
{
    [self.clickOnFolderDelegate clickOnFolder:folder];
}

- (void)_updateEmptynessOfFolder:(DBFolder *)folder
{
    FolderView *folderView = [folderViews objectAtIndex:folder.number];
    folderView.imageView.isEmpty = [folder isEmpty];
}

#pragma mark -
#pragma mark Notification methods
- (void)_applicationWillResignActive
{
    self.editing = NO;
    [self.folderEditModeDelegate didLeaveFolderEditMode];
}

- (void)_genLoadImageQueue
{
    [self stopLoadingImages];
    
    if(_loadImageQueue) {
        dispatch_release(_loadImageQueue);
    }
    
    NSString *queueName = [NSString stringWithFormat:@"LoadFolderImageQueue_%d", self.page];
    _loadImageQueue = dispatch_queue_create([queueName cStringUsingEncoding:NSUTF8StringEncoding], NULL);
}
//--------------------------------------------------------------
//  [END] Private Methods
//==============================================================

//==============================================================
//  [BEGIN] Notification receivers
#pragma mark -
#pragma mark Notification receivers
//--------------------------------------------------------------
- (void)_refreshExpireCountOfAllFolders
{
    DBFolder *folder;
    FolderView *folderView;
    int nExpireCount;
    int nNearExpiredCount;
    for(int nIndex = 0; nIndex < kFolderPerPage; nIndex++) {
        folder = folderDataArray[nIndex];
        folderView = [folderViews objectAtIndex:nIndex];
        nExpireCount = 0;
        nNearExpiredCount = 0;
        
        if(folder) {
            nExpireCount = [CoreDataDatabase totalExpiredItemsInFolder:folder within:0];
            nNearExpiredCount = [CoreDataDatabase totalNearExpiredItemsInFolder:folder];
        }
        
        folderView.expiredBadgeNumber = nExpireCount;
        folderView.nearExpiredBadgeNumber = nNearExpiredCount;
    }
}

- (void)_refreshExpireCountOfChangedFolders
{
    [_changedFolderNumbers enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [self _refreshExpireCountOfFolder:[NSNumber numberWithInt:idx]];
    }];
    
    [_changedFolderNumbers removeAllIndexes];
}

- (void)_refreshExpireCountOfFolder:(NSNumber *)folderNunmber
{
    int nFolderNumber = [folderNunmber intValue];
    if(nFolderNumber >= [folderViews count]) {
        [FlurryAnalytics logEvent:@"Error: Folder number exceeds folderViews size in _refreshExpireCountOfFolder"];
        return;
    }
    
    //Since changes are not saved in persistence, if we get expired count in another thread,
    //we won't get the new count, so we leave this code runs in main thread.
    
    FolderView *folderView = [folderViews objectAtIndex:nFolderNumber];
    DBFolder *folder = folderDataArray[nFolderNumber];
    int nExpireCount = 0;
    int nNearExpiredCount = 0;
    if(folder) {
        nExpireCount = [CoreDataDatabase totalExpiredItemsInFolder:folder within:0];
        nNearExpiredCount = [CoreDataDatabase totalNearExpiredItemsInFolder:folder];
    }
    
    folderView.expiredBadgeNumber = nExpireCount;
    folderView.nearExpiredBadgeNumber = nNearExpiredCount;
}

- (void)_receiveSignificantTimeChangeNotification:(NSNotification *)notification
{
//    NSLog(@"Receive SignificantNotification");
    [self _refreshExpireCountOfAllFolders];
}

- (void)_receiveMangedObjectDidChangeNotification:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    DBFolderItem *folderItem = nil;
    DBFolder *oldFolder;
    NSDictionary *oldValues;
    
    NSSet *insertedObjects = [userInfo objectForKey:NSInsertedObjectsKey];
    for(NSManagedObject *object in insertedObjects) {
        if(object.managedObjectContext == nil ||
//           [object.objectID isTemporaryID] ||
           [object class] != [DBFolderItem class])
        {
            continue;
        }
        
        folderItem = (DBFolderItem *)object;
        if(folderItem.folder.page != self.page) {
            continue;
        }
        
        if(folderItem.count > 0 &&
           folderItem.expiryDate != nil)
        {
            [_changedFolderNumbers addIndex:folderItem.folder.number];
        }
    }
    
    NSSet *deletedObjects = [userInfo objectForKey:NSDeletedObjectsKey];
    for(NSManagedObject *object in deletedObjects) {
        if(object.managedObjectContext == nil ||
//           [object.objectID isTemporaryID] ||
           [object class] != [DBFolderItem class])
        {
            continue;
        }
        
        folderItem = (DBFolderItem *)object;
        if(folderItem.folder.page != self.page ||
           folderItem.folder == nil)        //When commit change, iOS will post the notification again.
                                            //But at this time, the folder has been removed from item.
        {
            continue;
        }
        
        if(folderItem.count > 0 &&
           folderItem.expiryDate != nil)
        {
            if((oldFolder = [[folderItem changedValuesForCurrentEvent] valueForKey:kAttrFolder])) {
                [_changedFolderNumbers addIndex:oldFolder.number];
            }
            
            [_changedFolderNumbers addIndex:folderItem.folder.number];
        }
    }
    
    NSSet *updatedObjects = [userInfo objectForKey:NSUpdatedObjectsKey];
    NSNumber *oldCount;
    DBNotifyDate *oldExpiryDate;
    for(NSManagedObject *object in updatedObjects) {
        if(object.managedObjectContext == nil ||
//           [object.objectID isTemporaryID] ||
           [object class] != [DBFolderItem class])
        {
            continue;
        }
        
        folderItem = (DBFolderItem *)object;
        if(folderItem.folder.page != self.page) {
            continue;
        }
    
        oldValues = [folderItem changedValuesForCurrentEvent];
        oldCount = [oldValues valueForKey:kAttrCount];
        oldExpiryDate = [oldValues valueForKey:kAttrExpiryDate];
        
        if((oldFolder = [oldValues valueForKey:kAttrFolder])) {
            if(folderItem.count > 0 &&
               folderItem.expiryDate != nil)
            {
                [_changedFolderNumbers addIndex:oldFolder.number];
            }
        }
        
        if(([oldCount intValue] > 0 || folderItem.count > 0) &&
           (oldExpiryDate != nil || folderItem.expiryDate != nil))
        {
            [_changedFolderNumbers addIndex:folderItem.folder.number];
        }
    }
    
    if([_changedFolderNumbers count] > 0) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_refreshExpireCountOfChangedFolders) object:nil];
        [self performSelector:@selector(_refreshExpireCountOfChangedFolders) withObject:nil afterDelay:0.1f];
    }
}

//--------------------------------------------------------------
//  [END] Notification receivers
//==============================================================
@end
