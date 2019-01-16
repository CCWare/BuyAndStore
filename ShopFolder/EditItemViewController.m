//
//  NewItemViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/09/19.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>   //For using CALayer
#import "EditItemViewController.h"
#import "CoreDataDatabase.h"
#import "TimeUtil.h"
#import "PickDateViewController.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "UIImage+Resize.h"
#import "UIImage+SaveToDisk.h"
#import "StringUtil.h"
#import "UIScreen+RetinaDetection.h"
#import "ListItemCell.h"
#import "NotificationConstant.h"
#import "ColorConstant.h"
#import "HardwareUtil.h"
#import "VersionCompare.h"
#import "SetExpirePeriodViewController.h"
#import "PreferenceConstant.h"
#import "FlurryAnalytics.h"

#import "DBFolderItem+ChangeLog.h"
#import "DBFolderItem+expiryOperations.h"
#import "DBFolderItem+Validate.h"

#import "DBItemBasicInfo+SetAdnGet.h"
#import "DBItemBasicInfo+Validate.h"
#import "NSManagedObject+DeepCopy.h"

#import "DBFolderItem+ChangeLog.h"

#define kItemNameLabelHeight    60.0f

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

//Section index
#define kNameSectionIndex       0
#define kCountSectionIndex      1
#define kDateSectionIndex       2
#define kPriceSectionIndex      3
#define kLocationSectionIndex   4
#define kNoteSectionIndex       5
#define kHistorySectionIndex    6

int g_nRealPriceSectionIndex    = kPriceSectionIndex;
int g_nRealLocationSectionIndex = kLocationSectionIndex;
int g_nRealNoteSectionIndex     = kNoteSectionIndex;
int g_nRealHistorySectionIndex  = kHistorySectionIndex;

//Row index
#define kCreateDateRowIndex     0
#define kExpireDateRowIndex     1
#define kExpireAlertRowIndex    2

@interface EditItemViewController (PrivateMethods)
- (void)_updateBarcodeField;
- (void)_updateCountLabel;
- (void)_updatePriceLabel;
- (void)_updateCreateDateLabel;
- (void)_updateExpireDateLabel;
- (void)_updateLocaltionLabel;
- (void)_updateNoteView;

- (void)_syncDataToUI;

- (void)_updateNameData;

- (void)_enterEditMode;
- (void)_toggleEditMode:(BOOL)editing animated:(BOOL)animate;
- (void)_addChangeLog:(NSDictionary *)changes oldItem:(DBFolderItem *)item;

- (void)_takePhotoFromAlbum;

- (void)_willShowKeyboard:(NSNotification *)notification;
- (void)_willHideKeyboard:(NSNotification *)notification;

- (NSString *)_formatNearExpiredDays;
- (void)_tapOnImageView:(UITapGestureRecognizer *)sender;

- (void)_initNearExpiredDaysFromItem:(DBFolderItem *)item;
- (void)_sortNearExpiredDays;

- (void)_autoFillBarcode:(Barcode *)barcode;

- (void)_receiveManagedObjectContextDidSaveNotification:(NSNotification *)notification;
@end

@implementation EditItemViewController

@synthesize canEditBasicInfo=_canEditBasicInfo;

@synthesize table;
@synthesize nameCell;
@synthesize editImageView;
@synthesize nameField;
@synthesize barcodeField;
@synthesize countCell;
@synthesize countStepper;
@synthesize countEditView;
@synthesize countField;
@synthesize priceCell;
@synthesize createDateCell;
@synthesize expiryDateCell;
@synthesize alertDaysCell;
@synthesize locationCell;
@synthesize noteCell;
@synthesize delegate;
@synthesize saveStateDelegate;

- (void)_initWithItem:(DBFolderItem *)item basicInfo:(DBItemBasicInfo *)basicInfo folder:(DBFolder *)folder
{
    _canEditBasicInfo = YES;
    
    _initFolder = folder;
    _initItem = item;
    _initBasicInfo = basicInfo;
    _pickedLocation = _initItem.location;
    _changeLogs = [_initItem localizedChangeLogs];
    
    //Init _tempBasicInfo
    if(_initBasicInfo == nil ||
       [_initBasicInfo.objectID isTemporaryID])
    {
        if(_initBasicInfo == nil) {
            _initBasicInfo = [CoreDataDatabase obtainTempItemBasicInfo];
        }
        _tempBasicInfo = _initBasicInfo;
    } else {    //Caller may pass a new folderItem with existed basicInfo, ex: add a shoppingItem
        [_initBasicInfo getDisplayImage];
        _tempBasicInfo = [CoreDataDatabase obtainTempItemBasicInfo];
        [_tempBasicInfo copyAttributesFrom:_initBasicInfo];
    }
    
    //Init _tempItem
    if(_initItem == nil ||
       [_initItem.objectID isTemporaryID])
    {
        _isNewItem = YES;
        
        if(_initItem == nil) {
            _initItem = [CoreDataDatabase obtainTempFolderItem];
        }
        _tempItem = _initItem;
        if(_tempItem.count < 1) {
            _tempItem.count = 1;
        }
        _tempItem.createTime = [[TimeUtil today] timeIntervalSinceReferenceDate];
    } else {
        _tempItem = [CoreDataDatabase obtainTempFolderItem];
        [_tempItem copyAttributesFrom:_initItem];
        
        isExpiredBeforeEditing = [_initItem isExpired];
        isNearExpiredBeforeEditing = [_initItem isNearExpired];
    }
    
    _expireDate = _initItem.expiryDate;
    [self _initNearExpiredDaysFromItem:_initItem];
    
    integerFormatter = [[NSNumberFormatter alloc] init];
    integerFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    integerFormatter.generatesDecimalNumbers = YES;
    integerFormatter.maximumFractionDigits = 0;
    integerFormatter.groupingSeparator = @",";
    
    _imageTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tapOnImageView:)];
}

- (id)initWithFolderItem:(DBFolderItem *)item basicInfo:(DBItemBasicInfo *)basicInfo folder:(DBFolder *)folder
{
    if((self = [super initWithNibName:nil bundle:nil])) {
        [self _initWithItem:item basicInfo:basicInfo folder:folder];
    }
    
    return self;
}

- (id)initWithShoppingItem:(DBShoppingItem *)shoppingItem folder:(DBFolder *)folder
{
    if((self = [super initWithNibName:nil bundle:nil])) {
        DBFolderItem *item = [CoreDataDatabase obtainTempFolderItem];
        item.price = shoppingItem.price;
        item.currencyCode = shoppingItem.currencyCode;
        item.count = shoppingItem.count;
        
        [self _initWithItem:item basicInfo:shoppingItem.basicInfo folder:folder];
    }
    
    return self;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.nameCell = nil;
    self.editImageView = nil;
    self.nameField = nil;
    self.barcodeField = nil;
    self.countCell = nil;
    self.countStepper = nil;
    self.countEditView = nil;
    self.countField = nil;
    self.createDateCell = nil;
    self.expiryDateCell = nil;
    self.alertDaysCell = nil;
    self.priceCell = nil;
    self.locationCell = nil;
    self.noteCell = nil;
    self.table = nil;
    
    editNameTable = nil;
    editFieldFont = nil;
    
    _previewImageView = nil;
    _imagePreviewView = nil;
    _imageLabelBackgroundView = nil;
    _imageLabel = nil;
    _tapToDismissLabel = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:nil];
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
    self.countStepper.value = _tempItem.count;
    
    //Regiester notifications for keyboard show/hide (iOS 5 suooprts "change")
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_willShowKeyboard:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_willHideKeyboard:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    if([HardwareUtil hasRearCam]) {
        rearCamEnabled = YES;
    } else {
        rearCamEnabled = NO;
    }
    
    editFieldFont = [UIFont systemFontOfSize:17];
    fEditCellHeight = editFieldFont.lineHeight + 2*kEditCellVerticalSpace;

    // Do any additional setup after loading the view from its nib.
