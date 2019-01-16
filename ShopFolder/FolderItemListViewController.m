//
//  FolderItemListViewController.m
//  ShopFolder
//
//  Created by Michael on 2012/11/16.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "FolderItemListViewController.h"
#import "CoreDataDatabase.h"
#import "DBItemBasicInfo+SetAdnGet.h"
#import "ColorConstant.h"
#import "PreferenceConstant.h"
#import "objc/message.h"    //for objc_msgSend
#import "DBFolderItem+expiryOperations.h"
#import "DBFolderItem+ChangeLog.h"
#import "SelectedFolderItem.h"
#import "NotificationConstant.h"
#import "FlurryAnalytics.h"
#import "NSManagedObject+DeepCopy.h"
#import "TimeUtil.h"
#import "UIImage+Resize.h"
#import "UIImage+RoundedCorner.h"
#import "PreferenceConstant.h"
#import "UIApplication+BadgeUpdate.h"

#ifdef _LITE_
#import "LiteLimitations.h"
#endif

#define kActionSelectAllIndex       0
#define kActionDeselectAllIndex     1

#define kActionArchiveIndex         0
#define kActionUnarchiveIndex       1

#define kSelectedSortButtonBackground   [UIColor blueColor]

#define kSortAscendingIndex         0
#define kSortDescendingIndex        1

@interface FolderItemListViewController ()
- (void)_tapOnLargeImagePreview:(UITapGestureRecognizer *)sender;
- (void)_dismissImagePreviewAnimated:(BOOL)animate;
- (void)_dismissSelectToolbar;
- (void)_beginEditFolderItemAtIndexPath:(NSIndexPath *)indexPath;

- (void)_cancelButtonPressed:(id)sender;
- (void)_leaveMoveMode;

- (void)_archiveSelectedItems:(BOOL)archived;
- (void)_deleteSelectedItems;

- (void)_receiveManagedObjectContextDidSaveNotification:(NSNotification *)notification;

- (void)_selectButton:(UIGestureRecognizer *)sender;
@end

@implementation FolderItemListViewController

