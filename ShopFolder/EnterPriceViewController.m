//
//  EnterPriceViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/10/18.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "EnterPriceViewController.h"
#import "VersionCompare.h"
#import "FlurryAnalytics.h"
#import "PreferenceConstant.h"

@interface EnterPriceViewController (PriovateMethods)
- (BOOL) _isValidPrice:(NSString *)string;
@end

@implementation EnterPriceViewController
@synthesize priceField;
@synthesize button_9;
@synthesize button_49;
@synthesize button_99;
@synthesize delegate;

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.priceField = nil;
    self.button_9 = nil;
    self.button_49 = nil;
    self.button_99 = nil;
}


- (id)initWithPrice: (double)inPrice
{
    if((self = [super initWithNibName:nil bundle:nil])) {
        price = inPrice;
        
        currencyFormatter = [[NSNumberFormatter alloc] init];
        currencyFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
        currencyFormatter.generatesDecimalNumbers = YES;
        currencyFormatter.minimumFractionDigits = 0;
    }
    
    return self;
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
    self.priceField.placeholder = NSLocalizedString(@"Please enter price", nil);
    
    UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                               target:self
                                                                               action:@selector(savePrice:)];
    self.navigationItem.rightBarButtonItem = barButton;
    
    barButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                              target:self
                                                              action:@selector(cancelEditing:)];
    self.navigationItem.leftBarButtonItem = barButton;
    
    if(currencyFormatter.maximumFractionDigits < 2) {
        self.button_49.hidden = YES;
        self.button_99.hidden = YES;
        
        if(currencyFormatter.maximumFractionDigits < 1) {
            self.button_9.hidden = YES;
        }
    }

    if(currencyFormatter.maximumFractionDigits > 0) {
        self.priceField.keyboardType = UIKeyboardTypeDecimalPad;
    }

    if(price != 0) {
        currencyFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        self.priceField.text = [currencyFormatter stringFromNumber:[NSNumber numberWithDouble:price]];
        currencyFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
    }
    
    self.view.backgroundColor = [[UIColor alloc] initWithPatternImage:
                                 [UIImage imageNamed:@"group_table_background"]];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.priceField becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)fastAddFloat: (id)sender
{
    NSString *buttonString = ((UIButton *)sender).titleLabel.text;
    NSString *newString = nil;
    NSRange range = [self.priceField.text rangeOfString:@"."];

    if(range.length == 0) {
        if([self.priceField.text length] == 0) {
            newString = [NSString stringWithFormat:@"0%@", buttonString];
        } else {
            newString = [self.priceField.text stringByAppendingString:buttonString];
        }
    } else {
        if(range.location > 0 && range.location < [self.priceField.text length]) {
            range.length = [self.priceField.text length] - range.location;
        }

        newString = [self.priceField.text stringByReplacingCharactersInRange:range withString:buttonString];
    }

    self.priceField.text = newString;
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Fast select price"
                   withParameters:[NSDictionary dictionaryWithObject:buttonString forKey:@"Price"]];
    }
}

- (IBAction)savePrice:(id)sender
{
    NSString *priceString = [currencyFormatter.currencyCode stringByAppendingString:self.priceField.text];
    price = [currencyFormatter numberFromString:priceString].doubleValue;
    [self.delegate finishEnteringPrice:price];
}

- (IBAction)cancelEditing:(id)sender
{
    price = 0;
    [self.delegate cancelEnteringPrice];
}

- (BOOL) _isValidPrice:(NSString *)string
{
    NSString *testString = [currencyFormatter.currencyCode stringByAppendingString:string];
    if([currencyFormatter numberFromString:testString]) {
        return YES;
    }
    
    return NO;
}

- (IBAction)pressDot:(id)sender
{
    NSString *candidate = [NSString stringWithFormat:@"%@.", self.priceField.text];
    if([self _isValidPrice:candidate]) {
        self.priceField.text = candidate;
    }
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if(price == 0) {
        textField.text = nil;
    } else {
        currencyFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        self.priceField.text = [currencyFormatter stringFromNumber:[NSNumber numberWithDouble:price]];
        currencyFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if(price == 0) {
        textField.text = nil;
    } else {
        textField.text = [currencyFormatter stringFromNumber:[NSNumber numberWithDouble:price]];
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *candidateString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if([candidateString length] == 0) {
        return YES;
    }

    NSRange existedDotRange = [textField.text rangeOfString:@"."];
    NSRange newDotRange = [string rangeOfString:@"."];
    if(existedDotRange.length > 0) {
        if(currencyFormatter.maximumFractionDigits == 0) {
            //No dot allowed
            return NO;
        }

        if(newDotRange.length > 0) {
            //Cannot be more than one dot
            return NO;
        }

        if([candidateString length] - existedDotRange.location > (currencyFormatter.maximumFractionDigits+1)) {
            //Exceed max factor digits
            return NO;
        }
    }
    
    if(newDotRange.length > 0 &&
       [candidateString length] - [candidateString rangeOfString:@"."].location > (currencyFormatter.maximumFractionDigits+1) )
    {
        //Fraction digits of candidate string exceeds max limit
        return NO;
    }

    NSString *stringWithoutSeperator = [candidateString stringByReplacingOccurrencesOfString:currencyFormatter.groupingSeparator withString:@""];
    if([self _isValidPrice:stringWithoutSeperator]) {
        //For adding seperators
        currencyFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        self.priceField.text = [currencyFormatter stringFromNumber:[NSNumber numberWithDouble:[stringWithoutSeperator doubleValue]]];
        currencyFormatter.numberStyle = NSNumberFormatterCurrencyStyle;

        if(newDotRange.length == 1) {  //Only appending dot
            newDotRange.location = range.location+newDotRange.location;
            if(newDotRange.location >= [self.priceField.text length]) {
                self.priceField.text = [self.priceField.text stringByAppendingString:@"."];
            }
        }
    }

    return NO;
//    return [self _isValidPrice:candidateString];
}
@end