//    self.table.allowsSelectionDuringEditing = YES;
    editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                               target:self
                                                               action:@selector(_enterEditMode)];

    doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                               target:self
                                                               action:@selector(doneEditing:)];

    //Init key cell
    self.nameCell = [[ListItemCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                            reuseIdentifier:@"NameCell"];
    self.nameCell.frame = CGRectMake(0, 0, self.nameCell.frame.size.width, kImageHeight);

    //Init Image
    CGRect rect = CGRectMake(0, 0, kImageWidth, kImageHeight);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
    CGContextFillRect(context, rect);
    UIImage *backgroundImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    self.nameCell.imageView.image = backgroundImage;

    self.editImageView = [[EditImageView alloc] initWithFrame:CGRectMake(0, 0, kImageWidth, kImageHeight)];
    self.nameCell.imageView.userInteractionEnabled = YES;
    self.nameCell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.nameCell.imageView.contentStretch = CGRectMake(0, 0, 0, 0);  //Not to resize to content
    [self.nameCell.imageView addSubview:self.editImageView];
    [self.editImageView.editView addTarget:self action:@selector(selectImage:) forControlEvents:UIControlEventTouchUpInside];

    self.nameCell.selectionStyle = UITableViewCellSelectionStyleNone;
    self.nameCell.backgroundColor = [UIColor clearColor];    //Must set here, IB doesn't work for this
    self.nameCell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];  //remove grouped style
    
    //Init Count cell
    self.countCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2
                                                  reuseIdentifier:@"EdititemTable_CountIdentifier"];
    self.countCell.selectionStyle = UITableViewCellSelectionStyleNone;
    self.countCell.textLabel.text = NSLocalizedString(@"Count", nil);
    [self.countCell layoutSubviews];
    
    self.countEditView.frame = CGRectMake(kDetailViewX, 0, 300-kDetailViewX, self.table.rowHeight);
    [self.countCell.contentView addSubview:self.countEditView];
    self.countField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    self.countField.delegate = self;
    
    //Init CreateDate cell
    self.createDateCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2
                                                  reuseIdentifier:@"EdititemTable_CreateDateIdentifier"];
    self.createDateCell.textLabel.text = NSLocalizedString(@"Create", @"TextLabel of cell to set create date");
    self.createDateCell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    //Init ExpireDate cell
    self.expiryDateCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2
                                                   reuseIdentifier:@"EdititemTable_ExpireDateIdentifier"];
    self.expiryDateCell.textLabel.text = NSLocalizedString(@"Expiry Date", nil);
    self.expiryDateCell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    //Init AlertDays cell
    self.alertDaysCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2
                                                reuseIdentifier:@"EdititemTable_AlertDaysIdentifier"];
    self.alertDaysCell.textLabel.text = NSLocalizedString(@"Notify", nil);
    self.alertDaysCell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    //Init Price cell
    self.priceCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2
                                                  reuseIdentifier:@"EdititemTable_PriceCellIdentifier"];
    self.priceCell.textLabel.text = NSLocalizedString(@"Price", nil);
    self.priceCell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    //Init Localtion cell
    self.locationCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2
                                               reuseIdentifier:@"EdititemTable_LocationCellIdentifier"];
    self.locationCell.textLabel.text = NSLocalizedString(@"Buy from", nil);
    self.locationCell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    //Init Note cell
    self.noteCell = [[FlexibleHeightTableViewCell alloc] initWithStyle:UITableViewCellStyleValue2
                                                       reuseIdentifier:@"EdititemTable_NoteCellIdentifier"];
    self.noteCell.textLabel.text = NSLocalizedString(@"Notes", nil);
    self.noteCell.selectionStyle = UITableViewCellSelectionStyleNone;
    [self.noteCell layoutSubviews];
    
    //Duplicate textLabel for showing at top instead of middle
    UILabel *replaceLabel = [[UILabel alloc] init];
    replaceLabel.frame = CGRectMake(10, 15, kDetailViewX-6-10, 15);
    replaceLabel.font = self.noteCell.textLabel.font;
    replaceLabel.textColor = self.noteCell.textLabel.textColor;
    replaceLabel.textAlignment = self.noteCell.textLabel.textAlignment;
    replaceLabel.text = self.noteCell.textLabel.text;
    replaceLabel.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
    replaceLabel.backgroundColor = [UIColor clearColor];
    [self.noteCell.contentView addSubview:replaceLabel];
    self.noteCell.textLabel.text = @" ";

    CGRect textViewFrame = CGRectMake(kDetailViewX-6, kTextViewVerticalSpace,
                                      322-kDetailViewX, self.table.rowHeight-2*kTextViewVerticalSpace);

    noteView = [[CustomEdgeTextView alloc] initWithFrame:textViewFrame];
    noteView.autocorrectionType = UITextAutocorrectionTypeNo;
    noteView.autoresizingMask = UIViewAutoresizingFlexibleWidth;//|UIViewAutoresizingFlexibleHeight;
    noteView.font = [UIFont boldSystemFontOfSize:17];
//    noteView.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:0.1];
    noteView.backgroundColor = [UIColor clearColor];
    noteView.delegate = self;
    noteView.customInset = UIEdgeInsetsMake(-kTextViewInset, 0, kTextViewInset, 0);
    noteView.scrollEnabled = NO;
    noteView.scrollsToTop = NO; //If not set, scroll to top will fail when noteView has scrollbar
    [noteView setContentOffset:CGPointMake(0, kTextViewInset) animated:NO];
//    self.noteCell.contentView.backgroundColor = [UIColor colorWithRed:0 green:1 blue:0 alpha:0.2];
    [self.noteCell.contentView addSubview:noteView];

    noteView.text = _tempItem.note;

    if([_initFolder.objectID isTemporaryID]) {
      [self _toggleEditMode: YES animated:NO];
    } else {
        if(_isNewItem) {
            self.title = NSLocalizedString(@"Add Item", @"Title for add an item");
            [self _toggleEditMode: YES animated:NO];
        } else {
            self.title = NSLocalizedString(@"Edit Item", @"Title for edit an item");
            [self _toggleEditMode: NO animated:NO];
        }
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_receiveManagedObjectContextDidSaveNotification:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:nil];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.table deselectRowAtIndexPath:[self.table indexPathForSelectedRow] animated:NO];

    if(_pickedLocation &&
       [_pickedLocation isFault])
    {
        _pickedLocation = nil;
    }
    
    [self _updateCreateDateLabel];
    [self _updateExpireDateLabel];
    [self _updatePriceLabel];
    [self _updateLocaltionLabel];
    [self _updateNoteView];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [self dismissKeyboard];

    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    //TODO: Adjust noteView frame
}

