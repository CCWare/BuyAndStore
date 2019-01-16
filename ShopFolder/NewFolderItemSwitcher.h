//
//  NewFolderItemSwitcher.h
//  ShopFolder
//
//  Created by Michael on 2011/10/20.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "SegmentViewControllerSwitcher.h"
#import "EditFolderViewController.h"
#import "EditItemViewController.h"

@interface NewFolderItemSwitcher : SegmentViewControllerSwitcher <EditFolderViewControllerSaveStateChangeDelegate,
                                                                  EditItemViewControllerSaveStateChangeDelegate>
{
    UISegmentedControl *segControl;
    UIBarButtonItem *buttonSave;
    UIBarButtonItem *buttonCancel;
    
@private
    EditFolderViewController *_editFolderVC;
    EditItemViewController *_editItemVC;
    BOOL _canSaveFolder;
    BOOL _canSaveItem;
}

@property (nonatomic, strong) UISegmentedControl *segControl;
@property (nonatomic, strong) UIBarButtonItem *buttonSave;
@property (nonatomic, strong) UIBarButtonItem *buttonCancel;
@property (nonatomic, weak) id <EditFolderViewControllerDelegate> delegate;

- (id)initWithNavigationController:(UINavigationController *)navCtrl
                            folder:(DBFolder *)folder
                              item:(DBFolderItem *)item
                         basicInfo:(DBItemBasicInfo *)basicInfo;
- (id)initWithNavigationController:(UINavigationController *)navCtrl
                            folder:(DBFolder *)folder
                      shoppingItem:(DBShoppingItem *)shoppingItem;
@end
