//
//  NewFolderViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/09/17.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import "EditFolderViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "CoreDataDatabase.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "UIImage+Resize.h"
#import "UIImage+SaveToDisk.h"
#import "StringUtil.h"
#import "UIScreen+RetinaDetection.h"
#import "HardwareUtil.h"
#import "PreferenceConstant.h"
#import "FlurryAnalytics.h"
#import "ColorConstant.h"

#import "DBFolder+Validate.h"
#import "DBFolder+SetAndGet.h"
#import "NSManagedObject+DeepCopy.h"

@interface EditFolderViewController (PrivateMethods)
- (void)_handleTap:(UIGestureRecognizer *)gr;
- (void)_takePhotoFromAlbum;
- (void)_updateDataToTempFolder;
@end

enum {
    kNameCellIndex = 0,
    kLockCellIndex,
//    kColorCellIndex
};

@implementation EditFolderViewController

@synthesize table;
@synthesize nameCell;
@synthesize folderImageView;
@synthesize editImageView;
@synthesize editNameView;
@synthesize nameField;
@synthesize lockCell;
@synthesize lockField;
@synthesize delegate;
@synthesize saveStatedelegate;
@synthesize skipChekingTextField;
@synthesize folderData=_folderData;

- (void)_initWithFolder:(DBFolder *)folder
{
    self.folderData = folder;
    
    if(_folderData == nil) {
        _folderData = [CoreDataDatabase obtainTempFolder];
        _tempFolder = _folderData;
        _isNewFolder = YES;
    } else if([_folderData.objectID isTemporaryID]) {
        _tempFolder = _folderData;
        _isNewFolder = YES;
    } else {
        _tempFolder = [CoreDataDatabase obtainTempFolder];
        [_tempFolder copyAttributesFrom:folder];
    }
}

- (id) initWithFolderData: (DBFolder *)folder
{
    if((self = [super initWithNibName:nil bundle:nil])) {
        [self _initWithFolder:folder];
    }
    
    return self;
}

- (id) initToCreateFolderOnly: (DBFolder *)folder
{
    if((self = [super initWithNibName:nil bundle:nil])) {
        [self _initWithFolder:folder];
        _createFolderOnly = YES;
    }
    
    return self;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.table = nil;
    self.nameCell = nil;
    self.folderImageView = nil;
    self.editImageView = nil;
    self.editNameView = nil;
    self.nameField = nil;
    self.lockCell = nil;
    self.lockField = nil;
//    self.colorCell = nil;
//    self.colorButton = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
}


- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationController.navigationBar.tintColor = kColorNavigationBarTintColor;
    
    //If editing an existed locked folder
    if(![_folderData.objectID isTemporaryID] &&
       [_folderData.password length] > 0)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_applicationWillResignActive)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
    }
    
    if([HardwareUtil hasRearCam]) {
        rearCamEnabled = YES;
    } else {
        rearCamEnabled = NO;
    }

    // Do any additional setup after loading the view from its nib.
    skipChekingTextField = NO;

