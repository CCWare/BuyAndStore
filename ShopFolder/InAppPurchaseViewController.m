//
//  InAppPurchaseViewController.m
//  ShopFolder
//
//  Created by Michael Tsai on 2012/03/21.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "InAppPurchaseViewController.h"
#import "PreferenceConstant.h"
#import "IAPCell.h"
#import <QuartzCore/QuartzCore.h>
#import "FlurryAnalytics.h"

//#define kIdentifierRemoveAD         @"tw.cctsai.buyrecordlite.remove_advertisement"
#define kIdentifierUnlimitCount     @"tw.cctsai.buyrecordlite.unlimit"

//#define kRestoreButtonSection  2
#define kRestoreButtonSection  1

@interface InAppPurchaseViewController ()
- (void)_showHUDWithLabel:(NSString *)label subLabel:(NSString *)subLabel animated:(BOOL)animate;
- (void)_hideHUDAnimated:(BOOL)animate;

//Transactions
- (void)_completeTransaction:(SKPaymentTransaction *)transaction;
- (void)_failedTransaction:(SKPaymentTransaction *)transaction;
- (void)_restoreTransaction:(SKPaymentTransaction *)transaction;

//Receipt validation
//- (BOOL)_verifyReceipt:(SKPaymentTransaction *)transaction;
//- (NSString *)_encode:(const uint8_t *)input length:(NSInteger)length;
@end

@implementation InAppPurchaseViewController
@synthesize delegate;
@synthesize table;
@synthesize navBar;
@synthesize doneButton;

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    m_request.delegate = nil;
    self.table = nil;
    self.navBar = nil;
    self.doneButton = nil;
    
    _hud.delegate = nil;
    [self _hideHUDAnimated:NO];
    _hud = nil;
    
    [_blockView removeFromSuperview];
    _blockView = nil;
    
    _buyingIndicator = nil;
    
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Enter IAP"];
        [FlurryAnalytics logPageView];
    }
}

- (void)dealloc
{
    m_request.delegate = nil;
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    navBar.title = NSLocalizedString(@"More Functions", @"Title of IAP view controller");

    // Do any additional setup after loading the view from its nib.
    if (![SKPaymentQueue canMakePayments]) {
        // Warn the user that purchases are disabled.
        UIAlertView *alertIAP = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"In-App Purchase Problem", nil)
                                                          message:NSLocalizedString(@"Please check:\nSettings->\nGeneral->\nRestrictions->\nIn-App Purchases.", nil)
                                                         delegate:self
                                                cancelButtonTitle:NSLocalizedString(@"Back", nil)
                                                otherButtonTitles:nil];
        [alertIAP show];
        return;
    }

    _blockView = [[UIView alloc] initWithFrame:self.table.frame];
    _blockView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
    _blockView.userInteractionEnabled = YES;    //Block touch to table

    [self _showHUDWithLabel:NSLocalizedString(@"Loading Items", nil) subLabel:NSLocalizedString(@"Please wait", nil) animated:NO];

    if(!m_request) {
        NSMutableSet *identifiers = [NSMutableSet set];
        [identifiers addObject:kIdentifierUnlimitCount];
//        [identifiers addObject:kIdentifierRemoveAD];

        m_request = [[SKProductsRequest alloc] initWithProductIdentifiers:identifiers];
        m_request.delegate = self;
    }
    
    [m_request start];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

//==============================================================
//  [BEGIN] UIAlertViewDelegate
#pragma mark - UIAlertViewDelegate
//--------------------------------------------------------------
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [self.delegate finishIAP];
}
//--------------------------------------------------------------
//  [END] UIAlertViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] SKRequestDelegate
#pragma mark - SKRequestDelegate
//--------------------------------------------------------------
- (void)requestDidFinish:(SKRequest *)request
{
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    [self.table reloadData];
    [self _hideHUDAnimated:YES];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
#ifdef DEBUG
    NSLog(@"Fail to request %@", [request description]);
#endif
    [self _hideHUDAnimated:NO];
    UIAlertView *alertFail = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot Fetch Items", nil)
                                                        message:NSLocalizedString(@"Please try again later.", nil)
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Back", nil)
                                              otherButtonTitles:nil];
    [alertFail show];
}
//--------------------------------------------------------------
//  [END] SKRequestDelegate
//==============================================================

