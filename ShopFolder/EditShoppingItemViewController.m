//
//  EditShoppingItemViewController.m
//  ShopFolder
//
//  Created by Chung-Chih Tsai on 2012/05/16.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "EditShoppingItemViewController.h"
#import "CoreDataDatabase.h"
#import "HardwareUtil.h"
#import "ListItemCell.h"
#import "StringUtil.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "UIImage+Resize.h"
#import "FlurryAnalytics.h"
#import "UIImage+SaveToDisk.h"
#import "PreferenceConstant.h"
#import "CoreDataDatabase.h"
#import "DBItemBasicInfo+SetAdnGet.h"
#import "DBItemBasicInfo+Validate.h"
#import "NSManagedObject+DeepCopy.h"
#ifdef _LITE_
#import "LiteLimitations.h"
#endif

#define kItemNameLabelHeight    60.0f

#define kAnimationDuration  0.3f
#define kNameFieldWidth     220.f
#define kNameFieldHeight    31.0f

#define kImageAndNameSection    0
#define kCountSection           1
#define kPriceSection           2

@interface EditShoppingItemViewController ()
- (void)_toggleEditMode:(BOOL)isEditing animated:(BOOL)animate;

- (void)_editButtonPressed:(id)sender;
- (void)_saveItem:(id)sender;
- (void)_cancelEditing:(id)sender;

- (void)_countChanged:(UIStepper *)sender;
- (void)_selectImage:(id)sender;

- (void)_tapOnImageView:(UITapGestureRecognizer *)sender;
- (void)_updateUIFromBoughtStatus:(BOOL)hasBought;

- (void)_willShowKeyboard:(NSNotification *)notification;
- (void)_willHideKeyboard:(NSNotification *)notification;

- (void)_updatePriceLabelWithPrice:(float)price;
@end

@implementation EditShoppingItemViewController
@synthesize table;
@synthesize delegate;

@synthesize toolbar;
@synthesize organizeButton;
@synthesize boughtStatusText;
@synthesize deleteButton;

- (void)_init
{
    _imageTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tapOnImageView:)];
    
    _currencyFormatter = [[NSNumberFormatter alloc] init];
    _currencyFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
    _currencyFormatter.minimumFractionDigits = 0;
    [_currencyFormatter setLenient:YES];
}

