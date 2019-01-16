//
//  NewFolderItemSwitcher.m
//  ShopFolder
//
//  Created by Michael on 2011/10/20.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "NewFolderItemSwitcher.h"
#import "DBFolder+Validate.h"
#import "DBFolderItem+Validate.h"
#import "DBItemBasicInfo+Validate.h"
#import "DBShoppingItem.h"

@interface NewFolderItemSwitcher ()
- (void) _cancelEditing: (id)sender;
- (void) _saveEditing: (id)sender;
@end

@implementation NewFolderItemSwitcher
@synthesize segControl;
@synthesize buttonSave;
@synthesize buttonCancel;
@synthesize delegate;

- (void)_commonInitWithFolderVC:(EditFolderViewController *)editFolderVC itemVC:(EditItemViewController *)editItemVC
{
    _editFolderVC = editFolderVC;
    _editItemVC = editItemVC;
    
    self.segControl = [[UISegmentedControl alloc]
                       initWithItems:[NSArray arrayWithObjects:
                                      NSLocalizedString(@" Folder ", @"For showing in seg ctrl"),
                                      NSLocalizedString(@"  Item  ", @"For showing in seg ctrl"), nil]];
    self.segControl.segmentedControlStyle = UISegmentedControlStyleBar;
    self.segControl.selectedSegmentIndex = 0;
    self.segControl.tintColor = [UIColor colorWithWhite:0.3f alpha:1.0f];
    [self.segControl addTarget:self
                        action:@selector(indexChangedInSegmentedControl:)
              forControlEvents:UIControlEventValueChanged];
    
    self.buttonSave = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                    target:self
                                                                    action:@selector(_saveEditing:)];
    
    self.buttonCancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                      target:self
                                                                      action:@selector(_cancelEditing:)];
    
    //Just select, not to check values
    [super indexChangedInSegmentedControl:self.segControl];
    _editFolderVC.navigationItem.leftBarButtonItem = self.buttonCancel;
    _editFolderVC.navigationItem.rightBarButtonItem = self.buttonSave;
}

- (id)initWithNavigationController:(UINavigationController *)navCtrl
                            folder:(DBFolder *)folder
                              item:(DBFolderItem *)item
                         basicInfo:(DBItemBasicInfo *)basicInfo
{
    EditFolderViewController *editFolderVC = [[EditFolderViewController alloc] initWithFolderData:folder];
    editFolderVC.saveStatedelegate = self;
    EditItemViewController *editItemVC = [[EditItemViewController alloc] initWithFolderItem:item
                                                                                  basicInfo:basicInfo
                                                                                     folder:editFolderVC.folderData];
    editItemVC.saveStateDelegate = self;

    NSArray *vcs = [NSArray arrayWithObjects:editFolderVC, editItemVC, nil];
    if((self = [super initWithNavigationController:navCtrl viewControllers:vcs])) {
        [self _commonInitWithFolderVC:editFolderVC itemVC:editItemVC];
        
        _canSaveFolder = [folder canSave];
        _canSaveItem = [item canSave] || [basicInfo canSave];
        self.buttonSave.enabled = (_canSaveFolder && _canSaveItem);
    }
    
    return self;
}

- (id)initWithNavigationController:(UINavigationController *)navCtrl folder:(DBFolder *)folder shoppingItem:(DBShoppingItem *)shoppingItem
{
    EditFolderViewController *editFolderVC = [[EditFolderViewController alloc] initWithFolderData:folder];
    EditItemViewController *editItemVC = [[EditItemViewController alloc] initWithShoppingItem:shoppingItem folder:folder];
    
    NSArray *vcs = [NSArray arrayWithObjects:editFolderVC, editItemVC, nil];
    if((self = [super initWithNavigationController:navCtrl viewControllers:vcs])) {
        [self _commonInitWithFolderVC:editFolderVC itemVC:editItemVC];
        
        _canSaveFolder = [folder canSave];
        _canSaveItem = [shoppingItem.basicInfo canSave];
        self.buttonSave.enabled = (_canSaveFolder && _canSaveItem);
    }
    
    return self;
}

- (void) indexChangedInSegmentedControl:(UISegmentedControl *)segCtrl
{
    //Prevent to select segment during value checking
    //Known issue: the segmented control may flash
    [self.segControl removeTarget:self
                           action:@selector(indexChangedInSegmentedControl:)
                 forControlEvents:UIControlEventValueChanged];

    if(self.segControl.selectedSegmentIndex == 1) { // folder -> item
        [_editFolderVC dismissKeyboard];
        
        _editItemVC.navigationItem.titleView = self.segControl;
        _editItemVC.navigationItem.leftBarButtonItem = self.buttonCancel;
        _editItemVC.navigationItem.rightBarButtonItem = self.buttonSave;
        
        NSArray *displayViewControllers = [NSArray arrayWithObject:_editItemVC];
        [self.navigationController setViewControllers:displayViewControllers animated:NO];
    } else {                                        // folder <- item
        [_editItemVC dismissKeyboard];
        
        _editFolderVC.navigationItem.titleView = self.segControl;
        _editFolderVC.navigationItem.leftBarButtonItem = self.buttonCancel;
        _editFolderVC.navigationItem.rightBarButtonItem = self.buttonSave;
        
        NSArray *displayViewControllers = [NSArray arrayWithObject:_editFolderVC];
        [self.navigationController setViewControllers:displayViewControllers animated:NO];
    }

    [self.segControl addTarget:self
                        action:@selector(indexChangedInSegmentedControl:)
              forControlEvents:UIControlEventValueChanged];
}

//==============================================================
//  [BEGIN] EditFolderViewControllerDelegate
#pragma mark - EditFolderViewControllerDelegate
//--------------------------------------------------------------
- (void)canSaveFolder:(BOOL)canSave
{
    _canSaveFolder = canSave;
    buttonSave.enabled = (_canSaveFolder && _canSaveItem);
}
//--------------------------------------------------------------
//  [END] EditFolderViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] EditItemViewControllerDelegate
#pragma mark - EditItemViewControllerDelegate
//--------------------------------------------------------------
- (void)canSaveItem:(BOOL)canSave
{
    _canSaveItem = canSave;
    buttonSave.enabled = (_canSaveFolder && _canSaveItem);
}
//--------------------------------------------------------------
//  [END] EditItemViewControllerDelegate
//==============================================================

- (void) _cancelEditing: (id)sender
{
    _editFolderVC.skipChekingTextField = YES;   //don't let alertView come out
    [self.delegate cancelEditFolder:self];
}

- (void)_saveEditing: (id)sender
{
    [_editFolderVC saveFolderToDatabase];
    [_editItemVC saveItemToDatabase];
    [self.delegate finishEditFolder:self withFolderData:_editFolderVC.folderData];
}

@end