//==============================================================
//  [BEGIN] SKProductsRequestDelegate
#pragma mark - SKProductsRequestDelegate
//--------------------------------------------------------------
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    if([response.products count] == 0) {
        [self _hideHUDAnimated:NO];
        UIAlertView *alertFail = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot Fetch Items", nil)
                                                            message:NSLocalizedString(@"Please try again later.", nil)
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"Back", nil)
                                                  otherButtonTitles:nil];
        [alertFail show];
        return;
    }

    m_products = [NSMutableArray arrayWithArray:response.products];
    _identifierToProductMap = [NSMutableDictionary dictionary];
    for(SKProduct *product in m_products) {
        [_identifierToProductMap setObject:product forKey:product.productIdentifier];
    }
}
//--------------------------------------------------------------
//  [END] SKProductsRequestDelegate
//==============================================================

//==============================================================
//  [BEGIN] SKPaymentTransactionObserver
#pragma mark - SKPaymentTransactionObserver
//--------------------------------------------------------------
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for(SKPaymentTransaction *transaction in transactions) {
        void(^finishTransactionBlock)() = ^{
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            self.doneButton.enabled = YES;
            [_blockView removeFromSuperview];
            _selectedIndex = nil;
        };

        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self _completeTransaction:transaction];
                finishTransactionBlock();
                break;
            case SKPaymentTransactionStateFailed:
                [self _failedTransaction:transaction];
                finishTransactionBlock();
                break;
            case SKPaymentTransactionStateRestored:
                [self _restoreTransaction:transaction];
                finishTransactionBlock();
                break;
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"Purchasing...");
                break;
            default:
                break;
        }
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    [self _hideHUDAnimated:YES];
}

- (void)_completeTransaction:(SKPaymentTransaction *)transaction
{
    NSLog(@"Complete transaction:\nIdentifier:%@", transaction.payment.productIdentifier);

    /*
    if([kIdentifierRemoveAD isEqualToString:transaction.payment.productIdentifier]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kPurchaseRemoveAD];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else*/
    if([kIdentifierUnlimitCount isEqualToString:transaction.payment.productIdentifier]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kPurchaseUnlimitCount];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    SKProduct *product = [_identifierToProductMap objectForKey:transaction.payment.productIdentifier];
#ifndef DEBUG
    if(product)
#endif
    {
        NSInteger completeIndex = [m_products indexOfObject:product];

        UITableViewCell *cell = [self.table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:completeIndex]];
        cell.userInteractionEnabled = NO;
        cell.detailTextLabel.text = NSLocalizedString(@"Installed", nil);
        [cell setNeedsDisplay];
    }
    
    if(/*[[NSUserDefaults standardUserDefaults] boolForKey:kPurchaseRemoveAD] &&*/
       [[NSUserDefaults standardUserDefaults] boolForKey:kPurchaseUnlimitCount])
    {
        [self.delegate finishIAP];
    }
}