- (id)initWithBasicInfo:(DBItemBasicInfo *)basicInfo
            preloadData:(LoadedBasicInfoData *)preloadData
{
    if((self = [super initWithNibName:@"FolderItemListViewController" bundle:nil])) {
        _basicInfo = basicInfo;
        _basicInfoData = preloadData;
        
        _selectedItemMap = [NSMutableDictionary dictionary];
        _unarchivedItemList = [NSMutableArray array];
        
        if(!_basicInfoData.isFullyLoaded) {
            [self updateBasicInfoStatistics];
            [self updateBasicInfoData];
            _basicInfoData.isFullyLoaded = YES;
        }
        
        //Must be 1-1 paired with sortFields
        sortSelectors = [NSArray arrayWithObjects:
                         [NSValue valueWithPointer:@selector(sortByCount)],
                         [NSValue valueWithPointer:@selector(sortByPrice)],
                         [NSValue valueWithPointer:@selector(sortByCreateDate)],
                         [NSValue valueWithPointer:@selector(sortByExpiryDate)],
                         nil];
        
        //Init picker index
        m_nCurrentSortFieldIndex = [[NSUserDefaults standardUserDefaults] integerForKey:kLastSortField];
        if(m_nCurrentSortFieldIndex > [sortSelectors count]-1) {
            m_nCurrentSortFieldIndex = 0;
            [[NSUserDefaults standardUserDefaults] setInteger:m_nCurrentSortFieldIndex forKey:kLastSortField];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        m_nCurrentSortOrderIndex = [[NSUserDefaults standardUserDefaults] integerForKey:kLastSortOrder];
        if(m_nCurrentSortOrderIndex > [sortOrders count]-1) {
            m_nCurrentSortOrderIndex = 0;
            [[NSUserDefaults standardUserDefaults] setInteger:m_nCurrentSortOrderIndex forKey:kLastSortOrder];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        m_nNewSortFieldIndex = m_nCurrentSortFieldIndex;
        m_nNewSortOrderIndex = m_nCurrentSortOrderIndex;
    }
    
    return self;
}

- (void)setInitBackgroundImage:(UIImage *)image cellPosition:(CGPoint)initPos
{
    _initBackgroundImage = image;
    _basicInfoCellInitPos = initPos;
}

- (void)viewDidUnload {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:nil];
    
    _basicInfoCell = nil;
    _selectedSortMethodImage = nil;
    _unselectedSortMethodImage = nil;
    
    [self setItemTable:nil];
    [self setCheatImageView:nil];
    [self setSelectToolbar:nil];
    [self setSelectButton:nil];
    [self setListTypeSegControl:nil];
    [self setSortButton:nil];
    [self setMoveButton:nil];
    [self setDuplicateButton:nil];
    [self setToolbar:nil];
    [self setItemTableBorderView:nil];
    [self setCloseSortButton:nil];
    [self setSortByCountButton:nil];
    [self setSortByPriceButton:nil];
    [self setSortByCreatedDateButton:nil];
    [self setSortByExpiryDateButton:nil];
    [self setSortOrderSegCtrl:nil];
    [self setSortPickerView:nil];
    [self setListTypeBarButtonItem:nil];
    [self setLeftBarSpace:nil];
    [self setRightBarSpace:nil];
    [super viewDidUnload];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationController.navigationBar.tintColor = kColorNavigationBarTintColor;
    //localize seg ctrl
    self.duplicateButton.title = NSLocalizedString(@"Copy", nil);
    self.moveButton.title = NSLocalizedString(@"Move", nil);
    self.sortButton.title = NSLocalizedString(@"Sort", nil);
    self.closeSortButton.title = NSLocalizedString(@"Close", nil);
    [self.listTypeSegControl setTitle:NSLocalizedString(@"Unarchived", @"List type: Unarchived") forSegmentAtIndex:0];
    [self.listTypeSegControl setTitle:NSLocalizedString(@"All", @"List type: All") forSegmentAtIndex:1];
    
    // Do any additional setup after loading the view from its nib.
    _basicInfoCell = [[BasicInfoCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"BasicInfoCell"];
    _basicInfoCell.showNextExpiredTime = YES;
    _basicInfoCell.showExpiryInformation = YES;
    _basicInfoCell.accessoryType = UITableViewCellAccessoryNone;
    _basicInfoCell.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, kBasicInfoCellHeight);
    
    [_basicInfoCell updateFromLoadedBasicInfo:_basicInfoData animated:NO];
    [self.view addSubview:_basicInfoCell];
    _basicInfoCell.delegate = self;
    
    UIImage *borderImage = [[UIImage imageNamed:@"table_border"] resizableImageWithCapInsets:UIEdgeInsetsMake(8.0f, 8.0f, 8.0f, 8.0f)];
    UIImageView *border = [[UIImageView alloc] initWithFrame:_basicInfoCell.frame];
    border.image = borderImage;
    [_basicInfoCell addSubview:border];
    
    UIImage *borderTopImage = [[UIImage imageNamed:@"table_border_top"] resizableImageWithCapInsets:UIEdgeInsetsMake(8.0f, 8.0f, 0.0f, 8.0f)];
    self.itemTableBorderView.image = borderTopImage;
    
    if(_initBackgroundImage) {
        self.cheatImageView.image = _initBackgroundImage;
        
        CGRect frame = _basicInfoCell.frame;
        frame.origin = _basicInfoCellInitPos;
        _basicInfoCell.frame = frame;
    } else {
        self.cheatImageView.hidden = YES;
        self.itemTable.hidden = NO;
    }
    
    //Make sort picker view more beautyful
    //Order should be the same as sortSelectors
    _sortMethodButtons = @[self.sortByCountButton, self.sortByPriceButton,
                           self.sortByCreatedDateButton, self.sortByExpiryDateButton];
    _buttonLabels = [NSMutableArray array];
    CGRect buttonImageFrame = CGRectMake(11.0f, 11.0f, 22.0f, 22.0f);
    UIColor *textColor = [UIColor blackColor];
    
    //Sort By Count button
    self.sortByCountButton.exclusiveTouch = YES;
    UIImageView *buttonIcon = [[UIImageView alloc] initWithFrame:buttonImageFrame];
    buttonIcon.image = [UIImage imageNamed:@"count"];
    [self.sortByCountButton addSubview:buttonIcon];
    
    UILabel *buttonTitle = [[UILabel alloc] initWithFrame:CGRectMake(44.0f, 0.0f,
                                                                     self.sortByCountButton.frame.size.width-44.0f,
                                                                     self.sortByCountButton.frame.size.height)];
    buttonTitle.backgroundColor = [UIColor clearColor];
    buttonTitle.text = NSLocalizedString(@"Count", nil);
    buttonTitle.textColor = textColor;
    buttonTitle.numberOfLines = 2;
    buttonTitle.textAlignment = UITextAlignmentLeft;
    buttonTitle.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    [self.sortByCountButton addSubview:buttonTitle];
    [_buttonLabels addObject:buttonTitle];
    
    //Sort By Price button
    self.sortByPriceButton.exclusiveTouch = YES;
    buttonIcon = [[UIImageView alloc] initWithFrame:buttonImageFrame];
    buttonIcon.image = [UIImage imageNamed:@"price"];
    [self.sortByPriceButton addSubview:buttonIcon];
    
    buttonTitle = [[UILabel alloc] initWithFrame:CGRectMake(44.0f, 0.0f,
                                                            self.sortByPriceButton.frame.size.width-44.0f,
                                                            self.sortByPriceButton.frame.size.height)];
    buttonTitle.backgroundColor = [UIColor clearColor];
    buttonTitle.text = NSLocalizedString(@"Price", nil);
    buttonTitle.textColor = textColor;
    buttonTitle.numberOfLines = 2;
    buttonTitle.textAlignment = UITextAlignmentLeft;
    buttonTitle.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    [self.sortByPriceButton addSubview:buttonTitle];
    [_buttonLabels addObject:buttonTitle];
    
    //Sort By Created Date button
    self.sortByCreatedDateButton.exclusiveTouch = YES;
    buttonIcon = [[UIImageView alloc] initWithFrame:buttonImageFrame];
    buttonIcon.image = [UIImage imageNamed:@"add"];
    [self.sortByCreatedDateButton addSubview:buttonIcon];
    
    buttonTitle = [[UILabel alloc] initWithFrame:CGRectMake(44.0f, 0.0f,
                                                            self.sortByCreatedDateButton.frame.size.width-44.0f,
                                                            self.sortByCreatedDateButton.frame.size.height)];
    buttonTitle.backgroundColor = [UIColor clearColor];
    buttonTitle.text = NSLocalizedString(@"Created\nDate", @"Sort button title");
    buttonTitle.textColor = textColor;
    buttonTitle.numberOfLines = 2;
    buttonTitle.textAlignment = UITextAlignmentLeft;
    buttonTitle.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    [self.sortByCreatedDateButton addSubview:buttonTitle];
    [_buttonLabels addObject:buttonTitle];
    
    //Sort By Expiry Date button
    self.sortByExpiryDateButton.exclusiveTouch = YES;
    buttonIcon = [[UIImageView alloc] initWithFrame:buttonImageFrame];
    buttonIcon.image = [UIImage imageNamed:@"clock"];
    [self.sortByExpiryDateButton addSubview:buttonIcon];
    
    buttonTitle = [[UILabel alloc] initWithFrame:CGRectMake(44.0f, 0.0f,
                                                            self.sortByExpiryDateButton.frame.size.width-44.0f,
                                                            self.sortByExpiryDateButton.frame.size.height)];
    buttonTitle.backgroundColor = [UIColor clearColor];
    buttonTitle.text = NSLocalizedString(@"Expiry\nDate", @"Sort button title");
    buttonTitle.textColor = textColor;
    buttonTitle.numberOfLines = 2;
    buttonTitle.textAlignment = UITextAlignmentLeft;
    buttonTitle.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    [self.sortByExpiryDateButton addSubview:buttonTitle];
    [_buttonLabels addObject:buttonTitle];

    _selectedSortMethodImage = [[UIImage imageNamed:@"button_selected_background"]
                                resizableImageWithCapInsets:UIEdgeInsetsMake(0.0f, 10.0f, 0.0f, 10.0f)];
    _unselectedSortMethodImage = [[UIImage imageNamed:@"button_unselected_background"]
                                  resizableImageWithCapInsets:UIEdgeInsetsMake(0.0f, 10.0f, 0.0f, 10.0f)];
    int buttonIndex = 0;
    for(UIImageView *sortButton in _sortMethodButtons) {
        sortButton.userInteractionEnabled = YES;
        UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_selectButton:)];
        tapGR.numberOfTapsRequired = 1;
        [sortButton addGestureRecognizer:tapGR];
        
        buttonTitle = [_buttonLabels objectAtIndex:buttonIndex];
        buttonTitle.font = [UIFont boldSystemFontOfSize:17.0f];
        
        if(buttonIndex == m_nCurrentSortFieldIndex) {
            sortButton.image = _selectedSortMethodImage;
        } else {
            sortButton.image = _unselectedSortMethodImage;
        }
        
        buttonIndex++;
    }
    self.sortOrderSegCtrl.selectedSegmentIndex = m_nCurrentSortOrderIndex;
    self.toolbar.items = @[self.leftBarSpace, self.listTypeBarButtonItem, self.rightBarSpace, self.sortButton];
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = CGRectMake(0, 44.0f,
                                self.sortPickerView.frame.size.width,
                                self.sortPickerView.frame.size.height - 44.0f);
    gradient.colors = [NSArray arrayWithObjects:
                       (id)[UIColor colorWithWhite:0.0f alpha:0.3f].CGColor,
                       (id)[UIColor clearColor].CGColor,
                       (id)[UIColor colorWithWhite:0.0f alpha:0.3f].CGColor,
                       nil];
    gradient.locations = @[@0.0f, @0.5f, @1.0f];
    [self.sortPickerView.layer insertSublayer:gradient atIndex:0];
    
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(_receiveManagedObjectContextDidSaveNotification:)
//                                                 name:NSManagedObjectContextDidSaveNotification
//                                               object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if(!self.cheatImageView.hidden) {
        self.cheatImageView.alpha = 1.0f;
        self.cheatImageView.transform = CGAffineTransformIdentity;
        
        [UIView animateWithDuration:0.5f
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             self.cheatImageView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.8f, 0.8f);
                             self.cheatImageView.alpha = 0.0f;
                         } completion:^(BOOL finished) {
                             self.cheatImageView.hidden = YES;
                             self.cheatImageView.image = nil;
                             _initBackgroundImage = nil;
                         }];
        
        CGFloat screenBottom = [UIScreen mainScreen].bounds.size.height - 44.0f - [[UIApplication sharedApplication] statusBarFrame].size.height;
        CGRect frame = self.itemTable.frame;
        frame.origin.y = screenBottom;
        self.itemTable.frame = frame;
        
        frame = self.sortPickerView.frame;
        frame.origin.y = screenBottom;
        self.sortPickerView.frame = frame;
        
        [UIView animateWithDuration:0.35f
                              delay:0.15f
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
                             self.itemTable.hidden = NO;
                             
                             CGRect frame = _basicInfoCell.frame;
                             frame.origin = CGPointZero;
                             _basicInfoCell.frame = frame;
                             
                             frame = self.itemTable.frame;
                             frame.origin.y = kBasicInfoCellHeight;
                             self.itemTable.frame = frame;
                             
                             frame = self.sortPickerView.frame;
                             frame.origin.y = screenBottom - 44.0f;
                             self.sortPickerView.frame = frame;
                         } completion:^(BOOL finished) {
                             
                         }];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//==============================================================
