//
//  ExpiryListViewController.m
//  ShopFolder
//
//  Created by Michael on 2012/10/31.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "ExpiryListViewController.h"
#import "CoreDataDatabase.h"
#import "TimeUtil.h"
#import "FlurryAnalytics.h"
#import "PreferenceConstant.h"
#import "ImageParameters.h"
#import "ColorConstant.h"
#import <QuartzCore/QuartzCore.h>
#import "DBFolderItem+expiryOperations.h"
#import "DBItemBasicInfo+SetAdnGet.h"
#import "UIView+ConverToImage.h"
#import "LiteLimitations.h"
#import "ExpiryItemCell.h"
#import "UIImage+Resize.h"
#import "UIImage+RoundedCorner.h"
#import "PreferenceConstant.h"
#import "DBFolderItem+ChangeLog.h"

#ifdef _LITE_
#import "LiteLimitations.h"
#endif

static int g_nRealExpiredSection        = 0;
static int g_nRealExpiresTodaySection   = 1;
static int g_nRealNearExpiredSection    = 2;

#define kLargeImageLabelBackgroundColor [UIColor colorWithWhite:0 alpha:0.35f]

#define kItemNameLabelHeight    60.0f

@interface ExpiryListViewController ()
- (DBFolderItem *)_getFolderItemAtIndexPath:(NSIndexPath *)indexPath;

- (void)_tapOnLargeImagePreview:(UITapGestureRecognizer *)sender;
- (void)_dismissImagePreviewAnimated:(BOOL)animate;

- (IBAction)_closeButtonPressed:(id)sender;
@end

@implementation ExpiryListViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _itemsExpired = [NSMutableArray array];
        _itemsExpireToday = [NSMutableArray array];
        _itemsNearExpired = [NSMutableArray array];
        
        _headerLabelFont = [UIFont boldSystemFontOfSize:20.0f];
        _headerHeight = _headerLabelFont.lineHeight + 4.0f;
    }
    return self;
}