//==============================================================
//  [BEGIN] UITableViewDataSource
#pragma mark -
#pragma mark UITableViewDataSource Methods
//--------------------------------------------------------------
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if(tableView == self.table) {
        g_nRealPriceSectionIndex = kPriceSectionIndex;
        g_nRealLocationSectionIndex = kLocationSectionIndex;
        g_nRealNoteSectionIndex = kNoteSectionIndex;
        g_nRealHistorySectionIndex = kHistorySectionIndex;

        if(isEditing) {
            g_nRealHistorySectionIndex = -1;
            return 6;   //hide history
        }

        int nSectionCount = 4;  //At least Name, Count, Date and History

        if(_tempItem.price != 0) {
            nSectionCount++;
        } else {
            g_nRealPriceSectionIndex = -1;
            g_nRealLocationSectionIndex--;
            g_nRealNoteSectionIndex--;
            g_nRealHistorySectionIndex--;
        }

        if(_pickedLocation) {
            nSectionCount++;
        } else {
            g_nRealLocationSectionIndex = -1;
            g_nRealNoteSectionIndex--;
            g_nRealHistorySectionIndex--;
        }
        
        if([_tempItem.note length] > 0) {
            nSectionCount++;
        } else {
            g_nRealNoteSectionIndex = -1;
            g_nRealHistorySectionIndex--;
        }

        return nSectionCount;
    } else if(tableView == editNameTable) {
        return 1;
    }

    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(tableView == self.table) {
        if(section == kDateSectionIndex)
        {
            if(isEditing) {
                if(_expireDate) {
                    return 3;
                }

                return 2;
            }

            if(_expireDate) {
                return 3;
            }
        } else if(section == g_nRealHistorySectionIndex) {
            return [_changeLogs count];
        }

        return 1;
    } else if(tableView == editNameTable) {
        return 2;   //Name and Barcode
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    if(tableView == self.table) {
        static NSString *CellTableIdentitifier = @"EditItemTable";

        if(indexPath.section == kNameSectionIndex) {
            return self.nameCell;
        } else if(indexPath.section == kCountSectionIndex) {
            return self.countCell;
        } else if(indexPath.section == kDateSectionIndex) {
            if(indexPath.row == kCreateDateRowIndex) {
                return self.createDateCell;
            } else if(indexPath.row == kExpireDateRowIndex) {
                return self.expiryDateCell;
            } else {
                return self.alertDaysCell;
            }
        } else if(indexPath.section == g_nRealPriceSectionIndex) {
            return self.priceCell;
        } else if(indexPath.section == g_nRealLocationSectionIndex) {
            return self.locationCell;
        } else if(indexPath.section == g_nRealNoteSectionIndex) {
            return self.noteCell;
        } else if(indexPath.section == g_nRealHistorySectionIndex) {
            static NSString *ChangeLogCellIdentitifier = @"ChangeLogCellIdentifier";
            cell = [tableView dequeueReusableCellWithIdentifier:ChangeLogCellIdentitifier];
            if(cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:ChangeLogCellIdentitifier];
                cell.textLabel.font = [UIFont systemFontOfSize:12.0f];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            
            //Most recently change on top
            ChangeLog *changeLog = [_changeLogs objectAtIndex:([_changeLogs count]-1 - indexPath.row)];
            cell.detailTextLabel.text = [TimeUtil timeToRelatedDescriptionFromNow:changeLog.time
                                                                    limitedRange:kDefaultRelativeTimeDescriptionRange];
            cell.textLabel.text = changeLog.log;
        } else {
            cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
            if(cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellTableIdentitifier];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
        }
    } else if(tableView == editNameTable) {
        static NSString *CellTableIdentitifier = @"EditingTable";
        cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
        if(cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellTableIdentitifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            UITextField *textField = nil;
            if(indexPath.row == 0) {
                if(self.nameField == nil) {
                    self.nameField = [[UITextField alloc] initWithFrame:CGRectMake(kEditCellHorizontalSpace, kEditCellVerticalSpace, kEditTableWidth-kEditCellHorizontalSpace, fEditCellHeight)];
                    self.nameField.font = editFieldFont;
                    self.nameField.placeholder = NSLocalizedString(@"Name", nil);
                    self.nameField.delegate = self;
                    self.nameField.returnKeyType = UIReturnKeyDone;
                }

                self.nameField.text = _tempBasicInfo.name;
                textField = self.nameField;
            } else if(indexPath.row == 1) {
                if(self.barcodeField == nil) {
                    self.barcodeField = [[UITextField alloc] initWithFrame:CGRectMake(kEditCellHorizontalSpace, 0, kEditTableWidth-kEditCellHorizontalSpace, fEditCellHeight)];
                    self.barcodeField.font = editFieldFont;
                    self.barcodeField.placeholder = NSLocalizedString(@"Barcode", nil);
                    self.barcodeField.keyboardType = UIKeyboardTypeNumberPad;
                    self.barcodeField.clearButtonMode = UITextFieldViewModeAlways;
                    self.barcodeField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
                    self.barcodeField.delegate = self;
                }

                [self _updateBarcodeField];
                textField = self.barcodeField;
            }

            textField.borderStyle = UITextBorderStyleNone;
            [cell.contentView addSubview:textField];
        }
    }

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(tableView == self.table) {
        //Cannot clear count by swiping when editing
        if(indexPath.section == kCountSectionIndex &&
           (isEditing || _tempItem.count == 0))
        {
            return NO;
        }
        
        if(indexPath.section == g_nRealHistorySectionIndex) {
            return NO;
        }

        if(indexPath.section != kNameSectionIndex &&
           !(indexPath.section == kDateSectionIndex && indexPath.row == kCreateDateRowIndex))
        {
            return YES;
        }
    }
    
    return NO;
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(tableView == self.table &&
       !isEditing)
    {
        self.navigationItem.rightBarButtonItem = doneButton;
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(tableView == self.table &&
       editingStyle == UITableViewCellEditingStyleDelete)
    {

        if(indexPath.section == kCountSectionIndex) {
            int nCount = _tempItem.count;
            if(nCount != 0) {
                if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                    [FlurryAnalytics logEvent:@"Swipe Action"
                               withParameters:[NSDictionary dictionaryWithObject:@"Clear Count" forKey:@"Action"]];
                }

                _tempItem.count = 0;
                if(isEditing) {
                    [self _updateCountLabel];
                } else {
                    //1. Copy edited data
                    DBFolderItem *originItemData = [CoreDataDatabase obtainTempFolderItem];
                    [originItemData copyAttributesFrom:_initItem];
                    _initItem.count = 0;
                    
                    NSDictionary *changes = [_initItem changedValues];
                    if([changes count] > 0) {
                        //2. Add changeLog
                        [self _addChangeLog:changes oldItem:originItemData];
                        _initItem.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
                        
                        if([CoreDataDatabase commitChanges:nil]) {
                            [self _updateCountLabel];
                            self.expiryDateCell.detailTextLabel.textColor = [UIColor darkTextColor];
                            
                            [self.table beginUpdates];
                            _changeLogs = [_initItem localizedChangeLogs];
                            [self.table insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:g_nRealHistorySectionIndex]]
                                              withRowAnimation:UITableViewRowAnimationAutomatic];
                            [self.table endUpdates];
                        } else {
                            [CoreDataDatabase cancelUnsavedChanges];
                            _tempItem.count = nCount;
                        }
                    }
                }
            }
        } else if(indexPath.section == g_nRealLocationSectionIndex) {
            if(_pickedLocation) {
                if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                    [FlurryAnalytics logEvent:@"Swipe Action"
                               withParameters:[NSDictionary dictionaryWithObject:@"Clear Location" forKey:@"Action"]];
                }

                if(isEditing) {
                    _pickedLocation = nil;
                    [self _updateLocaltionLabel];
                } else {
                    //1. Copy edited data
                    _initItem.location = nil;
                    
                    NSDictionary *changes = [_initItem changedValues];
                    if([changes count] > 0) {
                        [self _addChangeLog:changes oldItem:nil];   //Removing does not need old data
                        _initItem.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
                        
                        if([CoreDataDatabase commitChanges:nil]) {
                            _pickedLocation = nil;
                            [self.table beginUpdates];
                            [self.table deleteSections:[NSIndexSet indexSetWithIndex:g_nRealLocationSectionIndex]
                                      withRowAnimation:UITableViewRowAnimationTop];
                            [self.table endUpdates];
                            
                            [self.table beginUpdates];
                            _changeLogs = [_initItem localizedChangeLogs];
                            [self.table insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:g_nRealHistorySectionIndex]]
                                              withRowAnimation:UITableViewRowAnimationAutomatic];
                            [self.table endUpdates];
                        } else {
                            [CoreDataDatabase cancelUnsavedChanges];
                        }
                    }
                }
            }
        } else if(indexPath.section == g_nRealNoteSectionIndex) {
            if([_tempItem.note length] > 0) {
                if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                    [FlurryAnalytics logEvent:@"Swipe Action"
                               withParameters:[NSDictionary dictionaryWithObject:@"Clear Note" forKey:@"Action"]];
                }

                NSString *note = _tempItem.note;
                _tempItem.note = nil;

                if(isEditing) {
                    noteView.text = nil;
                    [self _updateNoteView];
                } else {
                    noteView.text = nil;
                    
                    //1. Copy edited data
                    _initItem.note = nil;
                    
                    NSDictionary *changes = [_initItem changedValues];
                    if([changes count] > 0) {
                        //2. Add changeLog
                        [self _addChangeLog:changes oldItem:nil];   //Removing does not need old data
                        _initItem.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
                        
                        if([CoreDataDatabase commitChanges:nil]) {
                            [self.table beginUpdates];
                            [self.table deleteSections:[NSIndexSet indexSetWithIndex:g_nRealNoteSectionIndex]
                                      withRowAnimation:UITableViewRowAnimationTop];
                            [self.table endUpdates];
                            
                            [self.table beginUpdates];
                            _changeLogs = [_initItem localizedChangeLogs];
                            [self.table insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:g_nRealHistorySectionIndex]]
                                              withRowAnimation:UITableViewRowAnimationAutomatic];
                            [self.table endUpdates];
                        } else {
                            [CoreDataDatabase cancelUnsavedChanges];
                            _tempItem.note = note;
                            noteView.text = note;
                        }
                    }
                }
            }
        } else if(indexPath.section == g_nRealPriceSectionIndex) {
            if(_tempItem.price != 0.0f) {
                if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                    [FlurryAnalytics logEvent:@"Swipe Action"
                               withParameters:[NSDictionary dictionaryWithObject:@"Clear Price" forKey:@"Action"]];
                }

                double dPrice = _tempItem.price;
                _tempItem.price = 0;

                if(isEditing) {
                    [self _updatePriceLabel];
                } else {
                    //1. Copy edited data
                    _initItem.price = 0;
                    
                    NSDictionary *changes = [_initItem changedValues];
                    if([changes count] > 0) {
                        //2. Add changeLog
                        [self _addChangeLog:changes oldItem:nil];   //Removing does not need old data
                        _initItem.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
                        
                        if([CoreDataDatabase commitChanges:nil]) {
                            [self.table beginUpdates];
                            [self.table deleteSections:[NSIndexSet indexSetWithIndex:g_nRealPriceSectionIndex]
                                      withRowAnimation:UITableViewRowAnimationTop];
                            [self.table endUpdates];

                            [self.table beginUpdates];
                            _changeLogs = [_initItem localizedChangeLogs];
                            [self.table insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:g_nRealHistorySectionIndex]]
                                              withRowAnimation:UITableViewRowAnimationAutomatic];
                            
                            [self.table endUpdates];
                        } else {
                            [CoreDataDatabase cancelUnsavedChanges];
                            _tempItem.price = dPrice;
                        }
                    }
                }
            }
        } else if(indexPath.section == kDateSectionIndex) {
            if(indexPath.row == kExpireDateRowIndex) {
                if(_expireDate) {
                    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                        [FlurryAnalytics logEvent:@"Swipe Action"
                                   withParameters:[NSDictionary dictionaryWithObject:@"Clear Expiry Date" forKey:@"Action"]];
                    }

                    if(isEditing) {
                        _expireDate = nil;
                        [self _updateExpireDateLabel];
                        
                        //Remove row of near-expiry alert days
                        if([self.table numberOfRowsInSection:kDateSectionIndex] == 3) {
                            [self.table beginUpdates];
                            [self.table deleteRowsAtIndexPaths:[NSArray arrayWithObject:
                                                                [NSIndexPath indexPathForRow:kExpireAlertRowIndex
                                                                                   inSection:kDateSectionIndex]]
                                              withRowAnimation:UITableViewRowAnimationTop];
                            [self.table endUpdates];
                        }
                    } else {
                        DBNotifyDate *expireDate = _initItem.expiryDate;
                        _expireDate = nil;
                        
                        //1. Copy edited data
                        _initItem.expiryDate = nil;
                        
                        NSDictionary *changes = [_initItem changedValues];
                        if([changes count] > 0) {
                            //2. Add changeLog
                            [self _addChangeLog:changes oldItem:nil];   //Removing does not need old data
                            _initItem.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
                            
                            if([CoreDataDatabase commitChanges:nil]) {
                                if([self.table numberOfRowsInSection:kDateSectionIndex] == 3) {
                                    [self.table beginUpdates];
                                    [self.table deleteRowsAtIndexPaths:[NSArray arrayWithObjects:
                                                                        [NSIndexPath indexPathForRow:kExpireDateRowIndex
                                                                                           inSection:kDateSectionIndex],
                                                                        [NSIndexPath indexPathForRow:kExpireAlertRowIndex
                                                                                           inSection:kDateSectionIndex], nil]
                                                      withRowAnimation:UITableViewRowAnimationTop];
                                    [self.table endUpdates];
                                    
                                    [self.table beginUpdates];
                                    _changeLogs = [_initItem localizedChangeLogs];
                                    [self.table insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:g_nRealHistorySectionIndex]]
                                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                                    [self.table endUpdates];
                                }
                            } else {
                                _expireDate = expireDate;
                                [CoreDataDatabase cancelUnsavedChanges];
                            }
                        }
                    }
                }
            } else if(indexPath.row == kExpireAlertRowIndex) {
                if([_nearExpiredDays count] > 0) {
                    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                        [FlurryAnalytics logEvent:@"Swipe Action"
                                   withParameters:[NSDictionary dictionaryWithObject:@"Clear Alert Days" forKey:@"Action"]];
                    }

                    if(isEditing) {
                        [_nearExpiredDays removeAllObjects];
                        [self _updateExpireDateLabel];
                    } else {
                        [_nearExpiredDays removeAllObjects];
                        
                        //1. Copy edited data
                        _initItem.nearExpiryDates = nil;
                        
                        NSDictionary *changes = [_initItem changedValues];
                        if([changes count] > 0) {
                            //2. Add changeLog
                            [self _addChangeLog:changes oldItem:nil];   //Removing does not need old data
                            _initItem.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
                            
                            if ([CoreDataDatabase commitChanges:nil]) {
                                [self _updateExpireDateLabel];
                                
                                [self.table beginUpdates];
                                _changeLogs = [_initItem localizedChangeLogs];
                                [self.table insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:g_nRealHistorySectionIndex]]
                                                  withRowAnimation:UITableViewRowAnimationAutomatic];
                                [self.table endUpdates];
                            } else {
                                [CoreDataDatabase cancelUnsavedChanges];
                                [self _initNearExpiredDaysFromItem:_initItem];
                            }
                        }
                    }
                }
            }
        } //end of if(indexPath.section == kDateSectionIndex)...

    }
}

- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(tableView == self.table &&
       !isEditing)
    {
        self.navigationItem.rightBarButtonItem = editButton;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if(tableView == self.table) {
        if(section == kNameSectionIndex) {
            if(isEditing &&
               self.canEditBasicInfo)
            {
                return NSLocalizedString(@"Please fill at least one of the data above.", @"Footer for key field section section");
            }
        }
    }
    
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if(tableView == self.table &&
       section == g_nRealHistorySectionIndex)
    {
        return NSLocalizedString(@"Change Log", nil);
    }
    
    return nil;
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
    if(tableView == self.table) {
        if(indexPath.section == kNameSectionIndex) {
            if(isEditing &&
               self.canEditBasicInfo)
            {
                //May be different if more than two cells in editTable
                if(editNameTable.frame.size.height > kImageHeight) {
                    return editNameTable.frame.size.height;
                } else {
                    return kImageHeight;
                }
            } else {
                return kImageHeight;
            }
        } else if(indexPath.section == g_nRealNoteSectionIndex) {
            if([noteView.text length] > 0) {
                CGFloat height = noteView.contentSize.height - 2*kTextViewInset;
                if(UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
                    int MAX_TEXT_HEIGHT = kMaxTextViewHeightPortrait - [[UIApplication sharedApplication] statusBarFrame].size.height;
                    if([[UIScreen mainScreen] bounds].size.height == 568) {
                        MAX_TEXT_HEIGHT += 88;
                    }
                    
                    if(height > MAX_TEXT_HEIGHT) {
                        height = MAX_TEXT_HEIGHT;
                    }
                } else {
                    const int MAX_TEXT_HEIGHT = kMaxTextViewHeightLandscape - [[UIApplication sharedApplication] statusBarFrame].size.height;
                    if(height > MAX_TEXT_HEIGHT) {
                        height = MAX_TEXT_HEIGHT;
                    }
                }
                
                height += 2*kTextViewVerticalSpace;
                if(height < self.table.rowHeight) {
                    height = self.table.rowHeight;
                }
                return height;
            }
        } else if(indexPath.section == g_nRealHistorySectionIndex) {
            return 22.0f;
        }

        return tableView.rowHeight;
    } else if(tableView == editNameTable) {
        return fEditCellHeight;
    }
    
    return 0;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(!isEditing) {
        return;
    }

    selectedIndex = indexPath;
    if(tableView == self.table) {
        if(indexPath.section == kDateSectionIndex) {
            PickDateViewController *vc;
            if(indexPath.row == kCreateDateRowIndex) {
                vc = [[PickDateViewController alloc] initWithCellName:NSLocalizedString(@"Create", @"TextLabel of cell to set create date")
                                                              andDate:[NSDate dateWithTimeIntervalSinceReferenceDate:_tempItem.createTime]];
                vc.isColoredByExpiryDate = NO;
                vc.showQuickSelection = NO;
                vc.canClearDate = NO;
                
                vc.title = _tempBasicInfo.name;
                vc.delegate = self;
                [self.navigationController pushViewController:vc animated:YES];
            } else if(indexPath.row == kExpireDateRowIndex) {
                vc = [[PickDateViewController alloc] initWithCellName:NSLocalizedString(@"Expiry Date", nil)
                                                              andDate:[NSDate dateWithTimeIntervalSinceReferenceDate:_expireDate.date]];
                vc.isColoredByExpiryDate = YES;
                vc.showQuickSelection = YES;
                vc.canClearDate = YES;
                
                vc.title = _tempBasicInfo.name;
                vc.delegate = self;
                [self.navigationController pushViewController:vc animated:YES];
            } else {
                SetExpirePeriodViewController *selectDaysVC = [[SetExpirePeriodViewController alloc]
                                                               initForSelectMultipleDays:_nearExpiredDays];
                if([_tempBasicInfo.name length] > 0) {
                    selectDaysVC.title = _tempBasicInfo.name;
                } else {
                    selectDaysVC.title = NSLocalizedString(@"Notify Days", nil);
                }
                
                selectDaysVC.delegate = self;
                [self.navigationController pushViewController:selectDaysVC animated:YES];
            }
        } else if(indexPath.section == g_nRealPriceSectionIndex) {
            EnterPriceViewController *vc = [[EnterPriceViewController alloc] initWithPrice:_tempItem.price];
            vc.title = _tempBasicInfo.name;
            vc.delegate = self;
            [self.navigationController pushViewController:vc animated:YES];
        } else if(indexPath.section == g_nRealLocationSectionIndex) {
            PickLocationViewController *listLocationVC = [[PickLocationViewController alloc] init];
            listLocationVC.title = NSLocalizedString(@"Select Place", nil);
            listLocationVC.delegate = self;
            [self.navigationController pushViewController:listLocationVC animated:YES];
        } else if(indexPath.section == g_nRealNoteSectionIndex) {
            [noteView becomeFirstResponder];
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NSLocalizedString(@"Clear", @"Clear content of UITableViewCell");
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    //If not set, table won't scroll when keyboard appears
    return YES;
}
//--------------------------------------------------------------
//  [END] UITableViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] UITextFieldDelegate
#pragma mark -
#pragma mark UITextFieldDelegate Methods
//--------------------------------------------------------------
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if (textField == self.countField) {
        //Clear count field when it was 0 before editing
        if(_tempItem.count == 0) {
            textField.text = nil;
        }
    } else if(textField == self.barcodeField) {
        if(rearCamEnabled) {
            [self dismissKeyboard];
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
    if(textField == self.nameField) {
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
                //Try to get existed basicInfo which has the same name
                _candidateBasicInfo = [CoreDataDatabase getItemBasicInfoByName:candidateString shouldExcludeBarcode:YES];
                if(_candidateBasicInfo) {
                    if(_tempBasicInfo.imageRawData == nil) {
                        //If we have not took an image, try to use image of _candidateBasicInfo
                        if(_candidateBasicInfo.imageRawData != nil) {
                            [_tempBasicInfo setUIImage:[_candidateBasicInfo getDisplayImage]];
                            self.editImageView.image = _tempBasicInfo.displayImage;
                        }
                    } else {
                        //If we have take an image and candidate has no image, try to assign image to candidate
                        if(_candidateBasicInfo.imageRawData == nil) {
                            [_candidateBasicInfo setUIImage:[_tempBasicInfo getDisplayImage]];
                            self.editImageView.image = _tempBasicInfo.displayImage;
                        }
                    }
                }
            }
        }
        
        self.navigationItem.rightBarButtonItem.enabled = ((_candidateBasicInfo != nil) || [_tempBasicInfo canSave]);
        [self.saveStateDelegate canSaveItem:self.navigationItem.rightBarButtonItem.enabled];
        return YES;
    } else {
        if(textField == self.countField ||                      //Count field
           (textField == self.barcodeField && !rearCamEnabled)) //User typed barcode, otherwise handle in barcodeScanned:
        {
            //No digit
            if([candidateString length] == 0) {
                if(textField == self.countField) {
                    _tempItem.count = 0;
                    self.countStepper.value = 0;
                } else {
                    [_tempBasicInfo setBarcode:nil];
                    _candidateBasicInfo = nil;
                    self.navigationItem.rightBarButtonItem.enabled = [_tempBasicInfo canSave];
                }
                
                return YES;
            }
            
            //Not pure digit string
            if(![integerFormatter numberFromString:candidateString]) {
                return NO;
            }
            
            //Not integer
            range = [candidateString rangeOfString:@"."];
            if(range.length > 0) {
                return NO;
            }
            
            //Count exceeds range
            if(textField == self.countField) {
                int value = [candidateString intValue];
                if(value > self.countStepper.maximumValue ||
                   value < self.countStepper.minimumValue)
                {
                    return NO;
                }
                
                self.countStepper.value = value;
                if(value <= 0) {
                    _tempItem.count = 0;
                    
                    //Always shows "0" when the value is 0 instead of "00000"
                    self.countField.text = @"0";
                    return NO;
                } else {
                    _tempItem.count = value;
                }
            } else {
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
    }
    
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    if(textField == self.barcodeField) {
        textField.text = nil;
        
        [_tempBasicInfo setBarcode:nil];
        _candidateBasicInfo = [CoreDataDatabase getItemBasicInfoByName:_tempBasicInfo.name shouldExcludeBarcode:YES];
        if(_candidateBasicInfo) {   //If there is another basicInfo has the same name with no barcode
            
            //Use candidate's image if it has one
            if(_candidateBasicInfo.imageRawData != nil) {
                [_tempBasicInfo setUIImage:[_candidateBasicInfo getDisplayImage]];
                self.editImageView.image = _tempBasicInfo.displayImage;
            }
        }
        
        self.navigationItem.rightBarButtonItem.enabled = [_tempBasicInfo canSave];
        [self.saveStateDelegate canSaveItem:self.navigationItem.rightBarButtonItem.enabled];
        return NO;  //YES will make text field become first responder
    }
    
    return YES;
}
//--------------------------------------------------------------
//  [END] UITextFieldDelegate
//==============================================================

//==============================================================
//  [BEGIN] UITextViewDelegate
#pragma mark - UITextViewDelegate Methods
//--------------------------------------------------------------
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    if(!isEditing) {
        return NO;
    }

    //Set text here to let text view scrolls to cursor
    noteView.text = _tempItem.note;
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView
{
    //1. Update data
    _tempItem.note = textView.text;

    //2. Adjust noteView frame
    [self _updateNoteView];
}
//--------------------------------------------------------------
//  [END] UITextViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] IBAction Methods
#pragma mark -
#pragma mark IBAction Methods
//--------------------------------------------------------------
- (IBAction)stepCount:(UIStepper *)sender
{
    _tempItem.count = sender.value;
    self.countField.text = [NSString stringWithFormat:@"%d", _tempItem.count];
}

- (void)saveItem: (id)sender
{
    if([self saveItemToDatabase]) {
        if(!_isNewItem) {
            [self _toggleEditMode:NO animated:YES];
        }
    }

    //Don't have to call removeFromSuperview since superview will dismiss modal view
}

- (void)doneEditing: (id)sender
{
    self.navigationItem.rightBarButtonItem = editButton;
    [self.table setEditing:NO animated:YES];
}

- (void) cancelEditing: (id)sender
{
    [_tempBasicInfo copyAttributesFrom:_initBasicInfo];
    [_tempItem copyAttributesFrom:_initItem];
    _expireDate = _initItem.expiryDate;
    [self _initNearExpiredDaysFromItem:_initItem];
    _pickedLocation = _initItem.location;

    [self dismissKeyboard];
    if(_isNewItem) {
        [self.delegate cancelEditItem:self];
    } else {
        [self _toggleEditMode:NO animated:YES];
    }
    
    //Only updated when text changes
    NSString *dataText = (_tempItem.note) ? _tempItem.note : @"";
    NSString *viewText = (noteView.text) ? noteView.text : @"";
    if(![dataText isEqualToString:viewText]) {
        noteView.text = _tempItem.note;
    }
    [self _updateNoteView];

    [self.table setContentOffset:CGPointMake(0, offsetBeforeEditing) animated:YES];

    //Don't have to call removeFromSuperview since superview will dismiss modal view
}

- (void)selectImage:(id)sender
{
    [self dismissKeyboard];

    if(!rearCamEnabled && ![self.editImageView hasImage]) {
        [self _takePhotoFromAlbum];
    } else {
        UIActionSheet *pickImageSheet = [[UIActionSheet alloc] init];
        
        pickImageSheet.title = NSLocalizedString(@"Pick Image From:", nil);
        pickImageSheet.cancelButtonIndex = 1;
        
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

- (void)_tapOnImageView:(UITapGestureRecognizer *)sender
{
    if((isEditing && self.canEditBasicInfo) ||
       sender.state != UIGestureRecognizerStateEnded ||
       _tempBasicInfo.imageRawData == nil)
    {
        return;
    }
    
    [self.table scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
    self.table.scrollEnabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;

    //Prepare large image view
    if(!_imagePreviewView) {
        _imagePreviewView = [[UIControl alloc] initWithFrame:self.table.frame];
        _imagePreviewView.userInteractionEnabled = YES;
        [_imagePreviewView addTarget:self action:@selector(dismissImage:) forControlEvents:UIControlEventTouchUpInside];
        
        _previewImageView = [[UIImageView alloc] init];
        _previewImageView.userInteractionEnabled = NO;
        _previewImageView.layer.masksToBounds = YES;
        _previewImageView.layer.borderColor = [UIColor colorWithWhite:0.67f alpha:1.0f].CGColor;
        _previewImageView.layer.borderWidth = 1.0f;
        _previewImageView.layer.cornerRadius = 10.0f;
        [_imagePreviewView addSubview:_previewImageView];
    }
    
    [self.table addSubview:_imagePreviewView];
    _imagePreviewView.backgroundColor = [UIColor clearColor];
    _imagePreviewView.hidden = NO;
    
    _previewImageView.image = [_tempBasicInfo getDisplayImage];
    _previewImageView.frame = [self.editImageView convertRect:self.editImageView.bounds toView:_imagePreviewView];

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
        _imageLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, labelWidth-20.0f*2.0f, _imageLabelBackgroundView.frame.size.height)];
        _imageLabel.backgroundColor = [UIColor clearColor];
        _imageLabel.textColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
        _imageLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
        _imageLabel.font = [UIFont boldSystemFontOfSize:21.0f];
        _imageLabel.numberOfLines = 2;
        _imageLabel.textAlignment = UITextAlignmentCenter;
        _imageLabel.contentMode = UIViewContentModeCenter;
        [_imageLabelBackgroundView addSubview:_imageLabel];
    }
    
    if([_tempBasicInfo.name length] == 0) {
        _imageLabelBackgroundView.hidden = YES;
    } else {
        _imageLabelBackgroundView.hidden = NO;
        _imageLabel.text = _tempBasicInfo.name;
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
                         _previewImageView.frame = [self.editImageView convertRect:self.editImageView.bounds toView:_imagePreviewView];
                         _imagePreviewView.backgroundColor = [UIColor clearColor];
                     } completion:^(BOOL finished) {
                         _imagePreviewView.hidden = YES;
                         [_imagePreviewView removeFromSuperview];
                         self.table.scrollEnabled = YES;
                         self.navigationItem.rightBarButtonItem.enabled = YES;
                     }];
}
//--------------------------------------------------------------
//  [END] IBAction Methods
//==============================================================

//==============================================================
//  [BEGIN] Instance Methods
#pragma mark -
#pragma mark Instance Methods
//--------------------------------------------------------------
-(BOOL)saveItemToDatabase
{
    //Save button is only enabled if basicInfo is validated, so we don't validate basicInfo again
    
    //Add itemData before basicInfo because they must be in the same MOC
    if(_isNewItem) {
        //Create a new item
        if(_initItem == nil) {
            _initItem = _tempItem;
        } else {
            [_initItem copyAttributesFrom:_tempItem];
        }
        
        [[CoreDataDatabase mainMOC] insertObject:_initItem];
    }
    
    _initItem.location = _pickedLocation;
    
    //Add expireDate and nearExpireDates
    if(_expireDate != nil &&
       _expireDate.managedObjectContext == nil)
    {
        [[CoreDataDatabase mainMOC] insertObject:_expireDate];
    }
    _initItem.expiryDate = _expireDate;
    
    if(_expireDate == nil) {
        _initItem.nearExpiryDates = nil;
    } else {
        NSDate *nearExpireDate;
        DBNotifyDate *notifyDate;
        NSMutableSet *nearExpiredDates = [NSMutableSet set];    //set of DBNotifyDate
        for(NSNumber *nearExpireDay in _nearExpiredDays) {
            nearExpireDate = [TimeUtil dateFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:_expireDate.date]
                                             inDays: -[nearExpireDay intValue]];
            notifyDate = [CoreDataDatabase getNotifyDateOfDate:nearExpireDate];
            if(notifyDate == nil) {
                notifyDate = [CoreDataDatabase obtainNotifyDate];
                notifyDate.date = [nearExpireDate timeIntervalSinceReferenceDate];
            }
            [nearExpiredDates addObject:notifyDate];
        }
        
        if([nearExpiredDates count] > 0) {
            _initItem.nearExpiryDates = nearExpiredDates;
        } else {
            _initItem.nearExpiryDates = nil;
        }
    }
    
    //Update basicInfo or add a new one
    if(_candidateBasicInfo) {
        //_candidateBasicInfo will be assigned in two conditions:
        //1. User scanned an existed barcode
        //2. Barcode is empty, but user typed an existed name
        
        _initItem.basicInfo = _candidateBasicInfo;
        if([_candidateBasicInfo.barcodeData length] > 0) {
            //_candidateBasicInfo has barcode, but name and image may be changed or removed
            _candidateBasicInfo.name = _tempBasicInfo.name;
            [_candidateBasicInfo setUIImage:[_tempBasicInfo getDisplayImage]];
        } else {
            //_candidateBasicInfo has no barcode and the name is not changed,
            //otherwise _candidateBasicInfo will be nil
            //but image may be changed or removed
            [_candidateBasicInfo setUIImage:[_tempBasicInfo getDisplayImage]];
        }
    } else if(_initBasicInfo == nil ||                 //new basicInfo
              [_initBasicInfo.objectID isTemporaryID])
    {
        if(_tempBasicInfo.managedObjectContext == nil) {
            [[CoreDataDatabase mainMOC] insertObject:_tempBasicInfo];
        }
        
        if(_initItem.basicInfo == nil) {
            _initItem.basicInfo = _tempBasicInfo;
        } else {
            [_initItem.basicInfo copyAttributesFrom:_tempBasicInfo];
        }
    } else {                                                //Edit an existed basicInfo
        //If barcode changed and doest not exist in DB, we have to create a new one
        if([_tempBasicInfo.barcodeData length] > 0) {
            //The _tempBasicInfo have a barcode, otherwise _candidateBasicInfo will not be nil
            //The barcode may be the same as origianl one, or a new one.
            if([_tempBasicInfo.barcodeData isEqualToString:_initBasicInfo.barcodeData]) {
                if(_initItem.basicInfo == nil) {
                    _initItem.basicInfo = _initBasicInfo;
                }
                [_initItem.basicInfo copyAttributesFrom:_tempBasicInfo];
            } else {
                [[CoreDataDatabase mainMOC] insertObject:_tempBasicInfo];
                _initItem.basicInfo = _tempBasicInfo;
            }
        } else {
            if([_initItem.basicInfo.barcodeData length] > 0) {
                //User may remove the barcode data of an existed basicInfo,
                //so we create a new one because we don't want to delete existed barcode information
                [[CoreDataDatabase mainMOC] insertObject:_tempBasicInfo];
                _initItem.basicInfo = _tempBasicInfo;
            } else {
                //User may change or remove the name or image of an existed basicInfo
                if(_initItem.basicInfo == nil) {
                    _initItem.basicInfo = _initBasicInfo;
                }
                [_initItem.basicInfo copyAttributesFrom:_tempBasicInfo];
            }
        }
    }
    
    if([_initFolder.objectID isTemporaryID]) {
        //The new folder must be saved before saving item
        //a.k.a, call [EditFolderViewController saveFolderToDatabase] first!
        [[CoreDataDatabase mainMOC] refreshObject:_initFolder mergeChanges:YES];
    }
    _initItem.folder = _initFolder;
    
    if(!_isNewItem) {
        //User edit an existed item
        //1. Copy edited data
        DBFolderItem *originItemData = [CoreDataDatabase obtainTempFolderItem];
        [originItemData copyAttributesFrom:_initItem];
        [_initItem copyAttributesFrom:_tempItem];
        
        //2. Add changeLog
        [self _addChangeLog:[_initItem changedValues] oldItem:originItemData];
    }
    
    if([[_initItem changedValues] count] == 0 &&
       [[_initItem.basicInfo changedValues] count] == 0)
    {
        [CoreDataDatabase cancelUnsavedChanges];
        return YES;
    }
    
    _initItem.lastUpdateTime = [[NSDate date] timeIntervalSinceReferenceDate];
    _initItem.isUserCreated = YES;
    
    if([CoreDataDatabase commitChanges:nil]) {
        //User may continue to edit again
        isExpiredBeforeEditing = [_initItem isExpired];
        isNearExpiredBeforeEditing = [_initItem isNearExpired];
        _changeLogs = [_initItem localizedChangeLogs];
        
        //Call for updating the item after back to list
        [self.delegate finishEditItem:self]; //Must be called before popping view controller
        return YES;
    } else {
        [CoreDataDatabase cancelUnsavedChanges];
    }
    
    return NO;
}

- (void)dismissKeyboard
{
    [self.nameField resignFirstResponder];
    [self.barcodeField resignFirstResponder];
    [self.countField resignFirstResponder];
    [noteView resignFirstResponder];
}
//--------------------------------------------------------------
//  [END] Instance Methods
//==============================================================

//==============================================================
//  [BEGIN] UIAlertViewDelegate Methods
#pragma mark -
#pragma mark UIAlertViewDelegate Methods
//--------------------------------------------------------------
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
}
//--------------------------------------------------------------
//  [END] UIAlertViewDelegate Methods
//==============================================================

