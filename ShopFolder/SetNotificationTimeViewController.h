//
//  SetNotificationTimeViewController.h
//  ShopFolder
//
//  Created by Michael on 2011/11/24.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SetNotificationTimeViewControllerDelegate;

@interface SetNotificationTimeViewController : UIViewController
{
    UILabel *label1;
    UILabel *label2;
    UIDatePicker *timePicker;
    
    int initHour;
    int initMinute;
}

@property (nonatomic, strong) IBOutlet UILabel *label1;
@property (nonatomic, strong) IBOutlet UILabel *label2;
@property (nonatomic, strong) IBOutlet UIDatePicker *timePicker;
@property (nonatomic, weak) id<SetNotificationTimeViewControllerDelegate> delegate;

- (IBAction)timePicked:(UIDatePicker *)picker;
@end

@protocol SetNotificationTimeViewControllerDelegate
- (void)setNotificationHour:(int)hh minute:(int)mm;
@end