- (id)initForEditingShoppingItem:(DBShoppingItem *)item
{
    if((self = [super initWithNibName:nil bundle:nil])) {
        _isNewShoppingItem = NO;
        _initShoppingItem = item;
        _initBasicInfo = item.basicInfo;
        _userTakenImage = [_initBasicInfo getDisplayImage];
        [self _init];
    }
    
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
        _isNewShoppingItem = YES;
        [self _init];
    }
    return self;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.table = nil;
    self.toolbar = nil;
    self.organizeButton = nil;
    self.boughtStatusText = nil;
    self.deleteButton = nil;
    
    _editButton = nil;
    _saveButton = nil;
    _cancelButton = nil;
    _nameCell = nil;
    _editImageView = nil;
    _countCell = nil;
    _countStepper = nil;
    _priceCell = nil;
    
    _previewImageView = nil;
    _imagePreviewView = nil;
    _imageLabelBackgroundView = nil;
    _imageLabel = nil;
    _tapToDismissLabel = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    //Regiester notifications for keyboard show/hide (iOS 5 suooprts "change")
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_willShowKeyboard:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_willHideKeyboard:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    self.toolbar.tintColor = self.navigationController.navigationBar.tintColor;
    // Do any additional setup after loading the view from its nib.
    _editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                target:self
                                                                action:@selector(_editButtonPressed:)];
    _saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                target:self
                                                                action:@selector(_saveItem:)];
    _cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                  target:self
                                                                action:@selector(_cancelEditing:)];
    
    _hasRearCam = [HardwareUtil hasRearCam];
    
    //Init key cell
    _nameCell = [[ListItemCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                        reuseIdentifier:@"EditShoppingItemTable_NameCell"];
    _nameCell.frame = CGRectMake(0, 0, _nameCell.frame.size.width, kImageHeight);
    
    //Init Image
    CGRect rect = CGRectMake(0, 0, kImageWidth, kImageHeight);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
    CGContextFillRect(context, rect);
    UIImage *backgroundImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    _nameCell.imageView.image = backgroundImage;
    
    _editImageView = [[EditImageView alloc] initWithFrame:CGRectMake(0, 0, kImageWidth, kImageHeight)];
    _nameCell.imageView.userInteractionEnabled = YES;
    _nameCell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    _nameCell.imageView.contentStretch = CGRectMake(0, 0, 0, 0);  //Not to resize to content
    [_nameCell.imageView addSubview:_editImageView];
    [_editImageView.editView addTarget:self action:@selector(_selectImage:) forControlEvents:UIControlEventTouchUpInside];

    _nameCell.selectionStyle = UITableViewCellSelectionStyleNone;
    _nameCell.backgroundColor = [UIColor clearColor];    //Must set here, IB doesn't work for this
    _nameCell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];  //remove grouped style
    
    _nameField = [[UITextField alloc] initWithFrame:CGRectMake(kImageWidth+20.0f, (kImageHeight-kNameFieldHeight)/2,
                                                               kNameFieldWidth, kNameFieldHeight)];
    _nameField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _nameField.delegate = self;
    _nameField.placeholder = NSLocalizedString(@"Name", nil);
    _nameField.returnKeyType = UIReturnKeyDone;
    _nameField.borderStyle = UITextBorderStyleRoundedRect;
    _nameField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    
    //Init Count cell
    _countCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2
                                            reuseIdentifier:@"EditShoppingItemTable_CountCell"];
    _countCell.selectionStyle = UITableViewCellSelectionStyleNone;
    _countCell.textLabel.text = NSLocalizedString(@"Count", nil);
    [_countCell layoutSubviews];
    _countStepper = [[UIStepper alloc] init];
    _countStepper.minimumValue = 1.0f;
    _countStepper.stepValue = 1.0f;
    [_countStepper addTarget:self action:@selector(_countChanged:) forControlEvents:UIControlEventValueChanged];
    
    //Init price cell
    _priceCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2
                                        reuseIdentifier:@"EditShoppingItemTable_PriceCell"];
    _priceCell.textLabel.text = NSLocalizedString(@"Price", nil);
    _priceCell.selectionStyle = UITableViewCellSelectionStyleNone;
    _priceCell.accessoryType = UITableViewCellAccessoryNone;

    if(!_isNewShoppingItem) {
        self.navigationItem.rightBarButtonItem = _editButton;
//        self.title = NSLocalizedString(@"Shopping Item", nil);
        
        _editImageView.image = [_initBasicInfo getDisplayImage];
        _nameCell.textLabel.text = _initBasicInfo.name;
        _nameCell.detailTextLabel.text = [StringUtil formatBarcode:_initBasicInfo.barcode];
        _nameField.text = _initBasicInfo.name;
        [self _updatePriceLabelWithPrice:_initShoppingItem.price];
        self.toolbar.hidden = NO;

        [self _updateUIFromBoughtStatus:_initShoppingItem.hasBought];
        _countStepper.value = _initShoppingItem.count;
        _countCell.detailTextLabel.text = [NSString stringWithFormat:@"%d", _initShoppingItem.count];
    } else {
        self.navigationItem.rightBarButtonItem = _saveButton;
        self.navigationItem.leftBarButtonItem = _cancelButton;
        self.title = NSLocalizedString(@"Add Item", nil);
        _saveButton.enabled = NO;
        self.toolbar.hidden = YES;
        _countStepper.value = 1;
        _countCell.detailTextLabel.text = @"1";
        [self _updateUIFromBoughtStatus:NO];
    }
    
    _isEditing = !_isNewShoppingItem;   //Force to skip value guard and toggle edit mode
    [self _toggleEditMode:_isNewShoppingItem animated:NO];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //Correctly put toolbar
    CGRect toolbarFrame = self.toolbar.frame;
    if(_isEditing) {
        toolbarFrame.origin.y = [UIScreen mainScreen].bounds.size.height - 44.0f -
                                [UIApplication sharedApplication].statusBarFrame.size.height;
    } else {
        toolbarFrame.origin.y = [UIScreen mainScreen].bounds.size.height - 44.0f - toolbarFrame.size.height -
                                [UIApplication sharedApplication].statusBarFrame.size.height;
    }
    self.toolbar.frame = toolbarFrame;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

