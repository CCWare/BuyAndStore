//
//  BasicInfoListViewController.m
//  ShopFolder
//
//  Created by Michael on 2012/11/14.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "BasicInfoListViewController.h"
#import "BasicInfoCell.h"
#import "NotificationConstant.h"
#import "DBFolderItem.h"
#import "DBItemBasicInfo+SetAdnGet.h"
#import "CoreDataDatabase.h"
#import "ColorConstant.h"
#import <QuartzCore/QuartzCore.h>   //For using CALayer
#import "UIView+ConverToImage.h"
#import "UIImage+RoundedCorner.h"
#import "UIImage+Resize.h"
#import "PreferenceConstant.h"

#ifdef _LITE_
#import "LiteLimitations.h"
#endif

#define kItemNameLabelHeight    60.0f

@interface BasicInfoListViewController ()
- (void)_tapOnLargeImagePreview:(UITapGestureRecognizer *)sender;
- (void)_dismissImagePreviewAnimated:(BOOL)animate;
@end

@implementation BasicInfoListViewController
@synthesize table;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:@"BasicInfoListViewController" bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        loadBasicInfoQueue = dispatch_queue_create("LoadBasicInfoQueue", NULL);
        loadedBasicInfoMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)viewDidUnload {
    [self setTable:nil];
    
    [super viewDidUnload];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.navigationController.navigationBar.tintColor = kColorNavigationBarTintColor;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    tableImage = [self.table convertToImage];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    tableImage = [self.table convertToImage];
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
    indexPathOfEditBasicInfo = indexPath;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kBasicInfoCellHeight;
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
    static NSString *CellTableIdentitifier = @"BasicInfoCellIdentifier";
    BasicInfoCell *cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
    if(cell == nil) {
        cell = [[BasicInfoCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellTableIdentitifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.showNextExpiredTime = YES;
        cell.showExpiryInformation = YES;
        cell.delegate = self;
    }
    
    [self setCell:cell withIndexPath:indexPath];
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [basicInfoIDs count];
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(editingStyle == UITableViewCellEditingStyleDelete) {
    }
}
//--------------------------------------------------------------
//  [END] UITableViewDataSource
//==============================================================

//==============================================================
//  [BEGIN] Instance functions
#pragma mark - Instance functions
//--------------------------------------------------------------
- (void)setCell:(BasicInfoCell *)cell withIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObjectID *basicInfoID = [basicInfoIDs objectAtIndex:indexPath.row];
    LoadedBasicInfoData *loadedInfo = [loadedBasicInfoMap valueForKey:[[basicInfoID URIRepresentation] path]];
    [cell updateFromLoadedBasicInfo:loadedInfo animated:NO];
}

- (LoadedBasicInfoData *)updateBasicInfo:(DBItemBasicInfo *)basicInfo fullyUpdated:(BOOL)isFull
{
    LoadedBasicInfoData *info = [loadedBasicInfoMap valueForKey:[[basicInfo.objectID URIRepresentation] path]];
    if(info == nil) {
        info = [LoadedBasicInfoData new];
        [loadedBasicInfoMap setValue:info forKey:[[basicInfo.objectID URIRepresentation] path]];
    }
    
    info.name = basicInfo.name;
    info.barcode = basicInfo.barcode;
    info.isInShoppingList = (basicInfo.shoppingItem != nil);
    info.isFavorite = basicInfo.isFavorite;
    
    if(isFull) {
        UIImage *resizedImage = [[basicInfo getDisplayImage] resizedImage:CGSizeMake(kImageWidth<<1, kImageHeight<<1)
                                                     interpolationQuality:kCGInterpolationHigh];
        info.image = [resizedImage roundedCornerImage:18 borderSize:1];
        info.priceStatistics = [CoreDataDatabase getPriceStatisticsOfBasicInfo:basicInfo];
        info.nextExpiryDate = [CoreDataDatabase getNextExpiryDateOfBasicInfo:basicInfo];
        info.isFullyLoaded = isFull;
    }
    
    return info;
}

- (BOOL)shouldHandleFolderItem:(DBFolderItem *)folderItem
{
    return YES;
}
//--------------------------------------------------------------
//  [END] Instance functions
//==============================================================

//==============================================================
//  [BEGIN] BasicInfoCellDelegate
#pragma mark - BasicInfoCellDelegate
//--------------------------------------------------------------
- (void)imageTouched:(BasicInfoCell *)cell
{
    _previewCellIndex = [self.table indexPathForCell:cell];
    NSManagedObjectID *objectID = [basicInfoIDs objectAtIndex:_previewCellIndex.row];
    DBItemBasicInfo *basicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:objectID];
    
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

- (void)editButtonPressed:(BasicInfoCell *)sender
{
    indexPathOfEditBasicInfo = [self.table indexPathForCell:sender];
    if(indexPathOfEditBasicInfo) {
        NSManagedObjectID *objectID = [basicInfoIDs objectAtIndex:indexPathOfEditBasicInfo.row];
        DBItemBasicInfo *basicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:objectID];
        if(basicInfo) {
            EditBasicInfoViewController *editBasicInfoVC = [[EditBasicInfoViewController alloc] initWithItemBasicInfo:basicInfo];
            editBasicInfoVC.delegate = self;
            
            UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:editBasicInfoVC];
            [self presentViewController:navCon animated:YES completion:NULL];
        }
    }
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
    BasicInfoCell *cell = (BasicInfoCell *)sender;
    NSIndexPath *index = [self.table indexPathForCell:cell];
    NSManagedObjectID *objectID = [basicInfoIDs objectAtIndex:index.row];
    DBItemBasicInfo *basicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:objectID];
    
    if(basicInfo.shoppingItem) {
        //Remove shopping item
        [CoreDataDatabase removeShoppingItem:basicInfo.shoppingItem updatePositionOfRestItems:YES];
        basicInfo.shoppingItem = nil;
    } else {
        //Add shopping item
        basicInfo.shoppingItem = [CoreDataDatabase obtainShoppingItem];
//        [CoreDataDatabase moveShoppingItem:basicInfo.shoppingItem to:0];
    }
    basicInfo.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
    
    LoadedBasicInfoData *loadedInfo = [loadedBasicInfoMap valueForKey:[basicInfo.objectID.URIRepresentation path]];
    loadedInfo.isInShoppingList = (basicInfo.shoppingItem != nil);
    
    if([CoreDataDatabase commitChanges:nil]) {
        //Update UI
        [cell setIsInShoppingList:(basicInfo.shoppingItem != nil)];
    } else {
        [CoreDataDatabase cancelUnsavedChanges];
    }
}

