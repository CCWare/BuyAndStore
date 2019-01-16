//
//  EditBasicInfoViewController.m
//  ShopFolder
//
//  Created by Michael on 2012/12/03.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "EditBasicInfoViewController.h"
#import "ImageParameters.h"
#import <QuartzCore/QuartzCore.h>
#import "CoreDataDatabase.h"
#import "EditImageView.h"
#import "NSManagedObject+DeepCopy.h"
#import "HardwareUtil.h"
#import "StringUtil.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "UIImage+Resize.h"
#import "UIImage+RoundedCorner.h"
#import "ListItemCell.h"
#import "ColorConstant.h"

#import "DBItemBasicInfo+SetAdnGet.h"
#import "DBItemBasicInfo+Validate.h"

#import "FlurryAnalytics.h"
#import "PreferenceConstant.h"

#define kImageTableSapce 8
#define kEditTableWidth (300-kImageWidth-kImageTableSapce)
#define kEditCellVerticalSpace      8
#define kEditCellHorizontalSpace    8
#define kTextViewVerticalSpace      8
#define kTextViewInset              5

#define kDetailViewX                 83
#define kDetailViewWidth            237 //310-kDetailViewX
#define kMaxTextViewHeightPortrait  184 //480 - 216(Keyboard) - 44(Nav Bar) - 20 (spaces) - 2*kTextViewVerticalSpace
#define kMaxTextViewHeightLandscape  90 //320 - 162(Keyboard) - 32(Nac Bar) - 20 (spaces) - 2*kTextViewVerticalSpace
#define kKeyboardHeightPortrait     216
#define kKeyboardHeightLandscape    162

#define kNameCellSection        0
#define kSafeStockSection       1

#define kEditNameRow            0
#define kEditBarcodeRow         1


@interface EditBasicInfoViewController ()
- (void)_cancelEditBasicInfo:(id)sender;
- (void)_finishEditBasicInfo:(id)sender;
- (void)_dismissKeyboard;
- (void)_autoFillBarcode:(Barcode *)barcode;
- (void)_updateBarcodeField;
- (void)_selectImage:(id)sender;
@end

@implementation EditBasicInfoViewController

- (id)initWithItemBasicInfo:(DBItemBasicInfo *)basicInfo
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _basicInfo = basicInfo;
        _tempBasicInfo = [CoreDataDatabase obtainTempItemBasicInfo];
        [_tempBasicInfo copyAttributesFrom:_basicInfo];
        
        _integerFormatter = [[NSNumberFormatter alloc] init];
        _integerFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        _integerFormatter.generatesDecimalNumbers = YES;
        _integerFormatter.maximumFractionDigits = 0;
        _integerFormatter.groupingSeparator = @",";
    }
    return self;
}