//==============================================================
//  [BEGIN] PickDateViewControllerDelegate Method
#pragma mark -
#pragma mark PickDateViewControllerDelegate Method
//--------------------------------------------------------------
- (void)finishPickingDate:(NSDate *)date
{
    if(selectedIndex.row == kExpireDateRowIndex) {
        NSTimeInterval time = [date timeIntervalSinceReferenceDate];
        if(time > 0) {
            _expireDate = [CoreDataDatabase getNotifyDateOfDate:date];
            if(_expireDate == nil) {
                _expireDate = [CoreDataDatabase obtainTempNotifyDate];
                _expireDate.date = time;
            }
            
            if([self.table numberOfRowsInSection:kDateSectionIndex] == 2) {
                [self.table beginUpdates];
                [self.table insertRowsAtIndexPaths:[NSArray arrayWithObject:
                                                    [NSIndexPath indexPathForRow:kExpireAlertRowIndex
                                                                       inSection:kDateSectionIndex]]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
                [self.table endUpdates];
            }
        } else {
            if([self.table numberOfRowsInSection:kDateSectionIndex] == 3) {
                [self.table beginUpdates];
                _expireDate = nil;
                
                [self.table deleteRowsAtIndexPaths:[NSArray arrayWithObject:
                                                    [NSIndexPath indexPathForRow:kExpireAlertRowIndex
                                                                       inSection:kDateSectionIndex]]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
                [self.table endUpdates];
            }
        }
    } else {
        _tempItem.createTime = [date timeIntervalSinceReferenceDate];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)cancelPickingDate
{
    [self.navigationController popViewControllerAnimated:YES];
}
//--------------------------------------------------------------
//  [END] PickDateViewControllerDelegate Method
//==============================================================

//==============================================================
//  [BEGIN] EnterPriceViewController Method
#pragma mark -
#pragma mark EnterPriceViewController Method
//--------------------------------------------------------------
- (void)finishEnteringPrice:(double)price
{
    _tempItem.price = price;
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)cancelEnteringPrice
{
    [self.navigationController popViewControllerAnimated:YES];
}
//--------------------------------------------------------------
//  [END] EnterPriceViewController Method
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
    [_tempBasicInfo setUIImage:nil];
    self.editImageView.image = nil;
    _previewImageView.image = nil;
    
    if(_candidateBasicInfo != nil ||
       [_tempBasicInfo canSave])
    {
        self.navigationItem.rightBarButtonItem.enabled = YES;
    } else {
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
    
    [self.saveStateDelegate canSaveItem:self.navigationItem.rightBarButtonItem.enabled];
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
    [self.saveStateDelegate canSaveItem:self.navigationItem.rightBarButtonItem.enabled];
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

        self.editImageView.image = _tempBasicInfo.displayImage;
        
        self.navigationItem.rightBarButtonItem.enabled = YES;
        [self.saveStateDelegate canSaveItem:self.navigationItem.rightBarButtonItem.enabled];
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
//  [BEGIN] PickLocationViewControllerDelegate
#pragma mark - PickLocationViewControllerDelegate
//--------------------------------------------------------------
- (void)pickLocation:(DBLocation *)location
{
    //We cannot assign location to _tempItem since they are in different context now
    _pickedLocation = location;
    [self _updateLocaltionLabel];
    [self.navigationController popViewControllerAnimated:YES];
}
//--------------------------------------------------------------
//  [END] PickLocationViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] Private Methods
#pragma mark -
#pragma mark Private Methods
//--------------------------------------------------------------

//==============================================================
//  [BEGIN] Update UI with item data
#pragma mark -
#pragma mark Update UI with item data
//--------------------------------------------------------------

- (void)_syncDataToUI
{
    //Update imageView
//    [self _updateImageView];
    self.editImageView.image = [_tempBasicInfo getDisplayImage];
//    [self _updateNameLabel];
    self.nameCell.textLabel.text = _tempBasicInfo.name;
//    [self _updateBarcodeLabel];
    self.nameCell.detailTextLabel.text = [StringUtil formatBarcode:_tempBasicInfo.barcode];
    
    [self _updateCountLabel];
    [self _updateCreateDateLabel];
    [self _updateExpireDateLabel];
    [self _updatePriceLabel];
    [self _updateLocaltionLabel];
}

- (void)_updateBarcodeField
{
    if(_candidateBasicInfo) {
        self.barcodeField.text = [StringUtil formatBarcode:_candidateBasicInfo.barcode];
    } else {
        self.barcodeField.text = [StringUtil formatBarcode:_tempBasicInfo.barcode];
    }
}

- (void)_updateCountLabel
{
    self.countCell.detailTextLabel.text = [NSString stringWithFormat:@"%d", _tempItem.count];
}

- (void)_updatePriceLabel
{
    if(_tempItem.price > 0) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterCurrencyStyle;
        formatter.minimumFractionDigits = 0;
        self.priceCell.detailTextLabel.text = [formatter stringFromNumber:[NSNumber numberWithDouble:_tempItem.price]];
    } else {
        self.priceCell.detailTextLabel.text = nil;
    }

    [self.priceCell layoutSubviews];
}

- (void)_updateLocaltionLabel
{
    self.locationCell.detailTextLabel.text = _pickedLocation.name;
}

- (void)_updateNoteView
{
    CGRect frame = noteView.frame;
    CGFloat heightDiff = frame.size.height;
    
    const CGFloat MIN_TEXTVIEW_HEIGHT = self.table.rowHeight - 2*kTextViewVerticalSpace;
    noteView.scrollEnabled = NO;
    
    if([noteView.text length] == 0) {
        frame.size.height = MIN_TEXTVIEW_HEIGHT;
    } else {
        frame.size.height = noteView.contentSize.height - 2*kTextViewInset;
        
        if(UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
            const int MAX_TEXT_HEIGHT = kMaxTextViewHeightPortrait - [[UIApplication sharedApplication] statusBarFrame].size.height;
            if(frame.size.height > MAX_TEXT_HEIGHT) {
                frame.size.height = MAX_TEXT_HEIGHT;
                noteView.scrollEnabled = YES;
            }
        } else {
            const int MAX_TEXT_HEIGHT = kMaxTextViewHeightLandscape - [[UIApplication sharedApplication] statusBarFrame].size.height;
            if(frame.size.height > MAX_TEXT_HEIGHT) {
                frame.size.height = MAX_TEXT_HEIGHT;
                noteView.scrollEnabled = YES;
            }
        }
        
        if(frame.size.height < MIN_TEXTVIEW_HEIGHT) {
            frame.size.height = MIN_TEXTVIEW_HEIGHT; 
        }
    }

    heightDiff = frame.size.height - heightDiff;
    
    //3. Adjust noteCell size
    if(heightDiff != 0.0) {
        noteView.frame = frame;
        if(!noteView.scrollEnabled) {
            [noteView setContentOffset:CGPointMake(0, kTextViewInset) animated:YES];
        }

        frame = self.noteCell.frame;
        frame.size.height += heightDiff;
        
        void(^setNoteCellFrameBlock)() = ^{
            self.noteCell.frame = frame;
        };

        //Only animate when changed by user input
        if([noteView isFirstResponder]) {
            [UIView animateWithDuration:0.3
                             animations:setNoteCellFrameBlock];
        } else {
            setNoteCellFrameBlock();
        }

        [self.table beginUpdates];
        self.table.contentSize = CGSizeMake(self.table.contentSize.width, self.table.contentSize.height+heightDiff);
        [self.table endUpdates];
    }
}

- (void)_updateCreateDateLabel
{
    if(_tempItem.createTime <= 0) {
        _tempItem.createTime = [[TimeUtil today] timeIntervalSinceReferenceDate];
    }

    self.createDateCell.detailTextLabel.text = [TimeUtil dateToStringInCurrentLocale:
                                                [NSDate dateWithTimeIntervalSinceReferenceDate:_tempItem.createTime]
                                                                           dateStyle:NSDateFormatterLongStyle];
    [self.createDateCell layoutSubviews];
}

- (void)_updateExpireDateLabel
{
    if(_expireDate == nil) {
        self.expiryDateCell.detailTextLabel.text = nil;
        self.alertDaysCell.detailTextLabel.text = nil;  //should be hidden
    } else {
        self.expiryDateCell.detailTextLabel.text = [TimeUtil dateToStringInCurrentLocale:
                                                    [NSDate dateWithTimeIntervalSinceReferenceDate:_expireDate.date]
                                                                               dateStyle:NSDateFormatterLongStyle];

        if([TimeUtil isExpired:[NSDate dateWithTimeIntervalSinceReferenceDate:_expireDate.date]]) {
            self.expiryDateCell.detailTextLabel.textColor = kColorExpiredTextColor;
        } else {
            [self _sortNearExpiredDays];
            NSDate *earliestDate = [TimeUtil dateFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:_expireDate.date]
                                                   inDays:-[[_nearExpiredDays lastObject] intValue]];
            if([earliestDate compare:[TimeUtil today]] != NSOrderedDescending) {
                self.expiryDateCell.detailTextLabel.textColor = kColorNearExpiredTextColor;
            } else {
                self.expiryDateCell.detailTextLabel.textColor = [UIColor darkTextColor];
            }
        }
        
        self.alertDaysCell.detailTextLabel.text = [self _formatNearExpiredDays];
    }

    [self.expiryDateCell layoutSubviews];
    [self.alertDaysCell layoutSubviews];
}
//--------------------------------------------------------------
//  [END] Update UI with item data
//==============================================================

//==============================================================
//  [BEGIN] Update item data with UI content
#pragma mark -
#pragma mark Update item data with UI content
//--------------------------------------------------------------
- (void)_updateNameData
{
    if([self.nameField.text length] > 0) {
        _tempBasicInfo.name = self.nameField.text;
    } else {
        _tempBasicInfo.name = nil;
    }
}
//--------------------------------------------------------------
//  [END] Update item data with UI content
//==============================================================
- (void)_enterEditMode
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Enter item edit mode"];
    }

    offsetBeforeEditing = self.table.contentOffset.y;
    [self _toggleEditMode:YES animated:YES];
}

