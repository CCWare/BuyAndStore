//
//  SetExpirePeriodViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/11/24.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "SetExpirePeriodViewController.h"
#import "PreferenceConstant.h"
#import "NotificationConstant.h"

const int PERIOD_LIST[] = {1, 2, 3, 4, 5, 6, 7, 14, 30, 60, 90};

@implementation SetExpirePeriodViewController
@synthesize table;
@synthesize toolbar;
@synthesize toolbarHint;
@synthesize delegate;

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.table = nil;
    self.toolbar = nil;
    self.toolbarHint = nil;
}

- (id)initForSelectMultipleDays:(NSMutableArray *)initDays
{
    if((self = [super init])) {
        selectedDays = initDays;
        if(selectedDays == nil) {
            selectedDays = [NSMutableArray array];
        }
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
    if(selectedDays == nil) {
        initValue = [[NSUserDefaults standardUserDefaults] integerForKey:kSettingNearExpiredDays];
        self.toolbar.hidden = YES;
    } else {
        self.table.contentInset = UIEdgeInsetsMake(0, 0, self.toolbar.frame.size.height, 0);
        self.toolbarHint.title = [NSString stringWithFormat:NSLocalizedString(@"%d/%d used", nil),
                                  [selectedDays count], kMaxNearExpiredDayCount];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    NSIndexPath *selectedIndex = [self.table indexPathForSelectedRow];
    if(selectedIndex) {
        [self.table deselectRowAtIndexPath:selectedIndex animated:NO];
    }
    
    [super viewWillAppear:animated];
}

//- (void)viewWillDisappear:(BOOL)animated
//{
//    //It may cost time for Database query, so we only do this once
//    int currentValue = [[NSUserDefaults standardUserDefaults] integerForKey:kSettingNearExpiredDays];
//    if(currentValue != initValue) {
//        [[NSNotificationCenter defaultCenter] postNotificationName:kExpirePreferenceChangeNotification object:nil userInfo:nil];
//    }
//    [super viewWillDisappear:animated];
//}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

//==============================================================
//  [BEGIN] UITableViewDataSource
#pragma mark -
#pragma mark UITableViewDataSource Methods
//--------------------------------------------------------------
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return sizeof(PERIOD_LIST)/sizeof(int);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return NSLocalizedString(@"Notify near-expired before:", nil);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const CELL_IDENTIFICATION = @"SetExpirePeriodCell";
    UITableViewCell *cell = [self.table dequeueReusableCellWithIdentifier:CELL_IDENTIFICATION];
    if(cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CELL_IDENTIFICATION];
//        cell.textLabel.textAlignment = UITextAlignmentCenter;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    int nDays = PERIOD_LIST[indexPath.row];
    if(nDays == 1) {
        cell.textLabel.text = NSLocalizedString(@"1 day", nil);
    } else {
        cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%d days", nil), nDays];
    }

    if(selectedDays) {
        if([selectedDays containsObject:[NSNumber numberWithInt:nDays]]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else {
        if(nDays == initValue) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            currentCell = cell;
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
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    int nDays = PERIOD_LIST[indexPath.row];

    if(selectedDays) {
        NSNumber *day = [NSNumber numberWithInt:nDays];
        if([selectedDays containsObject:day]) {
            //Deselect the day
            UITableViewCell *cell = [self.table cellForRowAtIndexPath:indexPath];
            cell.accessoryType = UITableViewCellAccessoryNone;
            [selectedDays removeObject:day];
            
            [self.delegate removeNearExpiredDay:day];
        } else if([selectedDays count] < kMaxNearExpiredDayCount) {
            UITableViewCell *cell = [self.table cellForRowAtIndexPath:indexPath];
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            [selectedDays addObject:day];
            
            [self.delegate addNearExpiredDay:day];
        }
        
        self.toolbarHint.title = [NSString stringWithFormat:NSLocalizedString(@"%d/%d used", @"Used when picking near-expired days"),
                                  [selectedDays count], kMaxNearExpiredDayCount];
    } else {    //From Settings
        [[NSUserDefaults standardUserDefaults] setInteger:nDays forKey:kSettingNearExpiredDays];
        [[NSUserDefaults standardUserDefaults] synchronize];

        lastCell = currentCell;
        currentCell = [self.table cellForRowAtIndexPath: indexPath];
        
        if(lastCell != currentCell) {
            lastCell.accessoryType = UITableViewCellAccessoryNone;
            currentCell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        
        [self.delegate setExpirePeriod:nDays];
    }
}
//--------------------------------------------------------------
//  [END] UITableViewDelegate
//==============================================================

@end