//==============================================================
//  [BEGIN] UITableViewDelegate
#pragma mark - UITableViewDelegate
//--------------------------------------------------------------
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if(indexPath.section == kPriceSection &&
       _isEditing)
    {
        EnterPriceViewController *enterPriceVC = [[EnterPriceViewController alloc] initWithPrice:_tempShoppingItem.price];
        enterPriceVC.title = _tempBasicInfo.name;
        enterPriceVC.delegate = self;
        [self.navigationController pushViewController:enterPriceVC animated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == kImageAndNameSection) {
        return kImageHeight;
    }

    return tableView.rowHeight;
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
    if(indexPath.section == kImageAndNameSection) {
        return _nameCell;
    } else if(indexPath.section == kCountSection) {
        return _countCell;
    } else if(indexPath.section == kPriceSection) {
        return _priceCell;
    }

    static NSString *CellTableIdentitifier = @"EditShopingItemCellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
    if(cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellTableIdentitifier];
    }
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == kPriceSection &&
       _tempShoppingItem.price != 0.0f)
    {
        return YES;
    }

    return NO;
}

//- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    if(indexPath.section == kPriceSection &&
//       !_isEditing)
//    {
//        _backupItem = _shoppingItem;
//        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
//                                                                                               target:self
//                                                                                               action:@selector(_doneEditing)];
//    }
//}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(editingStyle == UITableViewCellEditingStyleDelete) {
        _tempShoppingItem.price = 0.0f;
        
        if(!_isEditing) {
            _initShoppingItem.price = 0.0f;
            
            //Since this must be an existed shopping item, we can save without assigning its MOC
            [CoreDataDatabase commitChanges:nil];
        }
        
        _priceCell.detailTextLabel.text = nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if(section == kPriceSection) {
        PriceStatistics *statistics = [CoreDataDatabase getPriceStatisticsOfBasicInfo:_tempBasicInfo];
        if(statistics.countOfPrices > 0) {
            return [NSString stringWithFormat:@"%@%@\n%@%@ ~ %@",
                    NSLocalizedString(@"Average: ", nil),
                    [_currencyFormatter stringFromNumber:[NSNumber numberWithDouble:statistics.avgPrice]],
                    NSLocalizedString(@"Range: ", nil),
                    [_currencyFormatter stringFromNumber:[NSNumber numberWithDouble:statistics.minPrice]],
                    [_currencyFormatter stringFromNumber:[NSNumber numberWithDouble:statistics.maxPrice]]];
        }
    }
    
    return nil;
}
//--------------------------------------------------------------
//  [END] UITableViewDataSource
//==============================================================

