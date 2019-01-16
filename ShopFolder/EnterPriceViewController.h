//
//  EnterPriceViewController.h
//  ShopFolder
//
//  Created by Michael on 2011/10/18.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kMaximumFractionDigits 2

@protocol EnterPriceViewControllerDelegate;

@interface EnterPriceViewController : UIViewController <UITextFieldDelegate>
{
    UITextField *priceField;
    UIButton *button_9;
    UIButton *button_49;
    UIButton *button_99;

    double price;
    NSNumberFormatter *currencyFormatter;
}

@property (nonatomic, strong) IBOutlet UITextField *priceField;
@property (nonatomic, strong) IBOutlet UIButton *button_9;
@property (nonatomic, strong) IBOutlet UIButton *button_49;
@property (nonatomic, strong) IBOutlet UIButton *button_99;
@property (nonatomic, weak) id<EnterPriceViewControllerDelegate> delegate;

- (id)initWithPrice: (double)price;
- (IBAction)pressDot:(id)sender;
- (IBAction)fastAddFloat: (id)sender;
- (IBAction)savePrice:(id)sender;
- (IBAction)cancelEditing:(id)sender;
@end


@protocol EnterPriceViewControllerDelegate
- (void)finishEnteringPrice: (double)price;
- (void)cancelEnteringPrice;
@end