//    self.colorButton.layer.borderColor = [UIColor darkGrayColor].CGColor;
//    self.colorButton.layer.borderWidth = 3.0;
    
    UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTap:)];
    tapGR.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGR];
    
    self.nameCell.backgroundColor = [UIColor clearColor];    //Must set here, IB doesn't work for this
    self.nameCell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];  //remove grouped style

    //Init Image
    self.editImageView = [[EditImageView alloc] initWithFrame:CGRectMake(0, 0, kImageWidth, kImageHeight)];
    self.editImageView.editing = YES;
    self.folderImageView.userInteractionEnabled = YES;
    [self.folderImageView addSubview:self.editImageView];
    self.editImageView.image = [_tempFolder getDisplayImage];
    [self.editImageView.editView addTarget:self action:@selector(selectImage:) forControlEvents:UIControlEventTouchUpInside];
    
    self.editNameView.layer.borderWidth = 1;
    self.editNameView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.editNameView.layer.cornerRadius = 10;
    nameField = [[UITextField alloc] initWithFrame:CGRectMake(self.editNameView.layer.cornerRadius, 1,
                                                              self.editNameView.frame.size.width-self.editNameView.layer.cornerRadius,
                                                              self.editNameView.frame.size.height-2)];
    self.nameField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.nameField.backgroundColor = [UIColor clearColor];
    self.nameField.placeholder = NSLocalizedString(@"Name(Required)", @"Show in folder name field");
    self.nameField.delegate = self;
    self.nameField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    self.nameField.returnKeyType = UIReturnKeyDone;
    [self.editNameView addSubview:self.nameField];

    self.lockCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2
                                            reuseIdentifier:@"EditFolderTalbe_PasswordCell"];
    self.lockCell.selectionStyle = UITableViewCellSelectionStyleNone;
    self.lockCell.textLabel.text = NSLocalizedString(@"Password", nil);
    [self.lockCell layoutSubviews];
    int nLabelWidth = self.lockCell.textLabel.frame.size.width;
    self.lockField = [[UITextField alloc] initWithFrame:CGRectMake(nLabelWidth, 0, 300-nLabelWidth, 42)];
    self.lockField.borderStyle = UITextBorderStyleNone;
    self.lockField.clearButtonMode = UITextFieldViewModeAlways;
    self.lockField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    self.lockField.secureTextEntry = YES;
    self.lockField.clearButtonMode = UITextFieldViewModeAlways;
    self.lockField.placeholder = NSLocalizedString(@"Password", nil);
    self.lockField.returnKeyType = UIReturnKeyDone;
    self.lockField.text = _tempFolder.password;
    self.lockField.delegate = self;
    [self.lockCell.contentView addSubview:self.lockField];

    if(![_folderData.objectID isTemporaryID] ||
       _createFolderOnly)
    {
        self.nameField.text = _tempFolder.name;
        
        //Add navigation bar
        UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                   target:self
                                                                                   action:@selector(doneEditing:)];
        self.navigationItem.rightBarButtonItem = barButton;
        self.navigationItem.rightBarButtonItem.enabled = [_folderData canSave];
        
        barButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                  target:self
                                                                  action:@selector(cancelEditing:)];
        self.navigationItem.leftBarButtonItem = barButton;
        
        if(_createFolderOnly) {
            self.navigationItem.title = NSLocalizedString(@"New Folder", nil);
        } else {
            self.navigationItem.title = NSLocalizedString(@"Edit Folder", nil);
        }
    }

    if([_tempFolder.name length] == 0) {
        [self.nameField becomeFirstResponder];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)_updateDataToTempFolder
{
    [_tempFolder setImage:self.editImageView.image];
    _tempFolder.name = self.nameField.text;
    _tempFolder.password = ([self.lockField.text length] > 0) ? self.lockField.text : nil;
}

-(BOOL)saveFolderToDatabase
{
    [self _updateDataToTempFolder];
    [_folderData copyAttributesFrom:_tempFolder];
    if([_folderData.objectID isTemporaryID] ||
       _folderData.managedObjectContext == nil)
    {
        [[CoreDataDatabase mainMOC] insertObject:_folderData];
    }
    
    NSError *error;
    if(![CoreDataDatabase commitChanges:&error]) {
        return NO;
    }
    
    return YES;
}