- (void)_toggleEditMode:(BOOL)editing animated:(BOOL)animate
{
    isEditing = editing;

    static const float kAnimateionDuration = 0.3;

    if(self.canEditBasicInfo) {
        [self.editImageView setEditing:editing animated:animate duration:kAnimateionDuration];
    }

    if(editing) {
        [_tempBasicInfo copyAttributesFrom:_initBasicInfo];
        [_tempItem copyAttributesFrom:_initItem];
        
//        noteView.editable = YES;  //this will cause table to scroll down in Edit mode

        if(_initFolder != nil &&
           ![_initFolder.objectID isTemporaryID])
        {
            UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                       target:self
                                                                                       action:@selector(cancelEditing:)];
            self.navigationItem.leftBarButtonItem = barButton;
            
            UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                        target:self
                                                                                        action:@selector(saveItem:)];
            self.navigationItem.rightBarButtonItem = saveButton;
        }

        //Init Name and Barcode editing table
        if(!self.canEditBasicInfo) {
            //Fix bug: user presses + button to add an item but the image cannot enlarge
            if(_imageTapGR.view != self.editImageView) {
                [self.editImageView addGestureRecognizer:_imageTapGR];
            }
        } else {
            [self.editImageView removeGestureRecognizer:_imageTapGR];
            
            CGFloat tableHeight = fEditCellHeight*2;
            CGFloat tablePosY = 0;
            if(tableHeight < kImageHeight) {
                tablePosY = (kImageHeight - fEditCellHeight)/2;
            }
            
            if(editNameTable == nil) {
                editNameTable = [[UITableView alloc] initWithFrame:CGRectMake(kImageWidth+kImageTableSapce, tablePosY,
                                                                              kEditTableWidth, tableHeight)];
                editNameTable.delegate = self;
                editNameTable.dataSource = self;
                
                editNameTable.layer.cornerRadius = 10;
                editNameTable.layer.borderWidth = 1;
                editNameTable.layer.borderColor = [UIColor lightGrayColor].CGColor;
            }
            
            //Init name field
            if(self.nameField == nil) {
                self.nameField = [[UITextField alloc] initWithFrame:CGRectMake(kEditCellHorizontalSpace, kEditCellVerticalSpace, kEditTableWidth-kEditCellHorizontalSpace, fEditCellHeight)];
                self.nameField.font = editFieldFont;
                self.nameField.placeholder = NSLocalizedString(@"Name", nil);
                self.nameField.delegate = self;
                self.nameField.returnKeyType = UIReturnKeyDone;
            }
            self.nameField.text = _tempBasicInfo.name;
            
            //Init Barcode field
            if(self.barcodeField == nil) {
                self.barcodeField = [[UITextField alloc] initWithFrame:CGRectMake(kEditCellHorizontalSpace, 0, kEditTableWidth-kEditCellHorizontalSpace, fEditCellHeight)];
                self.barcodeField.font = editFieldFont;
                self.barcodeField.placeholder = NSLocalizedString(@"Barcode", nil);
                self.barcodeField.keyboardType = UIKeyboardTypeNumberPad;
                self.barcodeField.clearButtonMode = UITextFieldViewModeAlways;
                self.barcodeField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
                self.barcodeField.delegate = self;
            }
        }

        //Init count field
        self.countField.text = [NSString stringWithFormat:@"%d", _tempItem.count];

        if(animate) {
            //Animate Name and Barcode table
            if(self.canEditBasicInfo) {
                editNameTable.alpha = 0;
                [self.nameCell.contentView addSubview:editNameTable];
                [UIView animateWithDuration:kAnimateionDuration animations:^{
                    self.nameCell.textLabel.alpha = 0;
                    self.nameCell.detailTextLabel.alpha = 0;
                    
                    editNameTable.alpha = 1.0;
                } completion:^(BOOL finished) {
                    self.nameCell.textLabel.hidden = YES;
                    self.nameCell.detailTextLabel.hidden = YES;
                }];
            }

            //Animate count editing view
            self.countCell.detailTextLabel.alpha = 0.5;
            self.countEditView.alpha = 0;
            self.countEditView.hidden = NO;
            self.countEditView.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(0.01, 1),
                                                                   CGAffineTransformMakeTranslation(-self.countEditView.frame.size.width/2, 0));
            [UIView animateWithDuration:kAnimateionDuration animations:^{
                self.countEditView.transform = CGAffineTransformIdentity;
                self.countCell.detailTextLabel.alpha = 0;
                self.countEditView.alpha = 1.0;
            } completion:^(BOOL finished) {
                self.countCell.detailTextLabel.hidden = YES;
            }];
        } else {
            if(self.canEditBasicInfo) {
                [self.nameCell.contentView addSubview:editNameTable];
                self.nameCell.textLabel.hidden = YES;
                self.nameCell.detailTextLabel.hidden = YES;
            }
            
            self.countCell.detailTextLabel.hidden = YES;
            self.countEditView.hidden = NO;
        }
        
        self.priceCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.priceCell.selectionStyle = UITableViewCellSelectionStyleBlue;
        self.createDateCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.createDateCell.selectionStyle = UITableViewCellSelectionStyleBlue;
        self.expiryDateCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.expiryDateCell.selectionStyle = UITableViewCellSelectionStyleBlue;
        self.alertDaysCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.alertDaysCell.selectionStyle = UITableViewCellSelectionStyleBlue;
        self.locationCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.locationCell.selectionStyle = UITableViewCellSelectionStyleBlue;
        
        noteView.textColor = [UIColor blackColor];
        
        [self _updateExpireDateLabel];
        [self _syncDataToUI];
    } else {
//        noteView.editable = NO;   //this will cause table to scroll down in Edit mode
        if(_imageTapGR.view != self.editImageView) {
            [self.editImageView addGestureRecognizer:_imageTapGR];
        }

        self.navigationItem.rightBarButtonItem = editButton;
        self.navigationItem.leftBarButtonItem = nil;
        
        [self _syncDataToUI];
        
        if(animate) {
            //Animate Name and Barcode table
            self.nameCell.textLabel.hidden = NO;
            self.nameCell.detailTextLabel.hidden = NO;
            [UIView animateWithDuration:kAnimateionDuration animations:^{
                self.nameCell.textLabel.alpha = 1.0;
                self.nameCell.detailTextLabel.alpha = 1.0;

                editNameTable.alpha = 0;
            } completion:^(BOOL finished) {
                [editNameTable removeFromSuperview];
            }];
            
            //Animate count editing view
            self.countCell.detailTextLabel.hidden = NO;
            [UIView animateWithDuration:kAnimateionDuration animations:^{
                self.countCell.detailTextLabel.alpha = 1.0;
                self.countEditView.alpha = 0;
                self.countEditView.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(0.01, 1),
                                                                       CGAffineTransformMakeTranslation(-self.countEditView.frame.size.width/2, 0));
            } completion:^(BOOL finished) {
                self.countEditView.transform = CGAffineTransformIdentity;
            }];
        } else {
            self.nameField = nil;
            self.barcodeField = nil;
            [editNameTable removeFromSuperview];
            self.nameCell.textLabel.hidden = NO;
            self.nameCell.detailTextLabel.hidden = NO;

            self.countEditView.hidden = YES;
            self.countCell.detailTextLabel.hidden = NO;
        }
        
        self.priceCell.selectionStyle = UITableViewCellSelectionStyleNone;
        self.priceCell.accessoryType = UITableViewCellAccessoryNone;
        self.createDateCell.selectionStyle = UITableViewCellSelectionStyleNone;
        self.createDateCell.accessoryType = UITableViewCellAccessoryNone;
        self.expiryDateCell.selectionStyle = UITableViewCellSelectionStyleNone;
        self.expiryDateCell.accessoryType = UITableViewCellAccessoryNone;
        self.alertDaysCell.selectionStyle = UITableViewCellSelectionStyleNone;
        self.alertDaysCell.accessoryType = UITableViewCellAccessoryNone;
        self.locationCell.selectionStyle = UITableViewCellSelectionStyleNone;
        self.locationCell.accessoryType = UITableViewCellAccessoryNone;
        
        noteView.textColor = [UIColor darkGrayColor];
    }

    [self.table reloadData];
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