- (void)viewDidUnload {
    [self setTable:nil];
    [self setCloseButton:nil];
    [super viewDidUnload];
    
    _largeImageView = nil;
    _largeImageBackgroundView = nil;
    _imageForNoImageLabel = nil;
    _imageLabelBackgroundView = nil;
    _imageLabel = nil;
    _tapToDismissLabel = nil;
    _emptyImage = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.navigationController.navigationBar.tintColor = kColorNavigationBarTintColor;
    self.title = NSLocalizedString(@"Expiry List", nil);
    
    if([self.navigationController.viewControllers count] == 1) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", nil)
                                                                                 style:UIBarButtonItemStyleBordered
                                                                                target:self
                                                                                action:@selector(_closeButtonPressed:)];
    }
    
    g_nRealExpiredSection        = 0;
    g_nRealExpiresTodaySection   = 1;
    g_nRealNearExpiredSection    = 2;
    
    //Get expired items which are not in locked folders
    [_itemsExpired removeAllObjects];
    for(DBFolderItem *folderItem in [CoreDataDatabase getExpiredItemsBeforeToday]) {
        if([folderItem.folder.password length] == 0) {
            [_itemsExpired addObject:folderItem];
        }
    }
    
    if([_itemsExpired count] == 0) {
        g_nRealExpiredSection = -1;
        g_nRealExpiresTodaySection--;
        g_nRealNearExpiredSection--;
    }
    
    [_itemsExpireToday removeAllObjects];
    DBNotifyDate *notifyDate = [CoreDataDatabase getNotifyDateOfDate:[TimeUtil today]];
    for(DBFolderItem *folderItem in [notifyDate.expireItems allObjects]) {
        if([folderItem.folder.password length] == 0 &&
           folderItem.count > 0 &&
           !folderItem.isArchived)
        {
            [_itemsExpireToday addObject:folderItem];
        }
    }
    
    if([_itemsExpireToday count] == 0) {
        g_nRealExpiresTodaySection = -1;
        g_nRealNearExpiredSection--;
    }
    
    [_itemsNearExpired removeAllObjects];
    for(DBFolderItem *folderItem in [notifyDate.nearExpireItems allObjects]) {
        if([folderItem.folder.password length] == 0  &&
           folderItem.count > 0 &&
           !folderItem.isArchived)
        {
            [_itemsNearExpired addObject:folderItem];
        }
    }
    
    if([_itemsNearExpired count] == 0) {
        g_nRealNearExpiredSection = -1;
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:[[TimeUtil today] timeIntervalSinceReferenceDate]
                                               forKey:kLastExpiryListShowTime];
    [[NSUserDefaults standardUserDefaults] synchronize];
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
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kExpiryItemCellHeight;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
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
    static NSString *CellTableIdentitifier = @"ExpiryItemCellIdentifier";
    ExpiryItemCell *cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
    if(cell == nil) {
        cell = [[ExpiryItemCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellTableIdentitifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.delegate = self;
    }
    
    DBFolderItem *item = [self _getFolderItemAtIndexPath:indexPath];
    cell.name = item.basicInfo.name;
    cell.barcode = item.basicInfo.barcode;
    cell.count = item.count;
    [cell setPrice:item.price withCurrencyCode:item.currencyCode];
    cell.expiryDate = [NSDate dateWithTimeIntervalSinceReferenceDate:item.expiryDate.date];
    [cell setIsFavorite:item.basicInfo.isFavorite];
    [cell setIsInShoppingList:(item.basicInfo.shoppingItem != nil)];
    
    UIImage *resizedImage = [[item.basicInfo getDisplayImage] resizedImage:CGSizeMake(kImageWidth<<1, kImageHeight<<1)
                                                  interpolationQuality:kCGInterpolationHigh];
    UIImage *finalImage = [resizedImage roundedCornerImage:18 borderSize:1];
    cell.thumbImage = finalImage;
    
    [cell updateUI];
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    int nSection = 0;
    if([_itemsExpired count] > 0) {
        nSection++;
    }
    
    if([_itemsExpireToday count] > 0) {
        nSection++;
    }
    
    if([_itemsNearExpired count] > 0) {
        nSection++;
    }
    
    return nSection;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(section == g_nRealExpiredSection) {
        return [_itemsExpired count];
    } else if(section == g_nRealExpiresTodaySection) {
        return [_itemsExpireToday count];
    } else if(section == g_nRealNearExpiredSection) {
        return [_itemsNearExpired count];
    }
    
    return 0;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UILabel *label = nil;
    CGRect frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, _headerHeight);
    UIView *view = [[UIView alloc] initWithFrame:frame];
    UIColor *centerColor;
    UIColor *edgeColor;
    
    if(section == g_nRealExpiredSection) {
        label = [[UILabel alloc] initWithFrame:frame];
        label.textColor = [UIColor whiteColor];
        label.text = NSLocalizedString(@"Expired", nil);

        edgeColor = [UIColor colorWithHue:0.01f saturation:0.3f brightness:1.0f alpha:1.0f];
        centerColor = [UIColor colorWithHue:0.01f saturation:1.0f brightness:1.0f alpha:1.0f];
    } else if(section == g_nRealExpiresTodaySection) {
        label = [[UILabel alloc] initWithFrame:frame];
        label.textColor = [UIColor whiteColor];
        label.text = NSLocalizedString(@"Expires Today", nil);
        
        edgeColor = [UIColor colorWithHue:0.05f saturation:0.3f brightness:1.0f alpha:1.0f];
        centerColor = [UIColor colorWithHue:0.05f saturation:1.0f brightness:1.0f alpha:1.0f];
    } else if(section == g_nRealNearExpiredSection) {
        label = [[UILabel alloc] initWithFrame:frame];
        label.textColor = [UIColor whiteColor];;
        label.text = NSLocalizedString(@"Near-Expired", nil);
        
        edgeColor = [UIColor colorWithHue:0.09f saturation:0.3f brightness:1.0f alpha:1.0f];
        centerColor = [UIColor colorWithHue:0.09f saturation:1.0f brightness:1.0f alpha:1.0f];
    }
    
    if(label) {
        label.backgroundColor = [UIColor clearColor];
        label.textAlignment = UITextAlignmentCenter;
        label.font = _headerLabelFont;
        label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
        
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.startPoint = CGPointMake(0.0f, 0.5f);
        gradient.endPoint = CGPointMake(1.0f, 0.5f);
        
        gradient.frame = label.frame;
        gradient.colors = [NSArray arrayWithObjects:
                           (id)edgeColor.CGColor,
                           (id)centerColor.CGColor,
                           (id)centerColor.CGColor,
                           (id)edgeColor.CGColor, nil];
        gradient.locations = @[@0.0f, @0.3f, @0.7f, @1.0f];
        [view.layer addSublayer:gradient];
        [view addSubview:label];
    }
    
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return _headerHeight;
}

//- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    return NSLocalizedString(@"Archive", nil);
//}
//
//- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    if(editingStyle == UITableViewCellEditingStyleDelete) {
//        DBFolderItem *item = [self _getFolderItemAtIndexPath:indexPath];
//        
//        item.isArchived = YES;
//        if([CoreDataDatabase commitChanges:nil]) {
//            if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
//                [FlurryAnalytics logEvent:@"Swipe to archive item"];
//            }
//            
//            BOOL deleteSection = NO;
//            
//            if(indexPath.section == g_nRealExpiredSection) {
//                [_itemsExpired removeObject:item];
//                
//                if([_itemsExpired count] == 0) {
//                    [self.table beginUpdates];
//                    
//                    [self.table deleteSections:[NSIndexSet indexSetWithIndex:g_nRealExpiredSection]
//                              withRowAnimation:UITableViewRowAnimationAutomatic];
//                    
//                    g_nRealExpiredSection = -1;
//                    g_nRealExpiresTodaySection--;
//                    g_nRealNearExpiredSection--;
//                    
//                    [self.table endUpdates];
//                    
//                    deleteSection = YES;
//                }
//            } else if(indexPath.section == g_nRealExpiresTodaySection) {
//                [_itemsExpireToday removeObject:item];
//                
//                if([_itemsExpireToday count] == 0) {
//                    [self.table beginUpdates];
//                    
//                    [self.table deleteSections:[NSIndexSet indexSetWithIndex:g_nRealExpiresTodaySection]
//                              withRowAnimation:UITableViewRowAnimationAutomatic];
//                    
//                    g_nRealExpiresTodaySection = -1;
//                    g_nRealNearExpiredSection--;
//                    
//                    [self.table endUpdates];
//                    
//                    deleteSection = YES;
//                }
//            } else if(indexPath.section == g_nRealNearExpiredSection) {
//                [_itemsNearExpired removeObject:item];
//                
//                if([_itemsNearExpired count] == 0) {
//                    [self.table beginUpdates];
//                    [self.table deleteSections:[NSIndexSet indexSetWithIndex:g_nRealNearExpiredSection]
//                              withRowAnimation:UITableViewRowAnimationAutomatic];
//                    
//                    g_nRealNearExpiredSection = -1;
//                    
//                    [self.table endUpdates];
//                    
//                    deleteSection = YES;
//                }
//            }
//            
//            if([_itemsExpired count] == 0 &&
//               [_itemsExpireToday count] == 0 &&
//               [_itemsNearExpired count] == 0)
//            {
//                [self.delegate expiryListShouldDismiss];
//            } else if(!deleteSection) {
//                [self.table beginUpdates];
//                [self.table deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
//                [self.table endUpdates];
//            }
//        } else {
//            item.isArchived = NO;
//        }
//    }
//}
//--------------------------------------------------------------
//  [END] UITableViewDataSource
//==============================================================

//==============================================================
//  [BEGIN] ExpiryItemCellDelegate
#pragma mark - ExpiryItemCellDelegate
//--------------------------------------------------------------
- (void)cartButtonPressed:(ExpiryItemCell *)cell
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
    NSIndexPath *index = [self.table indexPathForCell:cell];
    DBFolderItem *item = [self _getFolderItemAtIndexPath:index];
    DBItemBasicInfo *basicInfo = item.basicInfo;
    
    if(basicInfo.shoppingItem) {
        //Remove shopping item
        [CoreDataDatabase removeShoppingItem:basicInfo.shoppingItem updatePositionOfRestItems:YES];
        basicInfo.shoppingItem = nil;
    } else {
        //Add shopping item
        basicInfo.shoppingItem = [CoreDataDatabase obtainShoppingItem];
    }
    basicInfo.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
    
    if([CoreDataDatabase commitChanges:nil]) {
        //Update UI
        [cell setIsInShoppingList:(basicInfo.shoppingItem != nil)];
    } else {
        [CoreDataDatabase cancelUnsavedChanges];
    }
}

- (void)favoriteButtonPressed:(ExpiryItemCell *)sender
{
    NSIndexPath *index = [self.table indexPathForCell:sender];
    DBFolderItem *item = [self _getFolderItemAtIndexPath:index];
    
    item.basicInfo.isFavorite = !item.basicInfo.isFavorite;
    item.basicInfo.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
    
    if([CoreDataDatabase commitChanges:nil]) {
        //Update UI
        [sender setIsFavorite:item.basicInfo.isFavorite];
    } else {
        [CoreDataDatabase cancelUnsavedChanges];
    }
}

