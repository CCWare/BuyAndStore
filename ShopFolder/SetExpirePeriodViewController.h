//
//  SetExpirePeriodViewController.h
//  ShopFolder
//
//  Created by Michael on 2011/11/24.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kMaxNearExpiredDayCount     3

@protocol SetExpirePeriodViewControllerDelegate;

@interface SetExpirePeriodViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
{
    UITableView *table;
    int initValue;
    UITableViewCell *lastCell;
    UITableViewCell *currentCell;
    
    NSMutableArray *selectedDays;
}

@property (nonatomic, strong) IBOutlet UITableView *table;
@property (nonatomic, strong) IBOutlet UIToolbar *toolbar;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *toolbarHint;
@property (nonatomic, weak) id<SetExpirePeriodViewControllerDelegate> delegate;

- (id)initForSelectMultipleDays:(NSMutableArray *)initDays;
@end

@protocol SetExpirePeriodViewControllerDelegate
@optional
//Called when init
- (void)setExpirePeriod:(int)days;

//Called when initForSelectMultipleDays
- (void)addNearExpiredDay:(NSNumber *)day;
- (void)removeNearExpiredDay:(NSNumber *)day;
@end
