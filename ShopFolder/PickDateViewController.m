//
//  PickDateViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/10/17.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "PickDateViewController.h"
#import "TimeUtil.h"
#import "ColorConstant.h"
#import "PreferenceConstant.h"
#import "FlurryAnalytics.h"

@interface PickDateViewController ()
- (void) _updateTime: (NSDate *)date;
- (void) _updateColor:(NSDate *)date;
- (void) _leave: (id)sender;
- (void) _saveDate: (id)sender;

@property (nonatomic, strong) NSDate *pickedDate;
@end

@implementation PickDateViewController
@synthesize datePicker;
@synthesize table;
@synthesize datePreviewCell;
@synthesize fastPickDateCell;
@synthesize cellName;
@synthesize inDate;
@synthesize isColoredByExpiryDate;
@synthesize showQuickSelection;
@synthesize canClearDate;
@synthesize delegate;
@synthesize pickedDate;

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.datePicker = nil;
    self.datePreviewCell = nil;
    self.fastPickDateCell = nil;
    self.table = nil;
    dateField = nil;
}

- (id) initWithCellName:(NSString *)name andDate:(NSDate *)date
{
    if((self = [super initWithNibName:nil bundle:nil])) {
        self.cellName = name;
        self.inDate = date;
        self.pickedDate = self.inDate;
        
        self.isColoredByExpiryDate = YES;
        self.showQuickSelection = YES;
        self.canClearDate = YES;
    }
    
    return self;
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
    // Do any additional setup after loading the view from its nib.
    self.datePreviewCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2
                                                   reuseIdentifier:@"PickDateTable_PreviewIdentifier"];
    self.datePreviewCell.selectionStyle = UITableViewCellSelectionStyleNone;
    self.datePreviewCell.textLabel.text = self.cellName;
    
    //=== Add TextField to replace detailTextLabel for showing clear button ==
    [self.datePreviewCell layoutSubviews];  //Calculate width of preview field
    int nFieldPosX = self.datePreviewCell.textLabel.frame.size.width-8;
    UIFont* fieldFont = [UIFont boldSystemFontOfSize:15];
    dateField = [[UITextField alloc] initWithFrame:CGRectMake(nFieldPosX, 0, 300-nFieldPosX, 42)];
    dateField.font = fieldFont;
    dateField.borderStyle = UITextBorderStyleNone;
    if(canClearDate) {
        dateField.clearButtonMode = UITextFieldViewModeAlways;
    }
    dateField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    
    if([self.inDate timeIntervalSinceReferenceDate] > 0) {
        self.datePicker.date = self.inDate;
        [self _updateColor:self.inDate];
        dateField.text = [TimeUtil dateToStringInCurrentLocale:self.datePicker.date];
    }

    dateField.delegate = self;
    [self.datePreviewCell.contentView addSubview:dateField];
    //==========================================================================

    self.fastPickDateCell.selectionStyle = UITableViewCellSelectionStyleNone;
    self.fastPickDateCell.backgroundColor = [UIColor clearColor];    //Must set here, IB doesn't work for this
    self.fastPickDateCell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];  //remove grouped style border
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(_leave:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(_saveDate:)];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

//==============================================================
//  [BEGIN] UITextFieldDelegate Methods
#pragma mark -
#pragma mark UITextFieldDelegate Methods
//--------------------------------------------------------------
- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    if(canClearDate) {
        [textField resignFirstResponder];
        self.pickedDate = nil;
        
        if(selectButton) {
            selectButton.highlighted = NO;
            selectButton = nil;
        }

        return YES;
    }

    return NO;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    //Don't allow user to change date by typing
    return NO;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    //Prevent to paste from clipboard
    return NO;
}
//--------------------------------------------------------------
//  [END] UITextFieldDelegate Methods
//==============================================================

//==============================================================
//  [BEGIN] UITableViewDataSource
#pragma mark -
#pragma mark UITableViewDataSource Methods
//--------------------------------------------------------------

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if(!showQuickSelection) {
        return 1;
    }

    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if(section == 1) {
        return NSLocalizedString(@"Pick Days After Today", nil);
    }
    
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const CellTableIdentitifier = @"PickDateTable";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];

    switch(indexPath.section) {
        case 0:
            return self.datePreviewCell;
        case 1:
            return self.fastPickDateCell;
            break;
        default:
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
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if(section == 1) {
        return 22;
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == 1) {
        return self.fastPickDateCell.frame.size.height;
    }
    
    return tableView.rowHeight;
}
//--------------------------------------------------------------
//  [END] UITableViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] IBActions
#pragma mark -
#pragma mark IBActions
//--------------------------------------------------------------
- (IBAction) pickDate: (UIDatePicker *)picker
{
    NSDate *newDate = [picker date];
    newDate = [TimeUtil timeInDate:newDate hour:0 minute:0 second:0];
    
    if(selectButton) {
        selectButton.highlighted = NO;
        selectButton = nil;
    }

    [self _updateTime:newDate];
}

- (void) _keepButtonHighlighted
{
    selectButton.highlighted = YES;
}

- (IBAction) selectDateAfterToday: (UIButton *) sender
{
    if(selectButton &&
       selectButton != sender)
    {
        selectButton.highlighted = NO;
    }

    selectButton = sender;
    [self performSelector:@selector(_keepButtonHighlighted) withObject:nil afterDelay:0.0]; //Must do this for keeping hilighted

    int days = [sender.titleLabel.text intValue];
    NSDate *newDate = [TimeUtil dateFromToday:days];
    [self.datePicker setDate:newDate];
    [self _updateTime:newDate];
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Fast select date"
                   withParameters:[NSDictionary dictionaryWithObject:sender.titleLabel.text forKey:@"Day"]];
    }
}
//--------------------------------------------------------------
//  [END] IBActions
//==============================================================

//==============================================================
//  [BEGIN] Private Methods
#pragma mark -
#pragma mark Private Methods
//--------------------------------------------------------------
- (void) _updateTime: (NSDate *)date
{
    dateField.text = [TimeUtil dateToStringInCurrentLocale:date];
    [self _updateColor: date];
    [self.datePreviewCell layoutSubviews];
    
    self.pickedDate = date;
}

- (void) _updateColor:(NSDate *)date
{
    if(!self.isColoredByExpiryDate) {
        return;
    }

    if([TimeUtil isExpired:date]) {
        dateField.textColor = kColorExpiredTextColor;
    } else {
        dateField.textColor = [UIColor darkTextColor];
    }
}

- (void) _leave: (id)sender
{
    [self.delegate cancelPickingDate];
}

- (void) _saveDate: (id)sender
{
    if(self.inDate == nil ||      //No init date, any change is available even nil
       self.pickedDate == nil ||    //has been cleared
       [self.pickedDate compare:self.inDate] != NSOrderedSame)
    {
        [self.delegate finishPickingDate:self.pickedDate];
    } else {
        [self.delegate cancelPickingDate];
    }
}
//--------------------------------------------------------------
//  [END] Private Methods
//==============================================================
@end
