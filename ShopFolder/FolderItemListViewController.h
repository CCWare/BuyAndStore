//
//  FolderItemListViewController.h
//  ShopFolder
//
//  Created by Michael on 2012/11/16.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DBItemBasicInfo.h"
#import "DBFolder.h"
#import "BasicInfoCell.h"
#import "LoadedBasicInfoData.h"
#import "OutlineLabel.h"
#import "ItemDetailCell.h"
#import "EditItemViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "EditBasicInfoViewController.h"

#ifdef _LITE_
#import "InAppPurchaseViewController.h"
#endif

#define kListTypeUnarchive  0
#define kListTypeAll        1

@protocol FolderItemListViewControllerDelegate;

@interface FolderItemListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate,
                                                            UIActionSheetDelegate, EditItemViewControllerDelegate,
                                                            BasicInfoCellDelegate, ItemDetailCellDelegate,
                                                            EditBasicInfoViewControllerDelegate, UIAlertViewDelegate
#ifdef _LITE_
                                                            ,InAppPurchaseViewControllerDelegate
#endif
>
{
    DBItemBasicInfo *_basicInfo;
    LoadedBasicInfoData *_basicInfoData;
    
    //For animating
    CGPoint _basicInfoCellInitPos;
    UIImage *_initBackgroundImage;
    BasicInfoCell *_basicInfoCell;
    
    //For large image preview
    UIImageView *_largeImageView;
    UIControl *_largeImageBackgroundView;
    UIView *_imageLabelBackgroundView;
    UILabel *_imageLabel;
    OutlineLabel *_tapToDismissLabel;
    CGRect _imageAnimateFromFrame;
    
    NSMutableSet *_folderItemSet;
    __weak NSMutableArray *_showList;   //point to _fullList or _unarchivedDataList
    NSMutableArray *_fullItemList;
    NSMutableArray *_unarchivedItemList;    //subset of _fullItemList
    NSMutableDictionary *_selectedItemMap;   //objectID -> SelectedFolderItem, use objectID since DBFodlerItem does not implement NSCopying
    
    NSArray *sortOrders;
    NSArray *sortSelectors;
    int m_nCurrentSortFieldIndex;
    int m_nCurrentSortOrderIndex;
    int m_nNewSortFieldIndex;
    int m_nNewSortOrderIndex;
    
    BOOL showSortPicker;
    BOOL _isMoveMode;
    
    UIActionSheet *_selectActionSheet;
    UIActionSheet *_archiveActionSheet;
    UIActionSheet *_unarchiveActionSheet;
    UIActionSheet *_confirmDeletionActionSheet;
    
    NSArray *_sortMethodButtons;
    NSMutableArray *_buttonLabels;
    BOOL _readyToSort;
    UIImage *_selectedSortMethodImage;
    UIImage *_unselectedSortMethodImage;
    
#ifdef _LITE_
    UIAlertView *_liteLimitAlert;
#endif
    
    UIBarButtonItem *_originRightBarButton;
}

- (id)initWithBasicInfo:(DBItemBasicInfo *)basicInfo
            preloadData:(LoadedBasicInfoData *)preloadData;

@property (strong, nonatomic) IBOutlet UITableView *itemTable;
@property (strong, nonatomic) IBOutlet UIImageView *cheatImageView;
@property (strong, nonatomic) IBOutlet UIImageView *itemTableBorderView;
@property (strong, nonatomic) IBOutlet UISegmentedControl *listTypeSegControl;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *sortButton;
@property (strong, nonatomic) IBOutlet UIToolbar *selectToolbar;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *selectButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *moveButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *duplicateButton;

@property (strong, nonatomic) IBOutlet UIView *sortPickerView;
@property (strong, nonatomic) IBOutlet UIToolbar *toolbar;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *closeSortButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *listTypeBarButtonItem;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *leftBarSpace;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *rightBarSpace;
@property (strong, nonatomic) IBOutlet UIImageView *sortByCountButton;
@property (strong, nonatomic) IBOutlet UIImageView *sortByPriceButton;
@property (strong, nonatomic) IBOutlet UIImageView *sortByCreatedDateButton;
@property (strong, nonatomic) IBOutlet UIImageView *sortByExpiryDateButton;
@property (strong, nonatomic) IBOutlet UISegmentedControl *sortOrderSegCtrl;

@property (nonatomic, weak) id<FolderItemListViewControllerDelegate> delegate;

- (IBAction)listTypeChanged:(id)sender;
- (IBAction)sortButtonPressed:(id)sender;
- (IBAction)countButtonPresses:(id)sender;
- (IBAction)moveButtonPressed:(id)sender;
- (IBAction)duplicateButtonPressed:(id)sender;
- (IBAction)archiveButtonPressed:(id)sender;
- (IBAction)deleteButtonPressed:(id)sender;

- (IBAction)closeSortView:(id)sender;
- (IBAction)selectSortOrder:(UISegmentedControl *)sender;

//For animatin
- (void)setInitBackgroundImage:(UIImage *)image cellPosition:(CGPoint)initPos;

- (void)refreshItemList;
- (void)sortAndLoadTable;
- (void)doSortAndLoadTable;

- (void)sortByPrice;
- (void)sortByCount;
- (void)sortByCreateDate;
- (void)sortByExpiryDate;

- (BOOL)shouldHandleChangesForFolderItem:(DBFolderItem *)item;
- (void)updateBasicInfoStatistics;
- (void)updateBasicInfoData;
@end

@protocol FolderItemListViewControllerDelegate
- (void)itemBasicInfoUpdated:(DBItemBasicInfo *)basicInfo newData:(LoadedBasicInfoData *)info;
@end