- (void)viewDidUnload {
    [self setTable:nil];
    _editNameTable = nil;
    _nameField = nil;
    _barcodeField = nil;
    _nameCell = nil;
    [super viewDidUnload];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.navigationController.navigationBar.tintColor = kColorNavigationBarTintColor;
    self.title = NSLocalizedString(@"Edit Information", nil);
    
    _rearCamEnabled = [HardwareUtil hasRearCam];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(_cancelEditBasicInfo:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                           target:self
                                                                                           action:@selector(_finishEditBasicInfo:)];

    editFieldFont = [UIFont systemFontOfSize:17];
    fEditCellHeight = editFieldFont.lineHeight + 2*kEditCellVerticalSpace;
    CGFloat tableHeight = fEditCellHeight*2;
    CGFloat tablePosY = 0;
    if(tableHeight < kImageHeight) {
        tablePosY = (kImageHeight - fEditCellHeight)/2;
    }
    _editNameTable = [[UITableView alloc] initWithFrame:CGRectMake(kImageWidth+kImageTableSapce, tablePosY,
                                                                           kEditTableWidth, tableHeight)];
    _editNameTable.delegate = self;
    _editNameTable.dataSource = self;
    
    _editNameTable.layer.cornerRadius = 10;
    _editNameTable.layer.borderWidth = 1;
    _editNameTable.layer.borderColor = [UIColor lightGrayColor].CGColor;
    
    //Init name field
    _nameField = [[UITextField alloc] initWithFrame:CGRectMake(kEditCellHorizontalSpace, kEditCellVerticalSpace,
                                                               kEditTableWidth-kEditCellHorizontalSpace, fEditCellHeight)];
    _nameField.font = editFieldFont;
    _nameField.placeholder = NSLocalizedString(@"Name", nil);
    _nameField.delegate = self;
    _nameField.returnKeyType = UIReturnKeyDone;
    _nameField.text = _tempBasicInfo.name;
    
    //Init Barcode field
    _barcodeField = [[UITextField alloc] initWithFrame:CGRectMake(kEditCellHorizontalSpace, 0, kEditTableWidth-kEditCellHorizontalSpace, fEditCellHeight)];
    _barcodeField.font = editFieldFont;
    _barcodeField.placeholder = NSLocalizedString(@"Barcode", nil);
    _barcodeField.keyboardType = UIKeyboardTypeNumberPad;
    _barcodeField.clearButtonMode = UITextFieldViewModeAlways;
    _barcodeField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    _barcodeField.delegate = self;
    [self _updateBarcodeField];
    
    _editImageView = [[EditImageView alloc] initWithFrame:CGRectMake(0, 0, kImageWidth, kImageHeight)];
    [_editImageView.editView addTarget:self action:@selector(_selectImage:) forControlEvents:UIControlEventTouchUpInside];
    _editImageView.image = [_tempBasicInfo getDisplayImage];
    _editImageView.editing = YES;
    
    _nameCell = [[ListItemCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                        reuseIdentifier:@"NameCell"];
    _nameCell.frame = CGRectMake(0, 0, _nameCell.frame.size.width, kImageHeight);
    _nameCell.imageView.userInteractionEnabled = YES;
    _nameCell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    _nameCell.imageView.contentStretch = CGRectMake(0, 0, 0, 0);  //Not to resize to content
    _nameCell.selectionStyle = UITableViewCellSelectionStyleNone;
    _nameCell.backgroundColor = [UIColor clearColor];    //Must set here, IB doesn't work for this
    _nameCell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];  //remove grouped style
    [_nameCell.contentView addSubview:_editNameTable];
    [_nameCell.contentView addSubview:_editImageView];
    
    [_nameField becomeFirstResponder];
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
    if(tableView == self.table) {
        if(indexPath.section == kNameCellSection) {
            //May be different if more than two cells in editTable
            if(_editNameTable.frame.size.height > kImageHeight) {
                return _editNameTable.frame.size.height;
            } else {
                return kImageHeight;
            }
        }
        
        return tableView.rowHeight;
    } else if(tableView == _editNameTable) {
        return fEditCellHeight;
    }
    
    return 0;
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
    UITableViewCell *cell = nil;
    if(tableView == self.table) {
        if(indexPath.section == kNameCellSection) {
            return _nameCell;
        }
    } else if(tableView == _editNameTable) {
        static NSString *CellTableIdentitifier = @"EditNameTableCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
        if(cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellTableIdentitifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        
        UITextField *textField = nil;
        if(indexPath.row == 0) {
            _nameField.text = _tempBasicInfo.name;
            textField = _nameField;
        } else {
            [self _updateBarcodeField];
            textField = _barcodeField;
        }
        
        textField.borderStyle = UITextBorderStyleNone;
        [cell.contentView addSubview:textField];
        return cell;
    }
    
    static NSString *CellTableIdentitifier = @"CellIdentifier";
    cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
    if(cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellTableIdentitifier];
    }
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if(tableView == self.table) {
        return 1;
    } else if(tableView == _editNameTable) {
        return 2;
    }
    
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(tableView == self.table) {
        return 1;
    } else if(tableView == _editNameTable) {
        return 2;
    }
    
    return 0;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
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
//  [BEGIN] UITextFieldDelegate
#pragma mark -
#pragma mark UITextFieldDelegate Methods
//--------------------------------------------------------------
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if(textField == _barcodeField) {
        if(_rearCamEnabled) {
            [self _dismissKeyboard];
            BarcodeScannerViewController *barcodeScanVC = [BarcodeScannerViewController new];
            barcodeScanVC.barcodeScanDelegate = self;
            [self presentModalViewController:barcodeScanVC animated:YES];
            
            return NO;
        }
        
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
            [FlurryAnalytics logEvent:@"Manual enter barcode"];
        }
    }
    
    return YES;
}