//  [BEGIN] UITableViewDelegate
#pragma mark - UITableViewDelegate
//--------------------------------------------------------------
- (void)_beginEditFolderItemAtIndexPath:(NSIndexPath *)indexPath
{
    DBFolderItem *folderItem = [_showList objectAtIndex:indexPath.row];
    EditItemViewController *editItemVC = [[EditItemViewController alloc] initWithFolderItem:folderItem
                                                                                  basicInfo:folderItem.basicInfo
                                                                                     folder:folderItem.folder];
    editItemVC.delegate = self;
    editItemVC.canEditBasicInfo = NO;
    [self.navigationController pushViewController:editItemVC animated:YES];
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self _beginEditFolderItemAtIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kItemDetailCellHeight;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    DBFolderItem *item = [_showList objectAtIndex:indexPath.row];
    
    if(item.isArchived) {
        cell.backgroundColor = kColorArchivedCellBackground;
    } else if([item isExpired]) {
        cell.backgroundColor = kColorExpiredCellBackground;
    } else if([item isNearExpired]) {
        cell.backgroundColor = kColorNearExpiredCellBackground;
    } else {
        cell.backgroundColor = [UIColor whiteColor];
    }
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
    static NSString *CellTableIdentitifier = @"FolderItemCellIdentifier";
    ItemDetailCell *cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
    if(cell == nil) {
        cell = [[ItemDetailCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellTableIdentitifier];
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
        cell.delegate = self;
    }
    
    cell.folderItem = [_showList objectAtIndex:indexPath.row];
    SelectedFolderItem *selectedItem = [_selectedItemMap objectForKey:cell.folderItem.objectID];
    if(selectedItem) {
        cell.isChecked = YES;
        
        if(_isMoveMode) {
            cell.selectCount = selectedItem.selectCount;
            cell.showSelectIndicator = YES;
        }
    } else {
        cell.isChecked = NO;
        cell.showSelectIndicator = NO;
    }
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_showList count];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    [self _beginEditFolderItemAtIndexPath:indexPath];
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(_isMoveMode) {
        return NO;
    }
    
    DBFolderItem *folderItem = [_showList objectAtIndex:indexPath.row];
    if(folderItem.isArchived) {
        return NO;
    }
    
    return YES;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NSLocalizedString(@"Archive", nil);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(editingStyle == UITableViewCellEditingStyleDelete) {
        DBFolderItem *folderItem = [_showList objectAtIndex:indexPath.row];
        if(folderItem.isArchived) {
            return;
        }
        
        folderItem.isArchived = YES;
        [folderItem addArchiveStatusChangeLog];
        folderItem.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
        
        if([CoreDataDatabase commitChanges:nil]) {
            [_unarchivedItemList removeObject:folderItem];
            
            [self.itemTable beginUpdates];
            if(self.listTypeSegControl.selectedSegmentIndex == kListTypeUnarchive) {
                //Remove row
                [self.itemTable deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else {
                //Change color of row
                [self.itemTable reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            [self.itemTable endUpdates];
            
            if([_unarchivedItemList count] == 0) {
                _showList = _fullItemList;
                self.listTypeSegControl.selectedSegmentIndex = kListTypeAll;
                
                [self.itemTable reloadData];
            }
            
            [self updateBasicInfoStatistics];
            [_basicInfoCell updateFromLoadedBasicInfo:_basicInfoData animated:YES];
            [self.delegate itemBasicInfoUpdated:_basicInfo newData:_basicInfoData];
            
            [[UIApplication sharedApplication] refreshApplicationBadgeNumber];
        } else {
            folderItem.isArchived = NO;
        }
    }
}
//--------------------------------------------------------------
//  [END] UITableViewDataSource
//==============================================================

//==============================================================
//  [BEGIN] Sort selectors
#pragma mark - Sort selectors
//--------------------------------------------------------------
- (NSComparisonResult)_compareTime:(NSTimeInterval)time1 toTime:(NSTimeInterval)time2
{
    if(time1 < time2) {
        return NSOrderedAscending;
    }
    
    if(time1 > time2) {
        return NSOrderedDescending;
    }
    
    return NSOrderedSame;
}

- (void)sortByPrice
{
    if(m_nCurrentSortOrderIndex == kSortAscendingIndex) {
        _fullItemList = [NSMutableArray arrayWithArray:[[_folderItemSet allObjects] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            DBFolderItem *item1 = (DBFolderItem *)obj1;
            DBFolderItem *item2 = (DBFolderItem *)obj2;
            
            if(item1.price < item2.price) { //may have error of digit
                return NSOrderedAscending;
            }
            
            if(item1.price > item2.price) {
                return NSOrderedDescending;
            }
            
            return [self _compareTime:item1.createTime toTime:item2.createTime];
        }]];
    } else {
        _fullItemList = [NSMutableArray arrayWithArray:[[_folderItemSet allObjects] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            DBFolderItem *item1 = (DBFolderItem *)obj1;
            DBFolderItem *item2 = (DBFolderItem *)obj2;
            
            if(item2.price < item1.price) { //may have error of digit
                return NSOrderedAscending;
            }
            
            if(item2.price > item1.price) {
                return NSOrderedDescending;
            }
            
            return [self _compareTime:item1.createTime toTime:item2.createTime];
        }] ];
    }
    
    [_unarchivedItemList removeAllObjects];
    for(DBFolderItem *item in _fullItemList) {
        if(!item.isArchived) {
            [_unarchivedItemList addObject:item];
        }
    }
}

- (void)sortByCreateDate
{
    if(m_nCurrentSortOrderIndex == kSortAscendingIndex) {
        _fullItemList = [NSMutableArray arrayWithArray:[[_folderItemSet allObjects] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            DBFolderItem *item1 = (DBFolderItem *)obj1;
            DBFolderItem *item2 = (DBFolderItem *)obj2;
            
            return [self _compareTime:item1.createTime toTime:item2.createTime];
        }]];
    } else {
        _fullItemList = [NSMutableArray arrayWithArray:[[_folderItemSet allObjects] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            DBFolderItem *item1 = (DBFolderItem *)obj1;
            DBFolderItem *item2 = (DBFolderItem *)obj2;
            
            return [self _compareTime:item2.createTime toTime:item1.createTime];
        }]];
    }
    
    [_unarchivedItemList removeAllObjects];
    for(DBFolderItem *item in _fullItemList) {
        if(!item.isArchived) {
            [_unarchivedItemList addObject:item];
        }
    }
}