//==============================================================
//  [BEGIN] UIActionSheetDelegate
#pragma mark -
#pragma mark UIActionSheetDelegate Methods
//--------------------------------------------------------------
- (void)_takePhotoFromCamera
{
    if(!_hasRearCam) {
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
    [_autoFillBasicInfo setUIImage:nil];
    
    _userTakenImage = nil;
    [_tempBasicInfo setUIImage:nil];
    _editImageView.image = nil;
    _previewImageView.image = nil;
    _saveButton.enabled = [_tempBasicInfo canSave];
}

- (void) actionSheetCancel:(UIActionSheet *)actionSheet
{
}

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
    
    if(actionSheet == _organizeSheet) {
        if(buttonIndex < [_candidateFolders count]) {
#ifdef _LITE_
            if(![[NSUserDefaults standardUserDefaults] boolForKey:kPurchaseUnlimitCount]) {
                _alertLiteLimitation = nil;
                if([CoreDataDatabase totalItems] >= kLimitTotalItems) {
                    _alertLiteLimitation = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Limited Item Count", nil)
                                                                      message:NSLocalizedString(@"Would you like to remove the limitation?", nil)
                                                                     delegate:self
                                                            cancelButtonTitle:NSLocalizedString(@"No, thanks", nil)
                                                            otherButtonTitles:NSLocalizedString(@"Yes", nil), nil];
                }
                
                if(_alertLiteLimitation) {
                    [_alertLiteLimitation show];
                    return;
                }
            }
#endif
            //Since the shoppingItem is an existed object, we don't obtain a temp one
            EditItemViewController *editItemVC = [[EditItemViewController alloc]
                                                  initWithShoppingItem:_initShoppingItem
                                                  folder:[_candidateFolders objectAtIndex:buttonIndex]];
            editItemVC.delegate = self;
            UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:editItemVC];
            [self presentViewController:navCon animated:YES completion:NULL];
            
            [FlurryAnalytics logEvent:@"Organize shopping item"
                       withParameters:[NSDictionary dictionaryWithObject:@"Original Folder" forKey:@"Target"]];
        } else {  //Save to new folder
            [_initShoppingItem copyAttributesFrom:_tempShoppingItem];
            [_initBasicInfo copyAttributesFrom:_tempBasicInfo];
            [self.delegate shoppingItemWillBeginToMove:_initShoppingItem];
            
            [FlurryAnalytics logEvent:@"Organize shopping item"
                       withParameters:[NSDictionary dictionaryWithObject:@"New Folder" forKey:@"Target"]];
        }
        
        return;
    }
    
    if(actionSheet == _deleteSheet) {
        [CoreDataDatabase removeShoppingItem:_initShoppingItem updatePositionOfRestItems:YES];
        [CoreDataDatabase commitChanges:nil];
        return;
    }
    
    if(buttonIndex == 0) {
        if(_hasRearCam) {
            [self _takePhotoFromCamera];
        } else {
            [self _takePhotoFromAlbum];
        }
    } else if(buttonIndex == 1) {
        if(_hasRearCam) {
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
//  [BEGIN] UITextFieldDeleate
#pragma mark - UITextFieldDeleate
//--------------------------------------------------------------
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *candidateString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    _tempBasicInfo.name = candidateString;
    if([candidateString length] > 0) {
        //The basicInfo of the shoppingItem may changed to another basicInfo, so let's find it out
        DBItemBasicInfo *basicInfo = [CoreDataDatabase getItemBasicInfoByName:candidateString
                                                         shouldExcludeBarcode:NO];
        if(basicInfo != nil) {
            _autoFillBasicInfo = basicInfo;
            
            //Assign new image to existed basicInfo which has no image originally
            if(basicInfo.imageRawData == nil &&
               _userTakenImage != nil)
            {
                [basicInfo setUIImage:_userTakenImage];
            }
            
            if(basicInfo.shoppingItem != nil) {
                _autoFillShoppingItem = basicInfo.shoppingItem;
                [_autoFillShoppingItem copyAttributesFrom:_tempShoppingItem];
            }
            
            _editImageView.image = [basicInfo getDisplayImage];
            _saveButton.enabled = [basicInfo canSave];
        } else {
            [CoreDataDatabase cancelUnsavedChanges];    //auto fill item and basicInfo may be changed
            _autoFillBasicInfo = nil;
            _autoFillShoppingItem = nil;
            
            if(_userTakenImage != _tempBasicInfo.displayImage) {
                [_tempBasicInfo setUIImage:_userTakenImage];
            }
            
            _editImageView.image = [_tempBasicInfo getDisplayImage];
            _saveButton.enabled = [_tempBasicInfo canSave];
        }
    } else {
        [CoreDataDatabase cancelUnsavedChanges];    //auto fill item and basicInfo may be changed
        _autoFillBasicInfo = nil;
        _autoFillShoppingItem = nil;
        if(_userTakenImage != _tempBasicInfo.displayImage) {
            [_tempBasicInfo setUIImage:_userTakenImage];
        }
        
        _editImageView.image = [_tempBasicInfo getDisplayImage];
        _saveButton.enabled = [_tempBasicInfo canSave];
    }
    
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    _tempBasicInfo.name = nil;
    
    _editImageView.image = [_tempBasicInfo getDisplayImage];
    _saveButton.enabled = [_tempBasicInfo canSave];
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}
//--------------------------------------------------------------
//  [END] UITextFieldDeleate
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
        _userTakenImage = [editImage thumbnailImage:kImageSaveSize
                                  transparentBorder:0
                                       cornerRadius:0
                               interpolationQuality:kCGInterpolationHigh];
        
        [_tempBasicInfo setUIImage:_userTakenImage];
        _autoFillBasicInfo.imageRawData = _tempBasicInfo.imageRawData;
        _autoFillBasicInfo.displayImage = _tempBasicInfo.displayImage;
        
        _editImageView.image = _tempBasicInfo.displayImage;
        _saveButton.enabled = YES;
        
        _autoFillShoppingItem = nil;
        _autoFillBasicInfo = nil;
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
//  [BEGIN] IBActions
#pragma mark - IBActions
//--------------------------------------------------------------
- (IBAction)organizeButtonPressed:(id)sender
{
    [self _toggleEditMode:NO animated:YES];
    
    _candidateFolders = [CoreDataDatabase getFoldersContainsItemsRelatedToShoppingItem:_initShoppingItem];

    if([_candidateFolders count] > 0) { //The folder may be deleted, so we check the pointer instead of originalFolderIDD
        _organizeSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Move To:", nil)
                                                     delegate:self
                                            cancelButtonTitle:nil
                                       destructiveButtonTitle:nil
                                            otherButtonTitles:nil];
        
        for(DBFolder *folder in _candidateFolders) {
            [_organizeSheet addButtonWithTitle:folder.name];
        }
        [_organizeSheet addButtonWithTitle:NSLocalizedString(@"Another Folder", nil)];
        [_organizeSheet addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        _organizeSheet.cancelButtonIndex = [_candidateFolders count] + 1;   //1 is the "Another Folder" button

        [_organizeSheet showInView:self.view];
    } else {
        [self.delegate shoppingItemWillBeginToMove:_initShoppingItem];
    }
}

- (IBAction)deleteButtonPressed:(id)sender
{
    if(!_deleteSheet) {
        _deleteSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Confirm Removal", nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                     destructiveButtonTitle:NSLocalizedString(@"Remove Item", nil)
                                          otherButtonTitles:nil];
    }
    
    [_deleteSheet showInView:self.view];
}