- (BOOL) textFieldShouldEndEditing:(UITextField *)textField
{
    return YES;
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *candidateString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if(textField == _nameField) {
        if([candidateString length] == 0) {
            _tempBasicInfo.name = nil;
            if([_candidateBasicInfo.name length] > 0 &&         //Has _candidateBasicInfo which has name and no barcode
               [_candidateBasicInfo.barcodeData length] == 0)
            {
                _candidateBasicInfo = nil;  //Then, it's no longer a candidate
            }
        } else {
            _tempBasicInfo.name = candidateString;
            
            if([_candidateBasicInfo.barcodeData length] == 0) {     //No existed barcode scanned
                //Try to get existed basicInfo
                _candidateBasicInfo = [CoreDataDatabase getItemBasicInfoByName:candidateString shouldExcludeBarcode:YES];
                if(_candidateBasicInfo) {
                    if(_tempBasicInfo.imageRawData == nil) {
                        //If we have not took an image, try to use image of _candidateBasicInfo
                        if(_candidateBasicInfo.imageRawData != nil) {
                            [_tempBasicInfo setUIImage:[_candidateBasicInfo getDisplayImage]];
                            _editImageView.image = _tempBasicInfo.displayImage;
                        }
                    } else {
                        //If we have take an image and candidate has no image, try to assign image to candidate
                        if(_candidateBasicInfo.imageRawData == nil) {
                            [_candidateBasicInfo setUIImage:[_tempBasicInfo getDisplayImage]];
                            _editImageView.image = _tempBasicInfo.displayImage;
                        }
                    }
                }
            } else {
                _candidateBasicInfo.name = candidateString;
            }
        }
        
        self.navigationItem.rightBarButtonItem.enabled = ((_candidateBasicInfo != nil) || [_tempBasicInfo canSave]);
        return YES;
    } else {
        if(textField == _barcodeField &&
           !_rearCamEnabled) //User typed barcode, otherwise handle in barcodeScanned:
        {
            //No digit
            if([candidateString length] == 0) {
                [_tempBasicInfo setBarcode:nil];
                _candidateBasicInfo = nil;
                self.navigationItem.rightBarButtonItem.enabled = [_tempBasicInfo canSave];
                return YES;
            }
            
            //Not pure digit string
            if(![_integerFormatter numberFromString:candidateString]) {
                return NO;
            }
            
            //Not integer
            range = [candidateString rangeOfString:@"."];
            if(range.length > 0) {
                return NO;
            }
            
            //Only no camera devices (e.g. iPad 1) will come here
            if([candidateString length] == 0) {
                [_tempBasicInfo setBarcode:nil];
                _candidateBasicInfo = nil;
            } else {
                Barcode *barcode = [[Barcode alloc] initWithType:nil andData:candidateString];
                [self _autoFillBarcode:barcode];
            }
            
            self.navigationItem.rightBarButtonItem.enabled = ((_candidateBasicInfo != nil) || [_tempBasicInfo canSave]);
        }
    }
    
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    if(textField == _barcodeField) {
        textField.text = nil;
        
        [_tempBasicInfo setBarcode:nil];
        _candidateBasicInfo = [CoreDataDatabase getItemBasicInfoByName:_tempBasicInfo.name shouldExcludeBarcode:YES];
        if(_candidateBasicInfo) {   //If there is another basicInfo has the same name with no barcode
            
            //Use candidate's image if it has one
            if(_candidateBasicInfo.imageRawData != nil) {
                [_tempBasicInfo setUIImage:[_candidateBasicInfo getDisplayImage]];
                _editImageView.image = _tempBasicInfo.displayImage;
            }
        }
        
        self.navigationItem.rightBarButtonItem.enabled = [_tempBasicInfo canSave];
        return NO;  //YES will make text field become first responder
    }
    
    return YES;
}
//--------------------------------------------------------------
//  [END] UITextFieldDelegate
//==============================================================