- (void)favoriteButtonPressed:(id)sender
{
    BasicInfoCell *cell = (BasicInfoCell *)sender;
    NSIndexPath *index = [self.table indexPathForCell:cell];
    NSManagedObjectID *objectID = [basicInfoIDs objectAtIndex:index.row];
    DBItemBasicInfo *basicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:objectID];
    
    basicInfo.isFavorite = !basicInfo.isFavorite;
    basicInfo.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
    
    LoadedBasicInfoData *loadedInfo = [loadedBasicInfoMap valueForKey:[basicInfo.objectID.URIRepresentation path]];
    loadedInfo.isFavorite = basicInfo.isFavorite;
    
    if([CoreDataDatabase commitChanges:nil]) {
        //Update UI
        [cell setIsFavorite:basicInfo.isFavorite];
    } else {
        [CoreDataDatabase cancelUnsavedChanges];
    }
}
//--------------------------------------------------------------
//  [END] BasicInfoCellDelegate
//==============================================================

//==============================================================
//  [BEGIN] FolderItemListViewControllerDelegate
#pragma mark - FolderItemListViewControllerDelegate
//--------------------------------------------------------------
- (void)itemBasicInfoUpdated:(DBItemBasicInfo *)basicInfo newData:(LoadedBasicInfoData *)info
{
    [loadedBasicInfoMap setValue:info forKey:[[basicInfo.objectID URIRepresentation] path]];
    
    int nIndex = [basicInfoIDs indexOfObject:basicInfo.objectID];
    if(nIndex != NSNotFound) {
        if(indexPathOfEditBasicInfo.row == nIndex) {
            [self.table beginUpdates];
            [self.table reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:nIndex inSection:0]]
                              withRowAnimation:UITableViewRowAnimationNone];
            [self.table endUpdates];
        } else {
            //Change to another item in the list, so remove the original one
            DBItemBasicInfo *oldBasicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:
                                                                [basicInfoIDs objectAtIndex:indexPathOfEditBasicInfo.row]];
            NSSet *folderItems = [NSSet setWithSet:oldBasicInfo.folderItems];
            for(DBFolderItem *item in folderItems) {
                if([self shouldHandleFolderItem:item]) {
                    item.basicInfo = basicInfo;
                }
            }
            [CoreDataDatabase commitChanges:nil];
            
            [self.table beginUpdates];
            [self.table reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:nIndex inSection:0]]
                              withRowAnimation:UITableViewRowAnimationNone];
            [self.table endUpdates];
            
            [self.table beginUpdates];
            [loadedBasicInfoMap removeObjectForKey:[oldBasicInfo.objectID.URIRepresentation path]];
            [basicInfoIDs removeObjectAtIndex:indexPathOfEditBasicInfo.row];
            [self.table deleteRowsAtIndexPaths:@[indexPathOfEditBasicInfo] withRowAnimation:UITableViewRowAnimationNone];
            [self.table endUpdates];
            
            indexPathOfEditBasicInfo = [NSIndexPath indexPathForRow:nIndex inSection:0];
        }
    } else {    //Change to another basicInfo which is not in the list
        //Remove old item
        DBItemBasicInfo *oldBasicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:
                                                            [basicInfoIDs objectAtIndex:indexPathOfEditBasicInfo.row]];
        NSSet *folderItems = [NSSet setWithSet:oldBasicInfo.folderItems];
        for(DBFolderItem *item in folderItems) {
            if([self shouldHandleFolderItem:item]) {
                item.basicInfo = basicInfo;
            }
        }
        [CoreDataDatabase commitChanges:nil];
        
        [loadedBasicInfoMap removeObjectForKey:[oldBasicInfo.objectID.URIRepresentation path]];
        
        //Add new item
        [self.table beginUpdates];
        [basicInfoIDs replaceObjectAtIndex:indexPathOfEditBasicInfo.row withObject:basicInfo.objectID];
        [self.table reloadRowsAtIndexPaths:@[indexPathOfEditBasicInfo] withRowAnimation:UITableViewRowAnimationNone];
        [self.table endUpdates];
        
        indexPathOfEditBasicInfo = [NSIndexPath indexPathForRow:0 inSection:0];
    }
}
//--------------------------------------------------------------
//  [END] FolderItemListViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] EditBasicInfoViewControllerDelegate
#pragma mark - EditBasicInfoViewControllerDelegate
//--------------------------------------------------------------
- (void)cancelEditBasicInfo:(id)sender
{
    indexPathOfEditBasicInfo = nil;
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)finishEditBasicInfo:(id)sender changedBasicIndo:(DBItemBasicInfo *)basicInfo
{
    int nIndex = [basicInfoIDs indexOfObject:basicInfo.objectID];
    if(nIndex != NSNotFound) {
        if(indexPathOfEditBasicInfo.row == nIndex) {
            [self updateBasicInfo:basicInfo fullyUpdated:YES];
            
            [self.table beginUpdates];
            [self.table reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:nIndex inSection:0]]
                              withRowAnimation:UITableViewRowAnimationNone];
            [self.table endUpdates];
        } else {
            //Change to another item in the list, so remove the original one
            DBItemBasicInfo *oldBasicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:
                                                                [basicInfoIDs objectAtIndex:indexPathOfEditBasicInfo.row]];
            NSSet *folderItems = [NSSet setWithSet:oldBasicInfo.folderItems];
            for(DBFolderItem *item in folderItems) {
                if([self shouldHandleFolderItem:item]) {
                    item.basicInfo = basicInfo;
                }
            }
            [CoreDataDatabase commitChanges:nil];
            
            [self.table beginUpdates];
            [self updateBasicInfo:basicInfo fullyUpdated:YES];
            [self.table reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:nIndex inSection:0]]
                              withRowAnimation:UITableViewRowAnimationNone];
            [self.table endUpdates];
            
            [self.table beginUpdates];
            [loadedBasicInfoMap removeObjectForKey:[oldBasicInfo.objectID.URIRepresentation path]];
            [basicInfoIDs removeObjectAtIndex:indexPathOfEditBasicInfo.row];
            [self.table deleteRowsAtIndexPaths:@[indexPathOfEditBasicInfo] withRowAnimation:UITableViewRowAnimationNone];
            [self.table endUpdates];
        }
    } else {    //Change to another basicInfo which is not in the list
        //Remove old item
        DBItemBasicInfo *oldBasicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:
                                                            [basicInfoIDs objectAtIndex:indexPathOfEditBasicInfo.row]];
        NSSet *folderItems = [NSSet setWithSet:oldBasicInfo.folderItems];
        for(DBFolderItem *item in folderItems) {
            if([self shouldHandleFolderItem:item]) {
                item.basicInfo = basicInfo;
            }
        }
        [CoreDataDatabase commitChanges:nil];
        
        [loadedBasicInfoMap removeObjectForKey:[oldBasicInfo.objectID.URIRepresentation path]];
        
        //Add new item
        [self.table beginUpdates];
        [self updateBasicInfo:basicInfo fullyUpdated:YES];
        [basicInfoIDs replaceObjectAtIndex:indexPathOfEditBasicInfo.row withObject:basicInfo.objectID];
        [self.table reloadRowsAtIndexPaths:@[indexPathOfEditBasicInfo] withRowAnimation:UITableViewRowAnimationNone];
        [self.table endUpdates];
    }
    
    indexPathOfEditBasicInfo = nil;
    [self dismissViewControllerAnimated:YES completion:NULL];
}
//--------------------------------------------------------------
//  [END] EditBasicInfoViewControllerDelegate
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
        self.table.scrollEnabled = YES;
        
        _previewCellIndex = nil;
    };
    
    if(animate) {
        BasicInfoCell *cell = (BasicInfoCell *)[self.table cellForRowAtIndexPath:_previewCellIndex];
        if(cell.expiredCount > 0 || cell.nearExpiredCount > 0) {
            [cell showBadgeAnimatedWithDuration:0.2f afterDelay:0.25f];
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
//--------------------------------------------------------------
//  [END] Private Methods
//==============================================================

@end
