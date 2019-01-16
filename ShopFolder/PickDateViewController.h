//
//  PickDateViewController.h
//  ShopFolder
//
//  Created by Michael on 2011/10/17.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PickDateViewControllerDelegate;

@interface PickDateViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
{
    UITableView *table;
    UITableViewCell *datePreviewCell;
    UITableViewCell *fastPickDateCell;
    UIDatePicker *datePicker;
    
    NSString *cellName;
    NSDate *initDate;
    
    UIButton *selectButton;
    UITextField *dateField;
    
    NSDate *pickedDate;
    
    BOOL isColoredByExpiryDate;
    BOOL showQuickSelection;
    BOOL canClearDate;
}

@property (nonatomic, strong) IBOutlet UIDatePicker *datePicker;
@property (nonatomic, strong) IBOutlet UITableView *table;
@property (nonatomic, strong) UITableViewCell *datePreviewCell;
@property (nonatomic, strong) IBOutlet UITableViewCell *fastPickDateCell;
@property (nonatomic, strong) NSString *cellName;
@property (nonatomic, strong) NSDate *inDate;
@property (nonatomic, assign) BOOL isColoredByExpiryDate;
@property (nonatomic, assign) BOOL showQuickSelection;
@property (nonatomic, assign) BOOL canClearDate;
@property (nonatomic, weak) id <PickDateViewControllerDelegate> delegate;

- (id) initWithCellName: (NSString *)name andDate:(NSDate *)date;
- (IBAction) pickDate: (UIDatePicker *)picker;
- (IBAction) selectDateAfterToday: (UIButton *) sender;
@end

@protocol PickDateViewControllerDelegate
- (void)finishPickingDate: (NSDate *)date;
- (void)cancelPickingDate;
@end