- (void)archiveButtonPressed:(ExpiryItemCell *)sender
{
    NSIndexPath *indexPath = [self.table indexPathForCell:sender];
    DBFolderItem *item = [self _getFolderItemAtIndexPath:indexPath];
    item.isArchived = YES;
    [item addArchiveStatusChangeLog];
    item.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
    
    if([CoreDataDatabase commitChanges:nil]) {
        BOOL deleteSection = NO;
        
        if(indexPath.section == g_nRealExpiredSection) {
            [_itemsExpired removeObject:item];
            
            if([_itemsExpired count] == 0) {
                [self.table beginUpdates];
                
                [self.table deleteSections:[NSIndexSet indexSetWithIndex:g_nRealExpiredSection]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
                
                g_nRealExpiredSection = -1;
                g_nRealExpiresTodaySection--;
                g_nRealNearExpiredSection--;
                
                [self.table endUpdates];
                
                deleteSection = YES;
            }
        } else if(indexPath.section == g_nRealExpiresTodaySection) {
            [_itemsExpireToday removeObject:item];
            
            if([_itemsExpireToday count] == 0) {
                [self.table beginUpdates];
                
                [self.table deleteSections:[NSIndexSet indexSetWithIndex:g_nRealExpiresTodaySection]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
                
                g_nRealExpiresTodaySection = -1;
                g_nRealNearExpiredSection--;
                
                [self.table endUpdates];
                
                deleteSection = YES;
            }
        } else if(indexPath.section == g_nRealNearExpiredSection) {
            [_itemsNearExpired removeObject:item];
            
            if([_itemsNearExpired count] == 0) {
                [self.table beginUpdates];
                [self.table deleteSections:[NSIndexSet indexSetWithIndex:g_nRealNearExpiredSection]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
                
                g_nRealNearExpiredSection = -1;
                
                [self.table endUpdates];
                
                deleteSection = YES;
            }
        }
        
        if([_itemsExpired count] == 0 &&
           [_itemsExpireToday count] == 0 &&
           [_itemsNearExpired count] == 0)
        {
            [self.delegate expiryListShouldDismiss];
        } else if(!deleteSection) {
            [self.table beginUpdates];
            [self.table deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            [self.table endUpdates];
        }
    } else {
        [CoreDataDatabase cancelUnsavedChanges];
    }
}

- (void)imageTouched:(ExpiryItemCell *)cell
{
    NSIndexPath *indexPath = [self.table indexPathForCell:cell];
    DBFolderItem *item = [self _getFolderItemAtIndexPath:indexPath];
    DBItemBasicInfo *basicInfo = item.basicInfo;
    if([basicInfo getDisplayImage] == nil) {
        return;
    }
    
    [self.table scrollRectToVisible:[cell convertRect:cell.bounds toView:self.table] animated:YES];
    
    CGRect cellFrame = [cell convertRect:cell.bounds toView:self.table];
    
    //Get visible position related to table view
    CGRect cellImageFrame = [cell convertRect:cell.imageViewFrame toView:self.table];
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
}
//--------------------------------------------------------------
//  [END] ExpiryItemCellDelegate
//==============================================================

//==============================================================
//  [BEGIN] Private Methods
#pragma mark - Private Methods
//--------------------------------------------------------------
- (DBFolderItem *)_getFolderItemAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == g_nRealExpiredSection) {
        return [_itemsExpired objectAtIndex:indexPath.row];
    } else if(indexPath.section == g_nRealExpiresTodaySection) {
        return [_itemsExpireToday objectAtIndex:indexPath.row];
    } else if(indexPath.section == g_nRealNearExpiredSection) {
        return [_itemsNearExpired objectAtIndex:indexPath.row];
    }
    
    return nil;
}

- (void)_tapOnLargeImagePreview:(UITapGestureRecognizer *)sender
{
    [self _dismissImagePreviewAnimated:YES];
}

- (void)_dismissImagePreviewAnimated:(BOOL)animate
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
//--------------------------------------------------------------
//  [END] Private Methods
//==============================================================

//==============================================================
//  [BEGIN] IBActions
#pragma mark - IBActions
//--------------------------------------------------------------
- (IBAction)_closeButtonPressed:(id)sender
{
    [self.delegate expiryListShouldDismiss];
}
//--------------------------------------------------------------
//  [END] IBActions
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
@end
