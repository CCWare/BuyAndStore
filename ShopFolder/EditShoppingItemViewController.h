//
//  EditShoppingItemViewController.h
//  ShopFolder
//
//  Created by Chung-Chih Tsai on 2012/05/16.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DBShoppingItem.h"
#import "EditImageView.h"
#import "EditShoppingItemViewController.h"
#import "EditItemViewController.h"
#import "OutlineLabel.h"
#import "EnterPriceViewController.h"

#ifdef _LITE_
#import "InAppPurchaseViewController.h"
#endif

@protocol EditShoppingItemViewControllerDelegate;

@interface EditShoppingItemViewController : UIViewController <UITableViewDelegate, UITableViewDataSource,
                                                              UITextFieldDelegate, UIActionSheetDelegate,
                                                              UIAlertViewDelegate, UIImagePickerControllerDelegate,
#ifdef _LITE_
                                                              InAppPurchaseViewControllerDelegate,
#endif
                                                              UINavigationControllerDelegate, EditItemViewControllerDelegate,
                                                              EnterPriceViewControllerDelegate>
{
    BOOL _isNewShoppingItem;
    DBShoppingItem *_initShoppingItem;
    DBItemBasicInfo *_initBasicInfo;
    
    DBShoppingItem *_autoFillShoppingItem;
    DBItemBasicInfo *_autoFillBasicInfo;
    
    DBShoppingItem *_tempShoppingItem;
    DBItemBasicInfo *_tempBasicInfo;
    UIImage *_userTakenImage;
    
    UIBarButtonItem *_editButton;
    UIBarButtonItem *_cancelButton;
    UIBarButtonItem *_saveButton;
    
    //Image, name and barcode cell
    UITableViewCell *_nameCell;
    EditImageView *_editImageView;
    UITextField *_nameField;
    
    //Count cell
    UITableViewCell *_countCell;
    UIStepper *_countStepper;
    
    //Price cell
    UITableViewCell *_priceCell;
    
    BOOL _hasRearCam;
    
    NSMutableArray *_candidateFolders;
    
    UIActionSheet *_organizeSheet;
    UIActionSheet *_deleteSheet;
#ifdef _LITE_
    UIAlertView *_alertLiteLimitation;
#endif
    
    BOOL _isEditing;
    UIControl *_imagePreviewView;
    UIImageView *_previewImageView;
    UITapGestureRecognizer *_imageTapGR;
    
    UIView *_imageLabelBackgroundView;
    UILabel *_imageLabel;
    OutlineLabel *_tapToDismissLabel;
    
    NSNumberFormatter *_currencyFormatter;
}

@property (nonatomic, strong) IBOutlet UITableView *table;
@property (nonatomic, weak) id<EditShoppingItemViewControllerDelegate> delegate;

@property (nonatomic, strong) IBOutlet UIToolbar *toolbar;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *organizeButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *boughtStatusText;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *deleteButton;

- (id)initForEditingShoppingItem:(DBShoppingItem *)item;

- (IBAction)organizeButtonPressed:(id)sender;
- (IBAction)deleteButtonPressed:(id)sender;
- (IBAction)changeBoughtStatus:(id)sender;
@end

@protocol EditShoppingItemViewControllerDelegate
- (void)cancelEditingShoppingItem;
- (void)finishEditingShoppingItem:(DBShoppingItem *)shoppingItem;
- (void)shoppingItemWillBeginToMove:(DBShoppingItem *)shoppingItem;
@end