- (IBAction)changeBoughtStatus:(id)sender
{
    _initShoppingItem.hasBought = !_initShoppingItem.hasBought;
    [CoreDataDatabase commitChanges:nil];
    [self _updateUIFromBoughtStatus:_initShoppingItem.hasBought];
}

- (void)_tapOnImageView:(UITapGestureRecognizer *)sender
{
    //Remember, user can only nlarge image in non-edit mode
    if(_isEditing ||
       [_initBasicInfo getDisplayImage] == nil ||
       sender.state != UIGestureRecognizerStateEnded)
    {
        return;
    }
    
    [self.table scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
    self.table.scrollEnabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    //Show larget image
    if(!_imagePreviewView) {
        _imagePreviewView = [[UIControl alloc] initWithFrame:self.table.frame];
        _imagePreviewView.userInteractionEnabled = YES;
        [_imagePreviewView addTarget:self action:@selector(dismissImage:) forControlEvents:UIControlEventTouchUpInside];
        
        _previewImageView = [[UIImageView alloc] init];
        _previewImageView.userInteractionEnabled = NO;
        _previewImageView.layer.cornerRadius = 10.0f;
        _previewImageView.layer.masksToBounds = YES;
        _previewImageView.layer.borderColor = [UIColor colorWithWhite:0.67f alpha:1.0f].CGColor;
        _previewImageView.layer.borderWidth = 1.0f;
        [_imagePreviewView addSubview:_previewImageView];
    }
    
    [self.table addSubview:_imagePreviewView];
    _imagePreviewView.backgroundColor = [UIColor clearColor];
    _imagePreviewView.hidden = NO;
    
    _previewImageView.image = [_initBasicInfo getDisplayImage];
    _previewImageView.frame = [_editImageView convertRect:_editImageView.bounds toView:_imagePreviewView];
    
    //Prepare bottom label area to show item's name
    CGFloat labelWidth = _imagePreviewView.frame.size.width - _previewImageView.frame.origin.x*2.0f;
    if(!_tapToDismissLabel) {
        _tapToDismissLabel = [[OutlineLabel alloc] initWithFrame:CGRectMake(0, 0, labelWidth, 50)];
        _tapToDismissLabel.textColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
        _tapToDismissLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25f];
        _tapToDismissLabel.font = [UIFont systemFontOfSize:21.0f];
        _tapToDismissLabel.textAlignment = UITextAlignmentCenter;
        _tapToDismissLabel.contentMode = UIViewContentModeCenter;
        _tapToDismissLabel.text = NSLocalizedString(@"Tap To Narrow Down", nil);
        [_previewImageView addSubview:_tapToDismissLabel];
    }
    _tapToDismissLabel.hidden = NO;
    
    if(!_imageLabelBackgroundView) {
        _imageLabelBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, labelWidth-kItemNameLabelHeight,
                                                                             labelWidth, kItemNameLabelHeight)];
        _imageLabelBackgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25f];
        [_previewImageView addSubview:_imageLabelBackgroundView];
    }
    
    if(!_imageLabel) {
        _imageLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 0.0f,
                                                                labelWidth-20.0f*2.0f,
                                                                _imageLabelBackgroundView.frame.size.height)];
        _imageLabel.backgroundColor = [UIColor clearColor];
        _imageLabel.textColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
        _imageLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
        _imageLabel.font = [UIFont boldSystemFontOfSize:21.0f];
        _imageLabel.numberOfLines = 2;
        _imageLabel.textAlignment = UITextAlignmentCenter;
        _imageLabel.contentMode = UIViewContentModeCenter;
        [_imageLabelBackgroundView addSubview:_imageLabel];
    }
    
    if([_initBasicInfo.name length] == 0) {
        _imageLabelBackgroundView.hidden = YES;
    } else {
        _imageLabelBackgroundView.hidden = NO;
        _imageLabel.text = _initBasicInfo.name;
    }

    _tapToDismissLabel.alpha = 0.0f;
    _imageLabelBackgroundView.alpha = 0.0f;

    [UIView animateWithDuration:0.33f
                          delay:0.0f
                        options:UIViewAnimationCurveEaseIn|UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         _imagePreviewView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
                         
                         CGRect targetFrame = _previewImageView.frame;
                         targetFrame.size.width = _imagePreviewView.frame.size.width-targetFrame.origin.x*2;
                         targetFrame.size.height = targetFrame.size.width;

                         _previewImageView.frame = targetFrame;
                     } completion:^(BOOL finished) {
                         if(finished) {
                             //Show image labels
                             [UIView animateWithDuration:0.1f
                                                   delay:0
                                                 options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionCurveEaseIn|UIViewAnimationOptionBeginFromCurrentState
                                              animations:^{
                                                  _tapToDismissLabel.alpha = 1.0f;
                                                  _imageLabelBackgroundView.alpha = 1.0f;
                                              } completion:^(BOOL finished) {
                                              }];
                         }
                     }];
}