- (void)sortByExpiryDate
{
    if(m_nCurrentSortOrderIndex == kSortAscendingIndex) {
        _fullItemList = [NSMutableArray arrayWithArray:[[_folderItemSet allObjects] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            DBFolderItem *item1 = (DBFolderItem *)obj1;
            DBFolderItem *item2 = (DBFolderItem *)obj2;
            
            if(item1.expiryDate.date < item2.expiryDate.date) {
                return NSOrderedAscending;
            }
            
            if(item1.expiryDate.date > item2.expiryDate.date) {
                return NSOrderedDescending;
            }
            
            return [self _compareTime:item1.createTime toTime:item2.createTime];
        }]];
    } else {
        _fullItemList = [NSMutableArray arrayWithArray:[[_folderItemSet allObjects] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            DBFolderItem *item1 = (DBFolderItem *)obj1;
            DBFolderItem *item2 = (DBFolderItem *)obj2;
            
            if(item1.expiryDate.date < item2.expiryDate.date) {
                return NSOrderedDescending;
            }
            
            if(item1.expiryDate.date > item2.expiryDate.date) {
                return NSOrderedAscending;
            }
            
            return [self _compareTime:item1.createTime toTime:item2.createTime];
        }]];
    }
    
    [_unarchivedItemList removeAllObjects];
    for(DBFolderItem *item in _fullItemList) {
        if(!item.isArchived) {
            [_unarchivedItemList addObject:item];
        }
    }
}

- (void)sortByCount
{
    if(m_nCurrentSortOrderIndex == kSortAscendingIndex) {
        _fullItemList = [NSMutableArray arrayWithArray:[[_folderItemSet allObjects] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            DBFolderItem *item1 = (DBFolderItem *)obj1;
            DBFolderItem *item2 = (DBFolderItem *)obj2;
            
            if(item1.count < item2.count) {
                return NSOrderedAscending;
            }
            
            if(item1.count > item2.count) {
                return NSOrderedDescending;
            }
            
            return [self _compareTime:item1.createTime toTime:item2.createTime];
        }]];
    } else {
        _fullItemList = [NSMutableArray arrayWithArray:[[_folderItemSet allObjects] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            DBFolderItem *item1 = (DBFolderItem *)obj1;
            DBFolderItem *item2 = (DBFolderItem *)obj2;
            
            if(item2.count < item1.count) {
                return NSOrderedAscending;
            }
            
            if(item2.count > item1.count) {
                return NSOrderedDescending;
            }
            
            return [self _compareTime:item1.createTime toTime:item2.createTime];
        }]];
    }
    
    [_unarchivedItemList removeAllObjects];
    for(DBFolderItem *item in _fullItemList) {
        if(!item.isArchived) {
            [_unarchivedItemList addObject:item];
        }
    }
}
//--------------------------------------------------------------
//  [END] Sort selectors
//==============================================================

//==============================================================
//  [BEGIN] BasicInfoCellDelegate
#pragma mark - BasicInfoCellDelegate
//--------------------------------------------------------------
- (void)imageTouched:(BasicInfoCell *)cell
{
    if([_basicInfo getDisplayImage] == nil) {
        return;
    }
    
    //Calculate from and to frames
    CGFloat targetSize = [UIScreen mainScreen].bounds.size.width - kSpaceToImage * 2.0f;
    CGRect toFrame = CGRectMake(cell.imageViewFrame.origin.x, cell.imageViewFrame.origin.y, targetSize, targetSize);
    _imageAnimateFromFrame = cell.imageViewFrame;
    
    //Prepare the view to cover table view
    if(!_largeImageBackgroundView) {
        _largeImageBackgroundView = [[UIControl alloc] initWithFrame:self.view.frame];
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
        _imageLabelBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, targetSize-60.0f,
                                                                             targetSize, 60.0)];
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
    
    if([_basicInfo.name length] == 0) {
        _imageLabelBackgroundView.hidden = YES;
    } else {
        _imageLabelBackgroundView.hidden = NO;
        _imageLabel.text = _basicInfo.name;
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
    _largeImageView.image = [_basicInfo getDisplayImage];
    _largeImageView.frame = _imageAnimateFromFrame;
    
    _tapToDismissLabel.alpha = 0.0f;
    _imageLabelBackgroundView.alpha = 0.0f;
    
    [UIView animateWithDuration:0.001f
                     animations:^{
                         //We're doing this because system will cache last animation direction
                         _largeImageView.frame = _imageAnimateFromFrame;
                     } completion:^(BOOL finished) {
                         if(finished) {
                             if(cell.expiredCount > 0 || cell.nearExpiredCount > 0) {
                                 [cell hideBadgeAnimatedWithDuration:0.1f afterDelay:0.0f];
                             }
                             
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
}

- (void)editButtonPressed:(BasicInfoCell *)sneder
{
    EditBasicInfoViewController *editBasicInfoVC = [[EditBasicInfoViewController alloc] initWithItemBasicInfo:_basicInfo];
    editBasicInfoVC.delegate = self;
    
    UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:editBasicInfoVC];
    [self presentViewController:navCon animated:YES completion:NULL];
}

- (void)cartButtonPressed:(id)sender
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
    if(_basicInfo.shoppingItem) {
        //Remove shopping item
        [CoreDataDatabase removeShoppingItem:_basicInfo.shoppingItem updatePositionOfRestItems:YES];
        _basicInfo.shoppingItem = nil;
    } else {
        //Add shopping item
        _basicInfo.shoppingItem = [CoreDataDatabase obtainShoppingItem];
//        [CoreDataDatabase moveShoppingItem:_basicInfo.shoppingItem to:0];
    }
    _basicInfo.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
    
    if([CoreDataDatabase commitChanges:nil]) {
        //Update UI
        [_basicInfoCell setIsInShoppingList:(_basicInfo.shoppingItem != nil)];
    } else {
        [CoreDataDatabase cancelUnsavedChanges];
    }
}

- (void)favoriteButtonPressed:(id)sender
{
    _basicInfo.isFavorite = !_basicInfo.isFavorite;
    _basicInfo.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
    
    if([CoreDataDatabase commitChanges:nil]) {
        //Update UI
        [_basicInfoCell setIsFavorite:_basicInfo.isFavorite];
    } else {
        [CoreDataDatabase cancelUnsavedChanges];
    }
}
//--------------------------------------------------------------
//  [END] BasicInfoCellDelegate
//==============================================================

//==============================================================
//  [BEGIN] EditBasicInfoViewControllerDelegate
#pragma mark - EditBasicInfoViewControllerDelegate
//--------------------------------------------------------------
- (void)cancelEditBasicInfo:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)finishEditBasicInfo:(id)sender changedBasicIndo:(DBItemBasicInfo *)basicInfo
{
    BOOL basicInfoChanged = ![basicInfo.objectID isEqual:_basicInfo.objectID];
    if(basicInfoChanged) {
        for(DBFolderItem *item in _fullItemList) {
            item.basicInfo = basicInfo;
        }
        
        [CoreDataDatabase commitChanges:nil];
    }
    
    _basicInfo = basicInfo;
    [self updateBasicInfoData];
    [self updateBasicInfoStatistics];
    [_basicInfoCell updateFromLoadedBasicInfo:_basicInfoData animated:YES];
    
    if(basicInfoChanged) {
        [self refreshItemList];
        [self doSortAndLoadTable];
    }
    
    [self dismissViewControllerAnimated:YES completion:NULL];
    [self.delegate itemBasicInfoUpdated:_basicInfo newData:_basicInfoData];
}
//--------------------------------------------------------------
//  [END] EditBasicInfoViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] ItemDetailCellDelegate
#pragma mark - ItemDetailCellDelegate
//--------------------------------------------------------------
- (void)cellCheckStatusChanged:(BOOL)checked from:(ItemDetailCell *)sender
{
    NSIndexPath *index = [self.itemTable indexPathForCell:sender];
    DBFolderItem *item = [_showList objectAtIndex:index.row];
    
    if([_selectedItemMap objectForKey:item.objectID]) {
        //Deselect item
        [_selectedItemMap removeObjectForKey:item.objectID];
        sender.selectCount = item.count;
        
        if(_isMoveMode) {
            sender.showSelectIndicator = NO;
        }
        
        if([_selectedItemMap count] == 0) {
            [self _dismissSelectToolbar];
        }
    } else {
        //Select item
        SelectedFolderItem *selectItem = [_selectedItemMap objectForKey:item.objectID];
        if(selectItem == nil) {
            [_selectedItemMap setObject:[[SelectedFolderItem alloc] initWithFolderItem:item]
                                 forKey:item.objectID];
        }
        
        if(_isMoveMode) {
            sender.showSelectIndicator = YES;
            sender.selectCount = item.count;
        }
        
        if([_selectedItemMap count] == 1) {
            //Show select toolbar
            CGRect frame = self.view.frame;
            [UIView animateWithDuration:0.3f
                                  delay:0.0f
                                options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                                 CGRect toolbarFrame = self.selectToolbar.frame;
                                 toolbarFrame.origin.y = frame.origin.y + frame.size.height - toolbarFrame.size.height;
                                 self.selectToolbar.frame = toolbarFrame;
                                 self.sortPickerView.alpha = 0.0f;
                             } completion:^(BOOL finished) {
                                 
                             }];
        }
    }
    
    if([_selectedItemMap count] > 0) {
        self.selectButton.title = [NSString stringWithFormat:@"%d", [_selectedItemMap count]];
    }
}

