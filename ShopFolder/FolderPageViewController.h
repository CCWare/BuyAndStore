//
//  FolderPageViewController.h
//  ShopFolder
//
//  Created by Michael on 2011/09/12.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ClickOnFolderDelegate.h"
#import "FolderView.h"
#import "DBFolder.h"
#import "EditFolderViewController.h"

#define kFolderPerPage          6
#define kNoFolderSelectedNumber -1

@protocol FolderEditModeDelegate;
@protocol FolderPageTappedDelegate;

@interface FolderPageViewController : UIViewController <UIGestureRecognizerDelegate, UIAlertViewDelegate, UITextFieldDelegate>
{
    NSArray *folderViews;
    DBFolder *folderDataArray[kFolderPerPage];
    
    int _page;
    __weak FolderView *_selectedFolderView;
    
    BOOL editing;
@private
    UIAlertView *_passwordAlertView;
    UITextField *_passwordField;
    NSString *_enteredPassword;
    
    NSMutableArray *_folderPositions;
    NSMutableArray *_folderImageFrames;
    
    NSNumber *_isContinueToLoadImages;
    BOOL _stopLoadingImages;
    NSURL *_currentBasicInfoURLOfImages[kFolderPerPage];
    
    dispatch_queue_t _loadImageQueue;
    NSMutableIndexSet *_changedFolderNumbers;    //save to cancel previous perform request
}

@property (nonatomic, strong) IBOutlet FolderView *folder1;
@property (nonatomic, strong) IBOutlet FolderView *folder2;
@property (nonatomic, strong) IBOutlet FolderView *folder3;
@property (nonatomic, strong) IBOutlet FolderView *folder4;
@property (nonatomic, strong) IBOutlet FolderView *folder5;
@property (nonatomic, strong) IBOutlet FolderView *folder6;

@property (nonatomic, weak) id <ClickOnFolderDelegate> clickOnFolderDelegate;
@property (nonatomic, weak) id <FolderEditModeDelegate> folderEditModeDelegate;
@property (nonatomic, weak) id <FolderPageTappedDelegate> pageTappedDelegate;

@property (nonatomic, readonly) FolderView *selectedFolderView;
@property (nonatomic, readonly) DBFolder *selectedFolder;

@property (nonatomic, assign) BOOL editing;

@property (nonatomic, readonly) NSArray *folderViews;

@property (nonatomic, readonly) int page;

- (id)initWithPageNumber:(int)page;
- (BOOL)isOverlapToFolder: (CGPoint)position;
- (void)selectEmptyFolder;
- (BOOL)isEmptyPage;
- (BOOL)isEmptyFolder:(DBFolder *)folder;
- (void)clearSelection;

- (void)changePageNumber:(int)newPage;  //called when add or delete a page

- (void)refreshFolderImagesContinuously:(NSNumber *)isContinue;
- (void)refreshFolderImagesAnimated:(BOOL)animate;
- (void)stopLoadingImages;

- (void)addFolder:(DBFolder *)folder;
- (void)removeFolder:(DBFolder *)folder;
@end

@protocol FolderEditModeDelegate
- (void)didEnterFolderEditMode;
- (void)didLeaveFolderEditMode;
- (void)shouldEditFolder: (DBFolder *)folderData;
- (void)shouldCreateFolderInPage:(int)page withNumber:(int)number;

- (void)askToDeleteFolder:(DBFolder *)folder view:(FolderView *)deleteView;
@end

@protocol FolderPageTappedDelegate
- (void)pageDidTapped: (FolderPageViewController *)sender;
@end