- (void)dismissImage:(id)sender
{
    _imageLabelBackgroundView.hidden = YES;
    _tapToDismissLabel.hidden = YES;

    [UIView animateWithDuration:0.33f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         _previewImageView.frame = [_editImageView convertRect:_editImageView.bounds toView:_imagePreviewView];
                         _imagePreviewView.backgroundColor = [UIColor clearColor];
                     } completion:^(BOOL finished) {
                         _imagePreviewView.hidden = YES;
                         [_imagePreviewView removeFromSuperview];
                         
                         self.table.scrollEnabled = YES;
                         self.navigationItem.rightBarButtonItem.enabled = YES;
                     }];
}
//--------------------------------------------------------------
//  [END] IBActions
//==============================================================

//==============================================================
//  [BEGIN] EditItemViewControllerDelegate
#pragma mark - EditItemViewControllerDelegate
//--------------------------------------------------------------
- (void)cancelEditItem:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)finishEditItem:(id)sender
{
    //ShoppingItem has been saved as folderItem, so we can delete it now
    [self dismissViewControllerAnimated:YES completion:^{
        //Notification receiver in ShoppingListViewController will pop the view controller
        [CoreDataDatabase removeShoppingItem:_initShoppingItem updatePositionOfRestItems:YES];
        [CoreDataDatabase commitChanges:nil];
    }];
}
//--------------------------------------------------------------
//  [END] EditItemViewControllerDelegate
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
//  [BEGIN] UIAlertViewDelegate
#pragma mark - UIAlertViewDelegate
//--------------------------------------------------------------
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if(alertView.cancelButtonIndex == buttonIndex) {
        return;
    }
    
#ifdef _LITE_
    if(alertView == _alertLiteLimitation) {
        InAppPurchaseViewController *iapVC = [[InAppPurchaseViewController alloc] init];
        iapVC.delegate = self;
        [self presentModalViewController:iapVC animated:YES];
    }