- (void)cellSelectCountChanged:(int)value from:(ItemDetailCell *)sender
{
    NSIndexPath *index = [self.itemTable indexPathForCell:(UITableViewCell *)sender];
    DBFolderItem *item = [_showList objectAtIndex:index.row];
    
    SelectedFolderItem *selectedItem = [_selectedItemMap objectForKey:item.objectID];
    selectedItem.selectCount = value;
}
//--------------------------------------------------------------
//  [END] ItemDetailCellDelegate
//==============================================================

//==============================================================
//  [BEGIN] Private Methods
#pragma mark - Private Methods
//--------------------------------------------------------------
- (void)_tapOnLargeImagePreview:(UITapGestureRecognizer *)sender
{
    [self _dismissImagePreviewAnimated:YES];
}

- (void)_dismissImagePreviewAnimated:(BOOL)animate
{
    _tapToDismissLabel.hidden = YES;
    _imageLabelBackgroundView.hidden = YES;
    
    void(^resizeBlock)() = ^{
        _largeImageBackgroundView.backgroundColor = [UIColor clearColor];
        _largeImageView.frame = _imageAnimateFromFrame;
    };
    
    void(^finishBlock)(BOOL finished) = ^(BOOL finished) {
        [_largeImageBackgroundView removeFromSuperview];
    };
    
    if(animate) {
        if(_basicInfoCell.expiredCount > 0 || _basicInfoCell.nearExpiredCount > 0) {
            [_basicInfoCell showBadgeAnimatedWithDuration:0.2f afterDelay:0.25f];
        }
        
        [UIView animateWithDuration:0.3
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionBeginFromCurrentState
                         animations:resizeBlock
                         completion:finishBlock];
    } else {
        resizeBlock();
        finishBlock(YES);
    }
}

- (void)_dismissSelectToolbar
{
    [self _leaveMoveMode];
    [_selectedItemMap removeAllObjects];
    
    CGRect frame = self.view.frame;
    [UIView animateWithDuration:0.3f
                          delay:0.0f
                        options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         CGRect toolbarFrame = self.selectToolbar.frame;
                         toolbarFrame.origin.y = frame.origin.y + frame.size.height;
                         self.selectToolbar.frame = toolbarFrame;
                         self.sortPickerView.alpha = 1.0f;
                     } completion:^(BOOL finished) {
                         
                     }];
}
//--------------------------------------------------------------
//  [END] Private Methods
//==============================================================

//==============================================================
//  [BEGIN] Sort APIs
#pragma mark - Sort APIs
//--------------------------------------------------------------
- (void)doSortAndLoadTable
{
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.sortButton.enabled = NO;
    self.listTypeSegControl.enabled = NO;
    self.itemTable.userInteractionEnabled = NO;
    
    dispatch_queue_t sortQueue = dispatch_queue_create("SortAndLoadTable", NULL);
    
    dispatch_async(sortQueue, ^(void) {
        SEL sortSelector;
        NSValue *selectorValue;
        selectorValue = [sortSelectors objectAtIndex:m_nCurrentSortFieldIndex];
        [selectorValue getValue:&sortSelector];
        //[self performSelector:sortSelector];
        objc_msgSend(self, sortSelector);
//        [self sortByCreateDate];
        
        [_unarchivedItemList removeAllObjects];
        for(DBFolderItem *item in _fullItemList) {
            if(!item.isArchived) {
                [_unarchivedItemList addObject:item];
            }
        }
       
        //Return items in UI thread
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if([_unarchivedItemList count] == 0 &&
               self.listTypeSegControl.selectedSegmentIndex == kListTypeUnarchive)
            {
                self.listTypeSegControl.selectedSegmentIndex = kListTypeAll;    //This won't call changeListType
            }
            
            if(self.listTypeSegControl.selectedSegmentIndex == kListTypeUnarchive) {
                _showList = _unarchivedItemList;
            } else {
                _showList = _fullItemList;
            }
            
            [self.itemTable reloadData];
            
            self.navigationItem.rightBarButtonItem.enabled = YES;
            self.sortButton.enabled = ([_showList count] > 1);
            self.listTypeSegControl.enabled = YES;
            self.itemTable.userInteractionEnabled = YES;
        });
    });
    
    dispatch_release(sortQueue);
}

- (void)refreshItemList
{
    _folderItemSet = [NSMutableSet setWithSet:_basicInfo.folderItems];
}

- (void)sortAndLoadTable
{
    BOOL doSort = NO;
    //Check field
    if(m_nNewSortFieldIndex != m_nCurrentSortFieldIndex) {
        m_nCurrentSortFieldIndex = m_nNewSortFieldIndex;
        doSort = YES;
    }
    
    //Check order
    if(m_nNewSortOrderIndex != m_nCurrentSortOrderIndex) {
        m_nCurrentSortOrderIndex = m_nNewSortOrderIndex;
        doSort = YES;
    }
    
    if(doSort) {
        [[NSUserDefaults standardUserDefaults] setInteger:m_nCurrentSortFieldIndex forKey:kLastSortField];
        [[NSUserDefaults standardUserDefaults] setInteger:m_nCurrentSortOrderIndex forKey:kLastSortOrder];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [self doSortAndLoadTable];
    }
}
//--------------------------------------------------------------
//  [END] Sort APIs
//==============================================================