//==============================================================
//  [BEGIN] BarcodeScanDelegate Methods
#pragma mark -
#pragma mark BarcodeScanDelegate Methods
//--------------------------------------------------------------
- (void)barcodeScanCancelled
{
    [self dismissModalViewControllerAnimated:YES];
}

- (void)barcodeScanned:(Barcode *)barcode
{
    self.navigationItem.rightBarButtonItem.enabled = YES;
    [self _autoFillBarcode:barcode];
    [self _updateBarcodeField];
    
    [self dismissModalViewControllerAnimated:YES];
}
//--------------------------------------------------------------
//  [END] BarcodeScanDelegate
//==============================================================

//==============================================================
//  [BEGIN] UIImagePickerControllerDelegate
#pragma mark -
#pragma mark UIImagePickerControllerDelegate Methods
//--------------------------------------------------------------
- (void) imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissModalViewControllerAnimated:YES];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissModalViewControllerAnimated:YES];
    
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    if(CFStringCompare((__bridge CFStringRef)mediaType, kUTTypeImage, 0) == kCFCompareEqualTo) {
        UIImage *editImage = [info objectForKey:UIImagePickerControllerEditedImage];
        [_tempBasicInfo setUIImage:[editImage thumbnailImage:kImageSaveSize
                                           transparentBorder:0
                                                cornerRadius:0
                                        interpolationQuality:kCGInterpolationHigh]];
        _candidateBasicInfo.imageRawData = _tempBasicInfo.imageRawData;
        _candidateBasicInfo.displayImage = _tempBasicInfo.displayImage;
        _editImageView.image = _tempBasicInfo.displayImage;
        
        self.navigationItem.rightBarButtonItem.enabled = YES;
    } else {
        [FlurryAnalytics logEvent:@"Fail to take image for item"
                   withParameters:[NSDictionary dictionaryWithObject:mediaType forKey:@"MediaType"]];
        
        UIAlertView *alertImageFail = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot Take Image", nil)
                                                                 message:NSLocalizedString(@"Please try again. If the problem remains, please turn off the app and run again.", nil)
                                                                delegate:nil
                                                       cancelButtonTitle:NSLocalizedString(@"Dismiss", nil)
                                                       otherButtonTitles:nil];
        [alertImageFail show];
    }
}
//--------------------------------------------------------------
//  [END] UIImagePickerControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] UIActionSheetDelegate
#pragma mark -
#pragma mark UIActionSheetDelegate Methods
//--------------------------------------------------------------
- (void)_takePhotoFromCamera
{
    if(!_rearCamEnabled) {
        return;
    }
    
    UIImagePickerController *pickImageVC = [[UIImagePickerController alloc] init];
    //Don't do this, otherwise you cannot dismiss the view controller
    //[[[UIApplication sharedApplication] keyWindow] setRootViewController:pickImageVC];
    pickImageVC.delegate = self;
    pickImageVC.allowsEditing = YES;
    
    pickImageVC.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    [self presentModalViewController:pickImageVC animated:YES];
}

- (void)_takePhotoFromAlbum
{
    UIImagePickerController *pickImageVC = [[UIImagePickerController alloc] init];
    //Don't do this, otherwise you cannot dismiss the view controller
    //[[[UIApplication sharedApplication] keyWindow] setRootViewController:pickImageVC];
    pickImageVC.delegate = self;
    pickImageVC.allowsEditing = YES;
    
    pickImageVC.mediaTypes = [NSArray arrayWithObject:(NSString *)kUTTypeImage];
    
    [self presentModalViewController:pickImageVC animated:YES];
}