#endif
}
//--------------------------------------------------------------
//  [END] UIAlertViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] EnterPriceViewControllerDelegate
#pragma mark - EnterPriceViewControllerDelegate
//--------------------------------------------------------------
- (void)cancelEnteringPrice
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)finishEnteringPrice:(double)price
{
    [self.navigationController popViewControllerAnimated:YES];
    _tempShoppingItem.price = price;
    [self _updatePriceLabelWithPrice:price];
}
//--------------------------------------------------------------
//  [END] EnterPriceViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] Private Methods
#pragma mark - Private Methods
//--------------------------------------------------------------
- (void)_toggleEditMode:(BOOL)isEditing animated:(BOOL)animate
{
    if(isEditing == _isEditing) {
        return;
    }
    
    [_editImageView setEditing:isEditing animated:animate duration:0.3f];
    _isEditing = isEditing;
    
    CGRect toolbarFrame = self.toolbar.frame;
    if(isEditing) {
        _tempShoppingItem = [CoreDataDatabase obtainTempShoppingItem];
        _tempBasicInfo = [CoreDataDatabase obtainTempItemBasicInfo];
        [_tempShoppingItem copyAttributesFrom:_initShoppingItem];
        [_tempBasicInfo copyAttributesFrom:_initBasicInfo];
        if(_isNewShoppingItem) {
            //We'll move it to 0 before saving, but we need to assign a position to move later
            _tempShoppingItem.listPosition = [CoreDataDatabase totalShoppingItems];
            _tempShoppingItem.count = 1;
        }
            
        _priceCell.selectionStyle = UITableViewCellSelectionStyleBlue;
        _priceCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        [_editImageView removeGestureRecognizer:_imageTapGR];
        _countCell.accessoryView = _countStepper;
        
        _nameCell.textLabel.text = nil;
        _nameCell.detailTextLabel.text = nil;
        [_nameCell addSubview:_nameField];

        if(animate) {
            _countStepper.alpha = 0.0f;
            _nameField.alpha = 0.0f;
            [UIView animateWithDuration:kAnimationDuration
                                  delay:0
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                                 _countStepper.alpha = 1.0f;
                                 _nameField.alpha = 1.0f;
                             } completion:^(BOOL finished) {
                                 
                             }];
        } else {
            _countStepper.alpha = 1.0f;
            _nameField.alpha = 1.0f;
        }
        
        toolbarFrame.origin.y = [UIScreen mainScreen].bounds.size.height - 44.0f -
                                [UIApplication sharedApplication].statusBarFrame.size.height;
    } else {
        _priceCell.selectionStyle = UITableViewCellSelectionStyleNone;
        _priceCell.accessoryType = UITableViewCellAccessoryNone;

        [_editImageView addGestureRecognizer:_imageTapGR];
        _nameCell.textLabel.text = _initBasicInfo.name;
        _nameCell.detailTextLabel.text = [StringUtil formatBarcode:_initBasicInfo.barcode];
        [_nameCell layoutSubviews];

        if(animate) {
            [UIView animateWithDuration:kAnimationDuration
                                  delay:0
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                                 _countStepper.alpha = 0.0f;
                                 _nameField.alpha = 0.0f;
                             } completion:^(BOOL finished) {
                                 _countCell.accessoryView = nil;
                             }];
        } else {
            _countCell.accessoryView = nil;
        }
        
        _tempBasicInfo = nil;
        _tempShoppingItem = nil;
        
        toolbarFrame.origin.y = [UIScreen mainScreen].bounds.size.height - 44.0f - toolbarFrame.size.height -
                                [UIApplication sharedApplication].statusBarFrame.size.height;
    }
    
    if(!animate) {
        self.toolbar.frame = toolbarFrame;
    } else {
        [UIView animateWithDuration:0.3f
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
                             self.toolbar.frame = toolbarFrame;
                         }
                         completion:NULL];
    }
    
    [self.table reloadData];
}

- (void)_editButtonPressed:(id)sender
{
    self.navigationItem.leftBarButtonItem = _cancelButton;
    self.navigationItem.rightBarButtonItem = _saveButton;
    
    [self _toggleEditMode:YES animated:YES];
}

- (void)_saveItem:(id)sender
{
    [_nameField resignFirstResponder];
    
    if(_isNewShoppingItem) {
        if(_autoFillBasicInfo == nil) {
            //User create a new basicInfo
            if(_tempBasicInfo.managedObjectContext == nil) {
                [[CoreDataDatabase mainMOC] insertObject:_tempBasicInfo];
            }
            
            _initBasicInfo = _tempBasicInfo;
        } else {
            _initBasicInfo = _autoFillBasicInfo;
        }
        
        if(_autoFillShoppingItem == nil) {
            if(_tempShoppingItem.managedObjectContext == nil) {
                [[CoreDataDatabase mainMOC] insertObject:_tempShoppingItem];
            }
            
            _initShoppingItem = _tempShoppingItem;
            [CoreDataDatabase moveShoppingItem:_initShoppingItem to:0]; //For shifting other shopping items' listPosition
        } else {
            _initShoppingItem = _autoFillShoppingItem;
        }
        
        _initShoppingItem.basicInfo = _initBasicInfo;
        [CoreDataDatabase commitChanges:nil];
        
        _isNewShoppingItem = NO;
        [self.delegate finishEditingShoppingItem:_initShoppingItem];
    } else {
        if(_autoFillBasicInfo == nil) {
            [_initBasicInfo copyAttributesFrom:_tempBasicInfo];
        } else {
            _initBasicInfo = _autoFillBasicInfo;
        }
        
        if(_autoFillShoppingItem == nil) {
            [_initShoppingItem copyAttributesFrom:_tempShoppingItem];
        } else {
            [_autoFillShoppingItem copyAttributesFrom:_tempShoppingItem];
            _initShoppingItem = _autoFillShoppingItem;
        }
        
        _initShoppingItem.basicInfo = _initBasicInfo;
        [CoreDataDatabase commitChanges:nil];
        
        self.navigationItem.leftBarButtonItem = nil;
        self.navigationItem.rightBarButtonItem = _editButton;
        [self _toggleEditMode:NO animated:YES];
    }

    [self.table reloadData];
}