- (void)_failedTransaction:(SKPaymentTransaction *)transaction
{
    NSLog(@"Fail transaction\nIdentifier:%@", transaction.payment.productIdentifier);

    if (transaction.error.code != SKErrorPaymentCancelled) {
        // Optionally, display an error here.
    }
    
    if(_selectedIndex) {
        [self.table reloadRowsAtIndexPaths:[NSArray arrayWithObject:_selectedIndex]
                          withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void)_restoreTransaction:(SKPaymentTransaction *)transaction
{
    NSLog(@"Restore transaction\nIdentifier:%@", transaction.payment.productIdentifier);

    /*if([kIdentifierRemoveAD isEqualToString:transaction.payment.productIdentifier]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kPurchaseRemoveAD];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else*/
    if([kIdentifierUnlimitCount isEqualToString:transaction.payment.productIdentifier]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kPurchaseUnlimitCount];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    SKProduct *product = [_identifierToProductMap objectForKey:transaction.payment.productIdentifier];
#ifndef DEBUG
    if(product)
#endif
    {
        NSInteger restoreIndex = [m_products indexOfObject:product];
        
        UITableViewCell *cell = [self.table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:restoreIndex]];
        cell.detailTextLabel.text = NSLocalizedString(@"Installed", nil);
        cell.userInteractionEnabled = NO;
        [cell setNeedsDisplay];
    }
    
    if(/*[[NSUserDefaults standardUserDefaults] boolForKey:kPurchaseRemoveAD] &&*/
       [[NSUserDefaults standardUserDefaults] boolForKey:kPurchaseUnlimitCount])
    {
        [self.delegate finishIAP];
    }
}

//- (BOOL)_verifyReceipt:(SKPaymentTransaction *)transaction {
//    NSString *jsonObjectString = [self _encode:(uint8_t *)transaction.transactionReceipt.bytes
//                                        length:transaction.transactionReceipt.length];      
//    NSString *completeString = [NSString stringWithFormat:@"http://url-for-your-php?receipt=%@", jsonObjectString];                               
//    NSURL *urlForValidation = [NSURL URLWithString:completeString];               
//    NSMutableURLRequest *validationRequest = [[NSMutableURLRequest alloc] initWithURL:urlForValidation];                          
//    [validationRequest setHTTPMethod:@"GET"];             
//    NSData *responseData = [NSURLConnection sendSynchronousRequest:validationRequest returningResponse:nil error:nil];  
//    NSString *responseString = [[NSString alloc] initWithData:responseData encoding: NSUTF8StringEncoding];
//    NSInteger response = [responseString integerValue];
//    return (response == 0);
//}
//
//- (NSString *)_encode:(const uint8_t *)input length:(NSInteger)length {
//    static char char_table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
//    
//    NSMutableData *data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
//    uint8_t *output = (uint8_t *)data.mutableBytes;
//    
//    for (NSInteger i = 0; i < length; i += 3) {
//        NSInteger value = 0;
//        for (NSInteger j = i; j < (i + 3); j++) {
//            value <<= 8;
//            
//            if (j < length) {
//                value |= (0xFF & input[j]);
//            }
//        }
//        
//        NSInteger index = (i / 3) * 4;
//        output[index + 0] =                    char_table[(value >> 18) & 0x3F];
//        output[index + 1] =                    char_table[(value >> 12) & 0x3F];
//        output[index + 2] = (i + 1) < length ? char_table[(value >> 6)  & 0x3F] : '=';
//        output[index + 3] = (i + 2) < length ? char_table[(value >> 0)  & 0x3F] : '=';
//    }
//    
//    return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
//}

//--------------------------------------------------------------
//  [END] SKPaymentTransactionObserver
//==============================================================

//==============================================================
//  [BEGIN] IBActions
#pragma mark - IBActions
//--------------------------------------------------------------
- (IBAction)done:(id)sender
{
    if(!m_products) {
        m_request.delegate = nil;
        [m_request cancel];
    }

#ifdef DEBUG
//    //For testing without real purchase
//    /*[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kPurchaseRemoveAD];*/
//    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kPurchaseUnlimitCount];
//    [[NSUserDefaults standardUserDefaults] synchronize];
#endif

    [self.delegate finishIAP];
}
//--------------------------------------------------------------
//  [END] IBActions
//==============================================================

//==============================================================
//  [BEGIN] MBProgressHUDDelegate
#pragma mark - MBProgressHUDDelegate
//--------------------------------------------------------------
- (void)_showHUDWithLabel:(NSString *)label subLabel:(NSString *)subLabel animated:(BOOL)animate
{
    [self.view addSubview:_blockView];

    if(_hud == nil) {
        _hud = [[MBProgressHUD alloc] initWithFrame:self.table.frame];
        _hud.removeFromSuperViewOnHide = YES;
        _hud.delegate = self;
        [self.view addSubview:_hud];
    }
    
    _hud.labelText = label;
    _hud.detailsLabelText = subLabel;
    [_hud show:animate];
}

- (void)_hideHUDAnimated:(BOOL)animate
{
    [_hud hide:animate];
    [_blockView removeFromSuperview];
}

- (void)hudWasHidden
{
    _hud = nil;
}
//--------------------------------------------------------------
//  [END] MBProgressHUDDelegate
//==============================================================

//==============================================================
//  [BEGIN] UITableViewDelegate
#pragma mark - UITableViewDelegate
//--------------------------------------------------------------
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == kRestoreButtonSection) {
        [self.table deselectRowAtIndexPath:indexPath animated:YES];
        [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
        [self _showHUDWithLabel:NSLocalizedString(@"Restoring Bought Items", nil)
                       subLabel:NSLocalizedString(@"Please wait", nil)
                       animated:YES];
        return;
    }

    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        SKProduct *product = [m_products objectAtIndex:indexPath.section];
        [FlurryAnalytics logEvent:@"Select IAP Item"
                   withParameters:[NSDictionary dictionaryWithObject:product.productIdentifier
                                                              forKey:@"Product"]];
    }

    _selectedIndex = indexPath;
    [self.table deselectRowAtIndexPath:indexPath animated:NO];
    
    [self.view addSubview:_blockView];
    self.doneButton.enabled = NO;
    
    UITableViewCell *cell = [self.table cellForRowAtIndexPath:indexPath];
    cell.detailTextLabel.text = nil;
    
    if(!_buyingIndicator) {
        _buyingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    }
    [_buyingIndicator startAnimating];
    cell.accessoryView = _buyingIndicator;

    SKProduct *product = [m_products objectAtIndex:indexPath.section];
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(kRestoreButtonSection == indexPath.section) {
        return 44;
    }

    SKProduct *product = [m_products objectAtIndex:indexPath.section];
    NSString *cellText = product.localizedDescription;
    UIFont *cellFont = [UIFont boldSystemFontOfSize:17.0f];
    CGSize constraintSize = CGSizeMake(230.0f, MAXFLOAT);
    CGSize labelSize = [cellText sizeWithFont:cellFont constrainedToSize:constraintSize lineBreakMode:UILineBreakModeWordWrap];

    return labelSize.height+20;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
}
//--------------------------------------------------------------
//  [END] UITableViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] UITableViewDataSource
#pragma mark - UITableViewDataSource
//--------------------------------------------------------------
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(kRestoreButtonSection == indexPath.section) {
        UITableViewCell *restoreCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"RestoreCell"];
        restoreCell.textLabel.text = NSLocalizedString(@"Restore Bought Items", nil);
        restoreCell.textLabel.textAlignment = UITextAlignmentCenter;
        return restoreCell;
    }

    static NSString *CellTableIdentitifier = @"IAP_Cell";
    IAPCell *cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
    if(cell == nil) {
        cell = [[IAPCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellTableIdentitifier];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    }

    SKProduct *product = [m_products objectAtIndex:indexPath.section];
    cell.textLabel.text = product.localizedDescription;
    
    NSString *cellText = product.localizedDescription;
    UIFont *cellFont = [UIFont boldSystemFontOfSize:17.0f];
    CGSize constraintSize = CGSizeMake(230.0f, MAXFLOAT);
    CGSize labelSize = [cellText sizeWithFont:cellFont constrainedToSize:constraintSize lineBreakMode:UILineBreakModeWordWrap];
    cell.textLabelSize = labelSize;
    int numberOfLines = labelSize.height/cellFont.lineHeight;
    cell.textLabel.numberOfLines = numberOfLines;
    cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
    
    cell.accessoryView = nil;
    BOOL isInstalled = NO;
    
    /*if([product.productIdentifier isEqualToString:kIdentifierRemoveAD]) {
        if([[NSUserDefaults standardUserDefaults] boolForKey:kPurchaseRemoveAD]) {
            isInstalled = YES;
        }
    } else*/
    if([product.productIdentifier isEqualToString:kIdentifierUnlimitCount]) {
        if([[NSUserDefaults standardUserDefaults] boolForKey:kPurchaseUnlimitCount]) {
            isInstalled = YES;
        }
    }
    
    if(isInstalled) {
        cell.detailTextLabel.text = NSLocalizedString(@"Installed", nil);
        cell.userInteractionEnabled = NO;
    } else {
        if(!_priceFormatter) {
            _priceFormatter = [[NSNumberFormatter alloc] init];  
            [_priceFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];  
            [_priceFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        }
        
        [_priceFormatter setLocale:product.priceLocale];  
        NSString *formattedPrice = [_priceFormatter stringFromNumber:product.price];
        cell.detailTextLabel.text = formattedPrice;
    }

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if([m_products count] > 0) {
        return [m_products count] + 1;  //1 is "Restore" button
    }

    return 0;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if(section >= [m_products count]) {
        return nil;
    }

    SKProduct *product = [m_products objectAtIndex:section];
    return product.localizedTitle;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if(section != kRestoreButtonSection) {
        return nil;
    }
    
    return NSLocalizedString(@"Restore bought items so that you don't have to buy again.", nil);
}
//--------------------------------------------------------------
//  [END] UITableViewDataSource
//==============================================================
@end
