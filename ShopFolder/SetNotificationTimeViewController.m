//
//  SetNotificationTimeViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/11/24.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "SetNotificationTimeViewController.h"
#import "PreferenceConstant.h"
#import "NotificationConstant.h"
#import "TimeUtil.h"

@implementation SetNotificationTimeViewController
@synthesize label1;
@synthesize label2;
@synthesize timePicker;
@synthesize delegate;

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.label1 = nil;
    self.label2 = nil;
    self.timePicker = nil;
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
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
    self.label1.text = NSLocalizedString(@"Select time to show expiry notification", nil);
    //TODO: show descrition according to hardware and iOS version
    self.label2.text = NSLocalizedString(@"For more notification settings,\nplease refer to Notification\n in Settings app.", nil);
    
    initHour = [[NSUserDefaults standardUserDefaults] integerForKey:kSettingDailyNotifyHour];
    initMinute = [[NSUserDefaults standardUserDefaults] integerForKey:kSettingDailyNotifyMinute];
    
    [timePicker setDate:[TimeUtil timeInDate:[NSDate date] hour:initHour minute:initMinute second:0]];
}

- (void)viewWillDisappear:(BOOL)animated
{
    int hh = [[NSUserDefaults standardUserDefaults] integerForKey:kSettingDailyNotifyHour];
    int mm = [[NSUserDefaults standardUserDefaults] integerForKey:kSettingDailyNotifyMinute];
    if(initHour != hh || initMinute != mm) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kExpirePreferenceChangeNotification object:nil userInfo:nil];
    }
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)timePicked:(UIDatePicker *)picker
{
    NSDate *date = picker.date;
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(kCFCalendarUnitHour | kCFCalendarUnitMinute) fromDate:date];
    NSInteger hh = [components hour];
    NSInteger mm = [components minute];
    
    [[NSUserDefaults standardUserDefaults] setInteger:hh forKey:kSettingDailyNotifyHour];
    [[NSUserDefaults standardUserDefaults] setInteger:mm forKey:kSettingDailyNotifyMinute];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [self.delegate setNotificationHour:hh minute:mm];
}

@end
