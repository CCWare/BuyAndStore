//
//  ListItemInFolderViewController.m
//  ShopFolder
//
//  Created by Michael on 2012/11/19.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "ListItemInFolderViewController.h"
#import "CoreDataDatabase.h"
#import "PreferenceConstant.h"
#import "DBItemBasicInfo+SetAdnGet.h"

@interface ListItemInFolderViewController ()
- (void)_addItemButtonPressed:(id)sender;
@end

@implementation ListItemInFolderViewController

- (id)initWithBasicInfo:(DBItemBasicInfo *)basicInfo
                 folder:(DBFolder *)folder
            preloadData:(LoadedBasicInfoData *)preloadData
{
    if((self = [super initWithBasicInfo:basicInfo preloadData:preloadData])) {
        _folder = folder;
        [self refreshItemList];
    }
    
    return self;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                               target:self
                                                                               action:@selector(_addItemButtonPressed:)];
    self.navigationItem.rightBarButtonItem = addButton;
    _originRightBarButton = self.navigationItem.rightBarButtonItem;
    
    [self doSortAndLoadTable];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refreshItemList
{
    _folderItemSet = [NSMutableSet setWithArray:[CoreDataDatabase getFolderItemsWithBasicInfo:_basicInfo inFolder:_folder]];
}

- (void)_addItemButtonPressed:(id)sender
{
    _isCreatingNewItem = YES;
    EditItemViewController *editItemVC = [[EditItemViewController alloc] initWithFolderItem:nil
                                                                                  basicInfo:_basicInfo
                                                                                     folder:_folder];
    editItemVC.delegate = self;
    editItemVC.canEditBasicInfo = NO;
    UINavigationController *navcon = [[UINavigationController alloc] initWithRootViewController:editItemVC];
    [self.navigationController presentViewController:navcon animated:YES completion:nil];
}

- (void)updateBasicInfoStatistics
{
    [super updateBasicInfoStatistics];
    
    _basicInfoData.stock = [CoreDataDatabase stockOfBasicInfo:_basicInfo inFolder:_folder];
    _basicInfoData.expiredCount = [CoreDataDatabase totalExpiredItemsOfBasicInfo:_basicInfo inFolder:_folder];
    _basicInfoData.nearExpiredCount = [CoreDataDatabase totalNearExpiredOfBasicInfo:_basicInfo inFolder:_folder];
}

- (BOOL)shouldHandleChangesForFolderItem:(DBFolderItem *)item
{
    if([item.basicInfo.objectID.URIRepresentation isEqual:_basicInfo.objectID.URIRepresentation] &&
       [_folder.objectID.URIRepresentation isEqual:item.folder.objectID.URIRepresentation])
    {
        return YES;
    }
    
    return NO;
}

//==============================================================
//  [BEGIN] EditItemViewControllerDelegate
#pragma mark - EditItemViewControllerDelegate
//--------------------------------------------------------------
- (void)cancelEditItem:(id)sender
{
    _isCreatingNewItem = NO;
    [super cancelEditItem:sender];
}

- (void)finishEditItem:(id)sender
{
    if(_isCreatingNewItem) {
        _isCreatingNewItem = NO;
        [self refreshItemList];
    }
    
    [super finishEditItem:sender];
}
//--------------------------------------------------------------
//  [END] EditItemViewControllerDelegate
//==============================================================

@end