- (NSString *)_formatNearExpiredDays
{
    const int NEAR_EXPIRE_COUNT = [_nearExpiredDays count];
    if(NEAR_EXPIRE_COUNT == 0) {
        return NSLocalizedString(@"None", nil);
    }

    [self _sortNearExpiredDays];

    NSMutableString *alertDayString = [NSMutableString string];
    //1. 1 day before
    //2. i days before
    //3. j and k days before
    //4, i, j and k days before
    for(int nIndex = 0; nIndex < NEAR_EXPIRE_COUNT; nIndex++) {
        [alertDayString appendString:[NSString stringWithFormat:@"%d", [[_nearExpiredDays objectAtIndex:nIndex] intValue]]];

        if(nIndex < NEAR_EXPIRE_COUNT-2) {
            [alertDayString appendString:@", "];
        } else if(nIndex == NEAR_EXPIRE_COUNT-2) {
            [alertDayString appendString:NSLocalizedString(@" and ", @"Used for near-expired alert days when view/edit an item")];
        }
    }
    
    if([_nearExpiredDays count] == 1 &&
       [[_nearExpiredDays objectAtIndex:0] intValue] <= 1)
    {
        [alertDayString appendString:NSLocalizedString(@" day before", @"Used for near-expired alert days when view/edit an item")];
    } else {
        [alertDayString appendString:NSLocalizedString(@" days before", @"Used for near-expired alert days when view/edit an item")];
    }
    
    return alertDayString;
}