//==============================================================
//  [BEGIN] IBActions
#pragma mark - IBActions
//--------------------------------------------------------------
- (IBAction)listTypeChanged:(id)sender
{
    UISegmentedControl *segCtrl = (UISegmentedControl *)sender;
    
    [self.itemTable beginUpdates];
    
    if(segCtrl.selectedSegmentIndex == kListTypeAll) {
        _showList = _fullItemList;
        
        NSMutableArray *insertRows = [NSMutableArray array];
        int nIndex = 0;
        for(DBFolderItem *item in _fullItemList) {
            if(![_unarchivedItemList containsObject:item]) {
                [insertRows addObject:[NSIndexPath indexPathForRow:nIndex inSection:0]];
            }
            nIndex++;
        }
        
        [self.itemTable insertRowsAtIndexPaths:insertRows withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        _showList = _unarchivedItemList;
        
        NSMutableArray *deleteRows = [NSMutableArray array];
        int nIndex = 0;
        for(DBFolderItem *item in _fullItemList) {
            if(![_unarchivedItemList containsObject:item]) {
                [deleteRows addObject:[NSIndexPath indexPathForRow:nIndex inSection:0]];
            }
            nIndex++;
        }
        
        [self.itemTable deleteRowsAtIndexPaths:deleteRows withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
    [self.itemTable endUpdates];
    self.sortButton.enabled = ([_showList count] > 1);
}

- (void)_cancelButtonPressed:(id)sender
{
    [self _leaveMoveMode];
}

- (void)_leaveMoveMode
{
    _isMoveMode = NO;
    
    NSArray *visibleCells = [self.itemTable visibleCells];
    for(ItemDetailCell *cell in visibleCells) {
        cell.showSelectIndicator = NO;
    }
    
    self.navigationItem.rightBarButtonItem = _originRightBarButton;
    self.moveButton.tintColor = kColorDefaultBarButtonItemColor;
}

- (IBAction)countButtonPresses:(id)sender
{
    if(!_selectActionSheet) {
        _selectActionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Select Items", nil)
                                                         delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                           destructiveButtonTitle:nil
                                                otherButtonTitles:NSLocalizedString(@"Select All", nil),
                                                                  NSLocalizedString(@"Deselect All", nil), nil];
        _selectActionSheet.destructiveButtonIndex = 1;
    }
    
    [_selectActionSheet showInView:self.view];
}

- (IBAction)moveButtonPressed:(id)sender
{
    if(!_isMoveMode) {
        _isMoveMode = YES;
        
        //Show sliders
        NSArray *visibleCells = [self.itemTable visibleCells];
        NSIndexPath *index;
        DBFolderItem *item;
        SelectedFolderItem *selectedItem;
        for(ItemDetailCell *cell in visibleCells) {
            index = [self.itemTable indexPathForCell:cell];
            item = [_showList objectAtIndex:index.row];
            selectedItem = [_selectedItemMap objectForKey:item.objectID];
            if(selectedItem) {
                cell.showSelectIndicator = YES;
                
                cell.selectCount = selectedItem.selectCount;
            } else {
                cell.showSelectIndicator = NO;
            }
        }
        
        self.moveButton.tintColor = kColorDoneButton;
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                               target:self
                                                                                               action:@selector(_cancelButtonPressed:)];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:kMoveItemsNotification
                                                            object:nil
                                                          userInfo:[NSDictionary dictionaryWithObject:[_selectedItemMap allValues]
                                                                                               forKey:kSelectedItemsToMove]];
    }
}

- (IBAction)duplicateButtonPressed:(id)sender
{
    [self _leaveMoveMode];
    
    //for list order consistency, we go through the full list
    NSMutableArray *newItems = [NSMutableArray array];
    DBFolderItem *newItem;
    int nIndex = 0;
    ItemDetailCell *cell;
    for(DBFolderItem *item in _fullItemList) {
        if([_selectedItemMap objectForKey:item.objectID]) {
            newItem = [CoreDataDatabase duplicateItem:item];
            [newItems addObject:newItem];
            
            nIndex = [_showList indexOfObject:item];
            if(nIndex != NSNotFound) {
                cell = (ItemDetailCell *)[self.itemTable cellForRowAtIndexPath:[NSIndexPath indexPathForRow:nIndex inSection:0]];
                cell.isChecked = NO;
                [cell showSelectIndicator:NO animated:NO];
                cell.selectCount = item.count;
            }
        }
    }
    [CoreDataDatabase commitChanges:nil];
    
    [self.itemTable beginUpdates];
    NSMutableArray *indexPaths = [NSMutableArray array];
    
    [_selectedItemMap removeAllObjects];
    nIndex = 0;
    for(newItem in newItems) {
        [_selectedItemMap setObject:[[SelectedFolderItem alloc] initWithFolderItem:newItem] forKey:newItem.objectID];
        [_fullItemList insertObject:newItem atIndex:0];
        if(!newItem.isArchived) {
            [_unarchivedItemList insertObject:newItem atIndex:0];
        }
        [_folderItemSet addObject:newItem];
        
        [indexPaths addObject:[NSIndexPath indexPathForRow:nIndex inSection:0]];
        nIndex++;
    }
    
    [self.itemTable insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.itemTable endUpdates];
    [self.itemTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
    
    [[UIApplication sharedApplication] refreshApplicationBadgeNumber];
    
    [self updateBasicInfoStatistics];
    [_basicInfoCell updateFromLoadedBasicInfo:_basicInfoData animated:YES];
    
    [self.delegate itemBasicInfoUpdated:_basicInfo newData:_basicInfoData];
}

- (IBAction)archiveButtonPressed:(id)sender
{
    [self _leaveMoveMode];
    
    if(self.listTypeSegControl.selectedSegmentIndex == kListTypeUnarchive) {
        [self _archiveSelectedItems:YES];
    } else {
        BOOL allUnarchived = YES;
        BOOL allArchived = YES;
        
        if(self.listTypeSegControl.selectedSegmentIndex == kListTypeAll) {
            for(SelectedFolderItem *selectedItem in [_selectedItemMap allValues]) {
                if(selectedItem.folderItem.isArchived) {
                    allUnarchived = NO;
                } else {
                    allArchived = NO;
                }
            }
        }
        
        if(allUnarchived) {
            [self _archiveSelectedItems:YES];
        } else if(allArchived) {
            if(!_unarchiveActionSheet) {
                _unarchiveActionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Unarchive Items", nil)
                                                                  delegate:self
                                                         cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                    destructiveButtonTitle:nil
                                                         otherButtonTitles:NSLocalizedString(@"Unarchive", nil), nil];
            }
            
            [_unarchiveActionSheet showInView:self.view];
        } else {
            if(!_archiveActionSheet) {
                _archiveActionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Archive/Unarchive Items", nil)
                                                                  delegate:self
                                                         cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                    destructiveButtonTitle:nil
                                                         otherButtonTitles:NSLocalizedString(@"Archive", nil),
                                                                           NSLocalizedString(@"Unarchive", nil), nil];
            }
            
            [_archiveActionSheet showInView:self.view];
        }
    }
}