//==============================================================
//  [BEGIN] UITextFieldDelegate
#pragma mark -
#pragma mark UITextFieldDelegate
//--------------------------------------------------------------
- (BOOL) textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (void) textFieldDidEndEditing:(UITextField *)textField
{
    if(skipChekingTextField) {  //Skip when cancel editing
        return;
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if(textField == self.nameField) {
        NSString *candidateString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        _tempFolder.name = candidateString;
        self.navigationItem.rightBarButtonItem.enabled = ([_tempFolder canSave] ||
                                                          (!_isNewFolder &&
                                                           [_tempFolder.name isEqualToString:_folderData.name]));
        
        //For creating item and folder at the same time
        [self.saveStatedelegate canSaveFolder:self.navigationItem.rightBarButtonItem.enabled];
    } else if(textField == self.lockField) {
        _tempFolder.password = ([self.lockField.text length] > 0) ? self.lockField.text : nil;
    }

    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    if(textField == self.nameField) {
        _tempFolder.name = nil;
        self.navigationItem.rightBarButtonItem.enabled = NO;
        [self.saveStatedelegate canSaveFolder:NO];
    }

    return YES;
}
//--------------------------------------------------------------
//  [END] UITextFieldDelegate
//==============================================================

- (IBAction)cancelEditing: (id)sender
{
    skipChekingTextField = YES;
    
    if(![_folderData.objectID isTemporaryID]) {
        [_tempFolder copyAttributesFrom:_folderData];
    }
    
    [self.delegate cancelEditFolder:self];
}

- (IBAction)doneEditing: (id)sender
{
    [self saveFolderToDatabase];
    [self.delegate finishEditFolder:self withFolderData:_folderData];
}

- (void)selectImage:(id)sender
{
    [self dismissKeyboard];
    
    if(!rearCamEnabled  && ![self.editImageView hasImage]) {
        [self _takePhotoFromAlbum];
    } else {
        UIActionSheet *pickImageSheet = [[UIActionSheet alloc] init];
        
        pickImageSheet.title = NSLocalizedString(@"Pick Image From:", nil);
        pickImageSheet.cancelButtonIndex = 1;                                               //Every iOS device has albums
        
        if(rearCamEnabled) {
            [pickImageSheet addButtonWithTitle:NSLocalizedString(@"Camera", nil)];          // 0
            pickImageSheet.cancelButtonIndex++;
        }
        
        [pickImageSheet addButtonWithTitle:NSLocalizedString(@"Photo Albums", nil)];        // 0 or 1
        
        if([self.editImageView hasImage]) {
            [pickImageSheet addButtonWithTitle:NSLocalizedString(@"Remove Image", nil)];    // 1 or 2
            pickImageSheet.destructiveButtonIndex = pickImageSheet.cancelButtonIndex;
            pickImageSheet.cancelButtonIndex++;
        }
        
        [pickImageSheet addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];              // 1 or 2 or 3
        
        pickImageSheet.delegate = self;
        
        [pickImageSheet showInView:self.navigationController.view];
    }
}

- (void)_handleTap:(UIGestureRecognizer *)gr
{
    if(gr.state == UIGestureRecognizerStateRecognized) {
        [self dismissKeyboard];
    }
}

- (void)dismissKeyboard
{
    [self.nameField resignFirstResponder];
    [self.lockField resignFirstResponder];
}

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [respondViewAfterDismissAlert becomeFirstResponder];
    respondViewAfterDismissAlert = nil;
}

//==============================================================
//  [BEGIN] UITableViewDataSource
#pragma mark -
#pragma mark UITableViewDataSource Methods
//--------------------------------------------------------------
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellTableIdentitifier = @"EditFolderTable";
    UITableViewCell *cell = nil;
    
    switch(indexPath.section) {
        case kNameCellIndex:
            return self.nameCell;
//        case kColorCellIndex:
//            return self.colorCell;
        case kLockCellIndex:
            return self.lockCell;
        default:
            cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
            if(cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellTableIdentitifier];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
    }
    
    return cell;
}

//--------------------------------------------------------------
//  [END] UITableViewDataSource
//==============================================================

//==============================================================
//  [BEGIN] UITableViewDelegate
#pragma mark -
#pragma mark UITableViewDelegate Methods
//--------------------------------------------------------------
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == kNameCellIndex) {
        return self.nameCell.frame.size.height;
    }
    
    return tableView.rowHeight;
}
//--------------------------------------------------------------
//  [END] UITableViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] UIActionSheetDelegate
#pragma mark -
#pragma mark UIActionSheetDelegate Methods
//--------------------------------------------------------------
- (void)_takePhotoFromCamera
{
    if(!rearCamEnabled) {
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
    [_tempFolder setImage:nil];
    self.editImageView.image = nil;
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
        if(rearCamEnabled) {
            [self _takePhotoFromCamera];
        } else {
            [self _takePhotoFromAlbum];
        }
    } else if(buttonIndex == 1) {
        if(rearCamEnabled) {
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
//  [BEGIN] UIImagePickerControllerDelegate
#pragma mark -
#pragma mark UIImagePickerControllerDelegate Methods
//--------------------------------------------------------------
- (void) imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissModalViewControllerAnimated:YES];
//    NSLog(@"Cancel to pick image");
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissModalViewControllerAnimated:YES];
    
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    if(CFStringCompare((__bridge CFStringRef)mediaType, kUTTypeImage, 0) == kCFCompareEqualTo) {
        UIImage *editImage = [info objectForKey:UIImagePickerControllerEditedImage];
        
        UIImage *resizedImage = [editImage thumbnailImage:kThumbImageSize
                                        transparentBorder:0
                                             cornerRadius:0
                                     interpolationQuality:kCGInterpolationHigh];
        self.editImageView.image = resizedImage;
    } else {
        [FlurryAnalytics logEvent:@"Fail to take image for folder"
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

- (void)_applicationWillResignActive
{
    [self.delegate cancelEditFolder:self];
}
@end
