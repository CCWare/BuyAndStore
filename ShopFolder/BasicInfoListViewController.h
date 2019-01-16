//
//  BasicInfoListViewController.h
//  ShopFolder
//
//  Created by Michael on 2012/11/14.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BasicInfoCell.h"
#import "OutlineLabel.h"
#import "FolderItemListViewController.h"
#import "EditBasicInfoViewController.h"

#ifdef _LITE_
#import "InAppPurchaseViewController.h"
#endif

@interface BasicInfoListViewController : UIViewController <BasicInfoCellDelegate, FolderItemListViewControllerDelegate,
                                                           EditBasicInfoViewControllerDelegate, UIAlertViewDelegate
#ifdef _LITE_
                                                           ,InAppPurchaseViewControllerDelegate
#endif
>
{
    NSMutableArray *basicInfoIDs;        //Array of objectID of DBItemBasicInfo
    
    dispatch_queue_t loadBasicInfoQueue;
    
    NSMutableDictionary *loadedBasicInfoMap;        //basicInfo -> LoadedBasicInfoData
    
    UIImage *tableImage;
    NSIndexPath *indexPathOfEditBasicInfo;
@private
    int _nSelectedIndex;
    
    //For large image preview
    UIImageView *_largeImageView;
    UIControl *_largeImageBackgroundView;
    UIView *_imageLabelBackgroundView;
    UILabel *_imageLabel;
    OutlineLabel *_tapToDismissLabel;
    CGRect _imageAnimateFromFrame;
    NSIndexPath *_previewCellIndex;
    
#ifdef _LITE_
    UIAlertView *_liteLimitAlert;
#endif
}

@property (strong, nonatomic) IBOutlet UITableView *table;

- (void)setCell:(BasicInfoCell *)cell withIndexPath:(NSIndexPath *)indexPath;
- (LoadedBasicInfoData *)updateBasicInfo:(DBItemBasicInfo *)basicInfo fullyUpdated:(BOOL)isFull;
- (BOOL)shouldHandleFolderItem:(DBFolderItem *)folderItem;
@end