- (IBAction)deleteButtonPressed:(id)sender
{
    [self _leaveMoveMode];
    
    if(!_confirmDeletionActionSheet) {
        _confirmDeletionActionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Delete Items", nil)
                                                                  delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                    destructiveButtonTitle:NSLocalizedString(@"Delete", nil)
                                                         otherButtonTitles:nil];
    }
    
    [_confirmDeletionActionSheet showInView:self.view];
}

- (IBAction)sortButtonPressed:(id)sender
{
    if(!_readyToSort) {
        self.itemTable.userInteractionEnabled = NO;
        self.navigationItem.rightBarButtonItem.enabled = NO;
        self.toolbar.items = @[self.closeSortButton, self.leftBarSpace, self.sortButton];
        
        [UIView animateWithDuration:0.3f
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
                             CGRect frame = self.sortPickerView.frame;
                             frame.origin.y = frame.origin.y - frame.size.height + 44.0f;
                             self.sortPickerView.frame = frame;
                         } completion:^(BOOL finished) {
                             self.sortButton.tintColor = [UIColor colorWithRed:0.117f green:0.431f blue:1.0f alpha:1.0f];
                         }];
    } else {
        self.sortButton.tintColor = [UIColor blackColor];
        
        [UIView animateWithDuration:0.3f
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
                             CGRect frame = self.sortPickerView.frame;
                             frame.origin.y = frame.origin.y + frame.size.height - 44.0f;
                             self.sortPickerView.frame = frame;
                         } completion:^(BOOL finished) {
                             self.toolbar.items = @[self.leftBarSpace, self.listTypeBarButtonItem, self.rightBarSpace, self.sortButton];
                         }];
        
        //Check sort method and order has changed or not
        if(m_nNewSortOrderIndex == m_nCurrentSortOrderIndex &&
           m_nNewSortFieldIndex == m_nCurrentSortFieldIndex)
        {
            self.itemTable.userInteractionEnabled = YES;
            self.navigationItem.rightBarButtonItem.enabled = YES;
        } else {
            //Show HUD
            
            //Do sort
            [self sortAndLoadTable];
        }
    }
    
    _readyToSort = !_readyToSort;
}

- (IBAction)closeSortView:(id)sender
{
    _readyToSort = NO;
    self.sortButton.tintColor = [UIColor blackColor];
    
    [UIView animateWithDuration:0.3f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         CGRect frame = self.sortPickerView.frame;
                         frame.origin.y = frame.origin.y + frame.size.height - 44.0f;
                         self.sortPickerView.frame = frame;
                     } completion:^(BOOL finished) {
                         self.itemTable.userInteractionEnabled = YES;
                         self.navigationItem.rightBarButtonItem.enabled = YES;
                         self.toolbar.items = @[self.leftBarSpace, self.listTypeBarButtonItem, self.rightBarSpace, self.sortButton];
                         
                         //Recover sort picker
                         int buttonIndex = 0;
                         for(UIImageView *sortButton in _sortMethodButtons) {
                             if(buttonIndex == m_nCurrentSortFieldIndex) {
                                 sortButton.image = _selectedSortMethodImage;
                             } else {
                                 sortButton.image = _unselectedSortMethodImage;
                             }
                             
                             buttonIndex++;
                         }
                         
                         self.sortOrderSegCtrl.selectedSegmentIndex = m_nCurrentSortOrderIndex;
                     }];
}

- (void)_selectButton:(UIGestureRecognizer *)sender
{
    if(sender.state == UIGestureRecognizerStateChanged ||
       sender.state == UIGestureRecognizerStateEnded)
    {
        int nIndex = 0;
        UILabel *buttonTitle;
        for(UIImageView *sortButton in _sortMethodButtons) {
            buttonTitle = [_buttonLabels objectAtIndex:nIndex];
            
            if(sender.view == sortButton) {
                m_nNewSortFieldIndex = nIndex;
                sortButton.image = _selectedSortMethodImage;
            } else {
                sortButton.image = _unselectedSortMethodImage;
            }
            
            nIndex++;
        }
    }
}

- (IBAction)selectSortOrder:(UISegmentedControl *)sender
{
    m_nNewSortOrderIndex = sender.selectedSegmentIndex;
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
    if(buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
    
    if(actionSheet == _selectActionSheet) {
        [_selectedItemMap removeAllObjects];
        int nIndex = 0;
        ItemDetailCell *cell;
        
        switch (buttonIndex) {
            case kActionSelectAllIndex:
                if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                    [FlurryAnalytics logEvent:@"Select All"];
                }
                
                for(DBFolderItem *item in _showList) {
                    [_selectedItemMap setObject:[[SelectedFolderItem alloc] initWithFolderItem:item] forKey:item.objectID];
                    cell = (ItemDetailCell *)[self.itemTable cellForRowAtIndexPath:[NSIndexPath indexPathForRow:nIndex inSection:0]];
                    cell.isChecked = YES;
                    cell.selectCount = item.count;
                    
                    if(_isMoveMode) {
                        cell.showSelectIndicator = YES;
                    }
                    nIndex++;
                }
                
                self.selectButton.title = [NSString stringWithFormat:@"%d", [_selectedItemMap count]];
                break;
            case kActionDeselectAllIndex:
                if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                    [FlurryAnalytics logEvent:@"Deselect all"];
                }
                
                for(DBFolderItem *item in _showList) {
                    cell = (ItemDetailCell *)[self.itemTable cellForRowAtIndexPath:[NSIndexPath indexPathForRow:nIndex inSection:0]];
                    cell.isChecked = NO;
                    cell.selectCount = item.count;
                    cell.showSelectIndicator = NO;
                    nIndex++;
                }
                
                [self _dismissSelectToolbar];
                break;
            default:
                break;
        }
    } else if(actionSheet == _archiveActionSheet) {
        BOOL archived = (buttonIndex == kActionArchiveIndex) ? YES : NO;
        [self _archiveSelectedItems:archived];
    } else if(actionSheet == _unarchiveActionSheet) {
        [self _archiveSelectedItems:NO];
    } else if(actionSheet == _confirmDeletionActionSheet) {
        [self _deleteSelectedItems];
    }
}