- (void)_removeImage
{
    //Delete image
    [_tempBasicInfo setUIImage:nil];
    [_candidateBasicInfo setUIImage:nil];
    _editImageView.image = nil;
    
    if(_candidateBasicInfo != nil ||
       [_tempBasicInfo canSave])
    {
        self.navigationItem.rightBarButtonItem.enabled = YES;
    } else {
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
}

- (void) actionSheetCancel:(UIActionSheet *)actionSheet
{
}

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
    
    if(buttonIndex == 0) {
        if(_rearCamEnabled) {
            [self _takePhotoFromCamera];
        } else {
            [self _takePhotoFromAlbum];
        }
    } else if(buttonIndex == 1) {
        if(_rearCamEnabled) {
            [self _takePhotoFromAlbum];
        } else {
            [self _removeImage];
        }
    } else if(buttonIndex == 2) {
        [self _removeImage];
    }
}
//--------------------------------------------------------------
//  [END] UIActionSheetDelegate
//==============================================================

//==============================================================
//  [BEGIN] Private Methods
#pragma mark - Private Methods
//--------------------------------------------------------------
- (void)_cancelEditBasicInfo:(id)sender
{
    [CoreDataDatabase cancelUnsavedChanges];
    [self.delegate cancelEditBasicInfo:self];
}

- (void)_finishEditBasicInfo:(id)sender
{
    if(_candidateBasicInfo) {
        _candidateBasicInfo.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
        [CoreDataDatabase commitChanges:nil];
        [self.delegate finishEditBasicInfo:self changedBasicIndo:_candidateBasicInfo];
    } else {
        [_basicInfo copyAttributesFrom:_tempBasicInfo];
        _basicInfo.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
        [CoreDataDatabase commitChanges:nil];
        [self.delegate finishEditBasicInfo:self changedBasicIndo:_basicInfo];
    }
}

- (void)_dismissKeyboard
{
    [_nameField resignFirstResponder];
    [_barcodeField resignFirstResponder];
}

- (void)_autoFillBarcode:(Barcode *)barcode
{
    if([barcode.barcodeData length] == 0) {
        return;
    }
    
    _candidateBasicInfo = [CoreDataDatabase getItemBasicInfoByBarcode:barcode];
    if(_candidateBasicInfo == nil) {
        //Scanned a new barcode
        [_tempBasicInfo setBarcode:barcode];
    } else {
        [_tempBasicInfo setBarcode:nil];
        
        _nameField.text = _candidateBasicInfo.name;
        _tempBasicInfo.name = _candidateBasicInfo.name;
        
        _editImageView.image = [_candidateBasicInfo getDisplayImage];
        [_tempBasicInfo setUIImage:_editImageView.image];
    }
}

- (void)_updateBarcodeField
{
    if(_candidateBasicInfo) {
        _barcodeField.text = [StringUtil formatBarcode:_candidateBasicInfo.barcode];
    } else {
        _barcodeField.text = [StringUtil formatBarcode:_tempBasicInfo.barcode];
    }
}

- (void)_selectImage:(id)sender
{
    [self _dismissKeyboard];
    
    if(!_rearCamEnabled && ![_editImageView hasImage]) {
        [self _takePhotoFromAlbum];
    } else {
        UIActionSheet *pickImageSheet = [[UIActionSheet alloc] init];
        
        pickImageSheet.title = NSLocalizedString(@"Pick Image From:", nil);
        pickImageSheet.cancelButtonIndex = 1;
        
        if(_rearCamEnabled) {
            [pickImageSheet addButtonWithTitle:NSLocalizedString(@"Camera", nil)];          // 0
            pickImageSheet.cancelButtonIndex++;
        }
        
        [pickImageSheet addButtonWithTitle:NSLocalizedString(@"Photo Albums", nil)];        // 0 or 1
        
        if([_editImageView hasImage]) {
            [pickImageSheet addButtonWithTitle:NSLocalizedString(@"Remove Image", nil)];    // 1 or 2
            pickImageSheet.destructiveButtonIndex = pickImageSheet.cancelButtonIndex;
            pickImageSheet.cancelButtonIndex++;
        }
        
        [pickImageSheet addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];              // 1 or 2 or 3
        
        pickImageSheet.delegate = self;
        
        [pickImageSheet showInView:self.navigationController.view];
    }
}
//--------------------------------------------------------------
//  [END] Private Methods
//==============================================================
@end
