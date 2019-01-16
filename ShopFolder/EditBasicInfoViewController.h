//
//  EditBasicInfoViewController.h
//  ShopFolder
//
//  Created by Michael on 2012/12/03.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DBItemBasicInfo.h"
#import "BarcodeScannerViewController.h"
#import "EditImageView.h"

@protocol EditBasicInfoViewControllerDelegate;

@interface EditBasicInfoViewController : UIViewController <UITableViewDataSource, UITableViewDelegate,
                                                           UITextFieldDelegate, UIActionSheetDelegate,
                                                           UIImagePickerControllerDelegate, UINavigationControllerDelegate,
                                                           BarcodeScanDelegate>
{
    DBItemBasicInfo *_basicInfo;
    DBItemBasicInfo *_tempBasicInfo;
    DBItemBasicInfo *_candidateBasicInfo;   //when barcode or name changes, do not change until pressing Save button
    
    BOOL _rearCamEnabled;
    NSNumberFormatter *_integerFormatter;
    
    UITableViewCell *_nameCell;
    UITableView *_editNameTable;
    UITextField *_nameField;
    UITextField *_barcodeField;
    UIFont *editFieldFont;
    CGFloat fEditCellHeight;
    
    EditImageView *_editImageView;
}

@property (strong, nonatomic) IBOutlet UITableView *table;
@property (nonatomic, weak) id<EditBasicInfoViewControllerDelegate> delegate;

- (id)initWithItemBasicInfo:(DBItemBasicInfo *)basicInfo;
@end

@protocol EditBasicInfoViewControllerDelegate
- (void)cancelEditBasicInfo:(id)sender;
- (void)finishEditBasicInfo:(id)sender changedBasicIndo:(DBItemBasicInfo *)basicInfo;
@end