- (void)_archiveSelectedItems:(BOOL)archived
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Archive items" timed:YES];
    }
    
    NSMutableArray *changedItemList = [NSMutableArray array];
    for(SelectedFolderItem *selectedItem in [_selectedItemMap allValues]) {
        if(selectedItem.folderItem.isArchived != archived) {
            selectedItem.folderItem.isArchived = archived;
            [selectedItem.folderItem addArchiveStatusChangeLog];
            selectedItem.folderItem.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
            [changedItemList addObject:selectedItem.folderItem];
        }
    }
    
    if([changedItemList count] > 0) {
        [_selectedItemMap removeAllObjects];
        [self _dismissSelectToolbar];
        
        [self.itemTable beginUpdates];
        NSMutableArray *indexPaths = [NSMutableArray array];
        for(DBFolderItem *item in changedItemList) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:[_fullItemList indexOfObject:item] inSection:0]];
            if(archived) {
                [_unarchivedItemList removeObject:item];
            } else {
                [_unarchivedItemList addObject:item];
            }
        }
        
        if(self.listTypeSegControl.selectedSegmentIndex == kListTypeAll) {
            [self.itemTable reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
        } else {
            //In unarchived list, it must be archive operation
            [self.itemTable deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        [self.itemTable endUpdates];
        
        [CoreDataDatabase commitChanges:nil];
        
        if([_unarchivedItemList count] == 0) {
            _showList = _fullItemList;
            self.listTypeSegControl.selectedSegmentIndex = kListTypeAll;
            
            [self.itemTable reloadData];
        }
        
        [[UIApplication sharedApplication] refreshApplicationBadgeNumber];
        
        [self updateBasicInfoStatistics];
        [_basicInfoCell updateFromLoadedBasicInfo:_basicInfoData animated:YES];
        [self.delegate itemBasicInfoUpdated:_basicInfo newData:_basicInfoData];
    }
}

- (void)_deleteSelectedItems
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Delete items" timed:YES];
    }
    
    NSMutableArray *deletedItems = [NSMutableArray array];
    NSMutableArray *deletedIndexPaths = [NSMutableArray array];
    DBFolderItem *item;
    
    [self.itemTable beginUpdates];
    for(SelectedFolderItem *selectedItem in [_selectedItemMap allValues]) {
        item = selectedItem.folderItem;
        [deletedIndexPaths addObject:[NSIndexPath indexPathForRow:[_showList indexOfObject:item]
                                                        inSection:0]];
        [deletedItems addObject:item];
    }

    for(item in deletedItems) {
        [_folderItemSet removeObject:item];
        [_fullItemList removeObject:item];
        if(!item.isArchived) {
            [_unarchivedItemList removeObject:item];
        }
        
        [CoreDataDatabase removeItem:item];
    }
    [CoreDataDatabase commitChanges:nil];
    [self.itemTable deleteRowsAtIndexPaths:deletedIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.itemTable endUpdates];
    
    [[UIApplication sharedApplication] refreshApplicationBadgeNumber];

    [self updateBasicInfoStatistics];
    [_basicInfoCell updateFromLoadedBasicInfo:_basicInfoData animated:YES];
    [self.delegate itemBasicInfoUpdated:_basicInfo newData:_basicInfoData];
    
    [self _dismissSelectToolbar];
}
//--------------------------------------------------------------
//  [END] UIActionSheetDelegate
//==============================================================

//==============================================================
//  [BEGIN] EditItemViewControllerDelegate
#pragma mark - EditItemViewControllerDelegate
//--------------------------------------------------------------
- (void)cancelEditItem:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)finishEditItem:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    [self updateBasicInfoStatistics];
    [self updateBasicInfoData];
    [_basicInfoCell updateFromLoadedBasicInfo:_basicInfoData animated:NO];
    [self.delegate itemBasicInfoUpdated:_basicInfo newData:_basicInfoData];

    [self doSortAndLoadTable];
    
    [[UIApplication sharedApplication] refreshApplicationBadgeNumber];
}
//--------------------------------------------------------------
//  [END] EditItemViewControllerDelegate
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
//  [BEGIN] Notification receivers
#pragma mark -
#pragma mark Notification receivers
//--------------------------------------------------------------

//Remember to call updateFromLoadedBasicInfo to update UI
- (void)updateBasicInfoStatistics
{
    _basicInfoData.priceStatistics = [CoreDataDatabase getPriceStatisticsOfBasicInfo:_basicInfo];
    _basicInfoData.nextExpiryDate = [CoreDataDatabase getNextExpiryDateOfBasicInfo:_basicInfo];
}

- (void)updateBasicInfoData
{
    _basicInfoData.name = _basicInfo.name;
    _basicInfoData.barcode = _basicInfo.barcode;
    _basicInfoData.isFavorite = _basicInfo.isFavorite;
    _basicInfoData.isInShoppingList = (_basicInfo.shoppingItem != nil);
    
    UIImage *resizedImage = [[_basicInfo getDisplayImage] resizedImage:CGSizeMake(kImageWidth<<1, kImageHeight<<1)
                                                  interpolationQuality:kCGInterpolationHigh];
    _basicInfoData.image = [resizedImage roundedCornerImage:18 borderSize:1];
}

- (BOOL)shouldHandleChangesForFolderItem:(DBFolderItem *)item
{
    //Since this checking is used to handle notification of the folder item.
    //Child classes may have it's own condition
    if([item.basicInfo.objectID.URIRepresentation isEqual:_basicInfo.objectID.URIRepresentation]) {
        return YES;
    }
    
    return NO;
}

- (void)_receiveManagedObjectContextDidSaveNotification:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    DBFolderItem *folderItem = nil;
    DBItemBasicInfo *basicInfo = nil;
    BOOL shouldReloadTable = NO;
    
    NSSet *insertedObjects = [userInfo objectForKey:NSInsertedObjectsKey];
    for(NSManagedObject *object in insertedObjects) {
        if(object.managedObjectContext == nil ||
           [object.objectID isTemporaryID])
        {
            continue;
        }
        
        //Copy and add new item will comes here
        
        if([object class] == [DBFolderItem class]) {            //update statistics
            folderItem = (DBFolderItem *)object;
            basicInfo = folderItem.basicInfo;
            
            if([self shouldHandleChangesForFolderItem:folderItem]) {
                //Add item to list
                [_folderItemSet addObject:object];
                
                //Update statistics of basicInfo
                [self updateBasicInfoStatistics];
                [_basicInfoCell updateFromLoadedBasicInfo:_basicInfoData animated:YES];
                
                shouldReloadTable = YES;
            }
        } else if([object class] != [DBItemBasicInfo class]) {  //User changes the besicInfo to anther one
            basicInfo = (DBItemBasicInfo *)object;
            if([basicInfo.objectID.URIRepresentation isEqual:_basicInfo.objectID.URIRepresentation]) {
                [_basicInfo.managedObjectContext refreshObject:_basicInfo mergeChanges:YES];
                [self updateBasicInfoData];
            }
        }
    }
    
    NSSet *updatedObjects = [userInfo objectForKey:NSUpdatedObjectsKey];
    
    for(NSManagedObject *object in updatedObjects) {
        if(object.managedObjectContext == nil ||
           [object.objectID isTemporaryID])
        {
            continue;
        }
        
        if([object class] == [DBFolderItem class]) {            //update statistics
            folderItem = (DBFolderItem *)object;
            basicInfo = folderItem.basicInfo;
            
            if([self shouldHandleChangesForFolderItem:folderItem]) {
                //Update statistics of basicInfo
                [self updateBasicInfoStatistics];
                [_basicInfoCell updateFromLoadedBasicInfo:_basicInfoData animated:YES];
                
                shouldReloadTable = YES;
            }
        } else if([object class] != [DBItemBasicInfo class]) {  //update basic info
            basicInfo = (DBItemBasicInfo *)object;
            if([basicInfo.objectID.URIRepresentation isEqual:_basicInfo.objectID.URIRepresentation]) {
                [_basicInfo.managedObjectContext refreshObject:_basicInfo mergeChanges:YES];
                [self updateBasicInfoData];
            }
        }
    }
    
    if(shouldReloadTable) {
        [self doSortAndLoadTable];
    }
}
//--------------------------------------------------------------
//  [END] Notification receivers
//==============================================================
@end