- (void)_cancelEditing:(id)sender
{
    [_nameField resignFirstResponder];
    [CoreDataDatabase cancelUnsavedChanges];    //auto fill item and basicInfo may be changed

    if(_isNewShoppingItem) {
        [self.delegate cancelEditingShoppingItem];
    } else {
        self.navigationItem.leftBarButtonItem = nil;
        self.navigationItem.rightBarButtonItem = _editButton;
        [self _toggleEditMode:NO animated:YES];
        
        _editImageView.image = [_initBasicInfo getDisplayImage];
        _nameCell.textLabel.text = _initBasicInfo.name;
        _nameCell.detailTextLabel.text = [StringUtil formatBarcode:_initBasicInfo.barcode];
        _nameField.text = _initBasicInfo.name;
        _countCell.detailTextLabel.text = [NSString stringWithFormat:@"%d", _initShoppingItem.count];
        [self _updatePriceLabelWithPrice:_initShoppingItem.price];
    }
    
    [self.table reloadData];
}

- (void)_selectImage:(id)sender
{
    [_nameField resignFirstResponder];
    
    if(!_hasRearCam  && ![_editImageView hasImage]) {
        [self _takePhotoFromAlbum];
    } else {
        UIActionSheet *pickImageSheet = [[UIActionSheet alloc] init];
        
        pickImageSheet.title = NSLocalizedString(@"Pick Image From:", nil);
        pickImageSheet.cancelButtonIndex = 1;
        
        if(_hasRearCam) {
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

- (void)_countChanged:(UIStepper *)sender
{
    _tempShoppingItem.count = sender.value;
    _countCell.detailTextLabel.text = [NSString stringWithFormat:@"%d", _tempShoppingItem.count];
    [_nameField resignFirstResponder];

    [FlurryAnalytics logEvent:@"Shopping count changed"];
}

- (void)_updateUIFromBoughtStatus:(BOOL)hasBought
{
    if(hasBought) {
        self.boughtStatusText.title = NSLocalizedString(@"Bought", nil);
        self.view.backgroundColor = [[UIColor alloc] initWithPatternImage:
                                      [UIImage imageNamed:@"group_table_background_bought"]];
    } else {
        self.boughtStatusText.title = NSLocalizedString(@"Not Bought", nil);
        self.view.backgroundColor = [[UIColor alloc] initWithPatternImage:
                                      [UIImage imageNamed:@"group_table_background"]];
    }
}

- (void)_updatePriceLabelWithPrice:(float)price
{
    if(price != 0.0f) {
        _priceCell.detailTextLabel.text = [_currencyFormatter stringFromNumber:
                                           [NSNumber numberWithDouble:price]];
    } else {
        _priceCell.detailTextLabel.text = nil;
    }
    
    [_priceCell layoutSubviews];
}

- (void)_willShowKeyboard:(NSNotification *)notification
{
    //1. Get keyboard frame
    CGRect keyboardFrame = ((NSValue *)[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey]).CGRectValue;
    double animDuration = [((NSNumber *)[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey]) doubleValue];
    
    //2. Adjust frame
    CGRect tableFrame = self.table.frame;
    tableFrame.size.height = [[UIScreen mainScreen] bounds].size.height - 44.0f - [[UIApplication sharedApplication] statusBarFrame].size.height - keyboardFrame.size.height;
    [UIView animateWithDuration:animDuration
                     animations:^{
                         self.table.frame = tableFrame;
                     }];
}

- (void)_willHideKeyboard:(NSNotification *)notification
{
    double animDuration = [((NSNumber *)[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey]) doubleValue];
    
    //2. Adjust frame
    CGRect tableFrame = self.table.frame;
    tableFrame.size.height = [[UIScreen mainScreen] bounds].size.height - 44.0f - [[UIApplication sharedApplication] statusBarFrame].size.height;
    [UIView animateWithDuration:animDuration
                     animations:^{
                         self.table.frame = tableFrame;
                     }];
}
//--------------------------------------------------------------
//  [END] Private Methods
//==============================================================
@end