- (void)_initNearExpiredDaysFromItem:(DBFolderItem *)item
{
    _nearExpiredDays = [NSMutableArray array];
    uint day;
    for(DBNotifyDate *nearExpireDate in item.nearExpiryDates) {
        day = [TimeUtil daysBetweenDate:[NSDate dateWithTimeIntervalSinceReferenceDate:nearExpireDate.date]
                                andDate:[NSDate dateWithTimeIntervalSinceReferenceDate:item.expiryDate.date]];
        [_nearExpiredDays addObject:[NSNumber numberWithUnsignedInt:day]];
    }
    
    [self _sortNearExpiredDays];
}

- (void)_sortNearExpiredDays
{
    [_nearExpiredDays sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSNumber *num1 = (NSNumber *)obj1;
        NSNumber *num2 = (NSNumber *)obj2;
        
        return [num1 compare:num2];
    }];
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
        
        self.nameField.text = _candidateBasicInfo.name;
        _tempBasicInfo.name = _candidateBasicInfo.name;

        self.editImageView.image = [_candidateBasicInfo getDisplayImage];
        [_tempBasicInfo setUIImage:self.editImageView.image];
    }
}

- (void)_addChangeLog:(NSDictionary *)changes oldItem:(DBFolderItem *)item
{
    //When expiryDate has been removed, alert dates will also be removed automatically.
    //But we'll just record the remove of expiryDate.
    BOOL expiryDateRemoved = NO;
    if([changes valueForKey:kAttrExpiryDate] &&
       _initItem.expiryDate == nil)
    {
        expiryDateRemoved = YES;
    }
    
    for(NSString *key in [changes allKeys]) {
        if([key isEqualToString:kAttrCount]) {
            [_initItem addCountChangeLogFromOldCount:item.count];
        } else if([key isEqualToString:kAttrCreateTime]) {
            [_initItem addCreateDateChangeLog];
        } else if([key isEqualToString:kAttrExpiryDate]) {
            [_initItem addExpiryDateChangeLog];
        } else if([key isEqualToString:kAttrNearExpiryDates]) {
            if(!expiryDateRemoved) {
                [_initItem addNearExpiryDaysChangeLog];
            }
        } else if([key isEqualToString:kAttrPrice]) {
            [_initItem addPriceChangeLog];
        } else if([key isEqualToString:kAttrLocation]) {
            [_initItem addLocationChangeLog];
        } else if([key isEqualToString:kAttrNote]) {
            [_initItem addNoteChangeLog];
        }
    }
}
//--------------------------------------------------------------
//  [END] Private Methods
//==============================================================

//==============================================================
//  [BEGIN] SetExpirePeriodViewControllerDelegate
#pragma mark - SetExpirePeriodViewControllerDelegate
//--------------------------------------------------------------
- (void)addNearExpiredDay:(NSNumber *)day
{
    if(![_nearExpiredDays containsObject:day]) {
        [_nearExpiredDays addObject:day];
    }
    
    [self _sortNearExpiredDays];
}

- (void)removeNearExpiredDay:(NSNumber *)day
{
    [_nearExpiredDays removeObject:day];
    [self _sortNearExpiredDays];
}
//--------------------------------------------------------------
//  [END] SetExpirePeriodViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] Notification receivers
#pragma mark -
#pragma mark Notification receivers
//--------------------------------------------------------------
- (void)_receiveManagedObjectContextDidSaveNotification:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    DBFolderItem *folderItem = nil;
    DBItemBasicInfo *basicInfo = nil;
    
    NSSet *deletedObjects = [userInfo objectForKey:NSDeletedObjectsKey];
    for(NSManagedObject *object in deletedObjects) {
        if(object.managedObjectContext == nil ||
           [object.objectID isTemporaryID])
        {
            continue;
        }
        
        if([object class] == [DBFolderItem class]) {
            folderItem = (DBFolderItem *)object;
            if([_initItem.objectID.URIRepresentation isEqual:folderItem.objectID.URIRepresentation]) {
                //TODO: show warning about item deletion
            }
        } else if([object class] != [DBItemBasicInfo class]) {
            basicInfo = (DBItemBasicInfo *)object;
            if([_initBasicInfo.objectID.URIRepresentation isEqual:basicInfo.objectID.URIRepresentation]) {
                //TODO: show warning about item deletion
            }
        }
    }
    
    NSSet *updatedObjects = [userInfo objectForKey:NSUpdatedObjectsKey];
    
    for(NSManagedObject *object in updatedObjects) {
        if(object.managedObjectContext == nil ||
           [object.objectID isTemporaryID])
        {
            continue;
        }
        
        if([object class] == [DBFolderItem class]) {            //update statistics
            folderItem = (DBFolderItem *)object;
            basicInfo = folderItem.basicInfo;
            
            if([_initItem.objectID.URIRepresentation isEqual:folderItem.objectID.URIRepresentation]) {
                //TODO: update UI and data
            }
        } else if([object class] != [DBItemBasicInfo class]) {  //update basic info
            basicInfo = (DBItemBasicInfo *)object;
            if([_initBasicInfo.objectID.URIRepresentation isEqual:basicInfo.objectID.URIRepresentation]) {
                //TODO: update UI and data
            }
        }
    }
}
//--------------------------------------------------------------
//  [END] Notification receivers
//==============================================================

@end
