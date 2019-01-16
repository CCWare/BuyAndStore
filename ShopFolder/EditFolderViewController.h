//
//  NewFolderViewController.h
//  ShopFolder
//
//  Created by Michael on 2011/09/17.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EditImageView.h"

#import "DBFolder.h"
#import "DBItemBasicInfo.h"

@protocol EditFolderViewControllerDelegate;
@protocol EditFolderViewControllerSaveStateChangeDelegate;

@interface EditFolderViewController : UIViewController <UITextFieldDelegate, UIAlertViewDelegate,
                                                        UITableViewDataSource, UITableViewDelegate,
                                                        UIImagePickerControllerDelegate, UINavigationControllerDelegate, 
                                                        UIActionSheetDelegate>
{
    //Save those because caller may commit changes when selecting location
    DBFolder *_tempFolder;
    NSManagedObjectID *_originFolderID;
    
    DBFolder *_folderData;
    BOOL rearCamEnabled;
@private
    UIView *respondViewAfterDismissAlert;
    BOOL skipChekingTextField;
    
    BOOL _createFolderOnly;
    BOOL _isNewFolder;
}

@property (nonatomic, strong) IBOutlet UITableView *table;
@property (nonatomic, strong) IBOutlet UITableViewCell *nameCell;
@property (nonatomic, strong) IBOutlet UIImageView *folderImageView;
@property (nonatomic, strong) EditImageView *editImageView;
@property (nonatomic, strong) IBOutlet UIView *editNameView;
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) IBOutlet UITableViewCell *lockCell;
@property (nonatomic, strong) IBOutlet UITextField *lockField;
@property (nonatomic, weak) id <EditFolderViewControllerDelegate> delegate;
@property (nonatomic, weak) id <EditFolderViewControllerSaveStateChangeDelegate> saveStatedelegate;
@property (nonatomic, assign) BOOL skipChekingTextField;

@property (nonatomic, strong) DBFolder *folderData;

- (id) initWithFolderData: (DBFolder *)folder;
- (id) initToCreateFolderOnly: (DBFolder *)folder;
- (IBAction)cancelEditing: (id)sender;
- (IBAction)doneEditing: (id)sender;

- (void)selectImage:(id)sender;
- (BOOL)saveFolderToDatabase;
- (void)dismissKeyboard;
@end

@protocol EditFolderViewControllerDelegate
- (void)cancelEditFolder:(id)sender;
- (void)finishEditFolder:(id)sender withFolderData:(DBFolder *)folderData;
@end

@protocol EditFolderViewControllerSaveStateChangeDelegate
- (void)canSaveFolder:(BOOL)canSave;    //For NewFolderItemSwitcher
@end