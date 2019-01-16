//
//  NewItemViewController.h
//  ShopFolder
//
//  Created by Michael on 2011/09/19.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DBFolderItem.h"
#import "DBFolder.h"
#import "PickDateViewController.h"
#import "EnterPriceViewController.h"
#import "EditImageView.h"
#import "BarcodeScannerViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <CoreLocation/CLLocationManagerDelegate.h>
#import "FlexibleHeightTableViewCell.h"
#import "CustomEdgeTextView.h"
#import "PickLocationViewController.h"
#import "OutlineLabel.h"
#import "SetExpirePeriodViewController.h"

@protocol EditItemViewControllerDelegate;
@protocol EditItemViewControllerSaveStateChangeDelegate;

@interface EditItemViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate,
                                                      UIAlertViewDelegate, UIImagePickerControllerDelegate,
                                                      UINavigationControllerDelegate, UIActionSheetDelegate,
                                                      UITextViewDelegate,
                                                      PickDateViewControllerDelegate, EnterPriceViewControllerDelegate,
                                                      BarcodeScanDelegate, PickLocationViewControllerDelegate,
                                                      SetExpirePeriodViewControllerDelegate>
{
    BOOL _isNewItem;
    DBFolderItem *_initItem;
    DBFolder *_initFolder;
    DBItemBasicInfo *_initBasicInfo;
    DBFolderItem *_tempItem;
    DBItemBasicInfo *_tempBasicInfo;
    DBItemBasicInfo *_candidateBasicInfo;   //when barcode or name changes, do not change until pressing Save button
    BOOL showAllOption;
    
    UIBarButtonItem *editButton;
    UIBarButtonItem *doneButton;
#pragma mark Item Cells
    //Image, name and barcode cell

    //Count cell
    NSNumberFormatter *integerFormatter;

    CustomEdgeTextView *noteView;
    
    UITableView *editNameTable;
    UIFont *editFieldFont;
    CGFloat fEditCellHeight;
    
    BOOL rearCamEnabled;
    
    BOOL isExpiredBeforeEditing;
    BOOL isNearExpiredBeforeEditing;

    NSIndexPath *selectedIndex;
    BOOL isEditing;
    CGFloat offsetBeforeEditing;
    
    UIControl *_imagePreviewView;
    UIImageView *_previewImageView;
    UITapGestureRecognizer *_imageTapGR;
    
    UIView *_imageLabelBackgroundView;
    UILabel *_imageLabel;
    OutlineLabel *_tapToDismissLabel;
    
    DBLocation *_pickedLocation;
    
    DBNotifyDate *_expireDate;
    NSMutableArray *_nearExpiredDays; //array of NSNumber
    
    NSArray *_changeLogs;   //Array of ChangeLog
    BOOL _canEditBasicInfo;
}

@property (nonatomic, assign) BOOL canEditBasicInfo;

@property (nonatomic, strong) IBOutlet UITableView *table;

@property (nonatomic, strong) UITableViewCell *nameCell;
@property (nonatomic, strong) EditImageView *editImageView;
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UITextField *barcodeField;

@property (nonatomic, strong) IBOutlet UITableViewCell *countCell;
@property (nonatomic, strong) IBOutlet UIView *countEditView;
@property (nonatomic, strong) IBOutlet UITextField *countField;
@property (nonatomic, strong) IBOutlet UIStepper *countStepper;
@property (nonatomic, strong) UITableViewCell *priceCell;
@property (nonatomic, strong) UITableViewCell *createDateCell;
@property (nonatomic, strong) UITableViewCell *expiryDateCell;
@property (nonatomic, strong) UITableViewCell *alertDaysCell;
@property (nonatomic, strong) UITableViewCell *locationCell;
@property (nonatomic, strong) UITableViewCell *noteCell;
@property (nonatomic, weak) id <EditItemViewControllerDelegate> delegate;
@property (nonatomic, weak) id <EditItemViewControllerSaveStateChangeDelegate> saveStateDelegate;

- (id)initWithFolderItem:(DBFolderItem *)item basicInfo:(DBItemBasicInfo *)basicInfo folder:(DBFolder *)folder;
- (id)initWithShoppingItem:(DBShoppingItem *)shoppingItem folder:(DBFolder *)folder;

- (IBAction)stepCount:(UIStepper *)sender;
- (void)doneEditing: (id)sender;
- (void)cancelEditing: (id)sender;
- (void)saveItem: (id)sender;
- (void)selectImage:(id)sender;

- (BOOL)saveItemToDatabase;
- (void)dismissKeyboard;

@end

@protocol EditItemViewControllerDelegate
- (void)cancelEditItem:(id)sender;
- (void)finishEditItem:(id)sender;
@end

@protocol EditItemViewControllerSaveStateChangeDelegate
- (void)canSaveItem:(BOOL)canSave;
@end