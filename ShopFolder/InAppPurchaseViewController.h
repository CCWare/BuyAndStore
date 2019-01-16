//
//  InAppPurchaseViewController.h
//  ShopFolder
//
//  Created by Michael Tsai on 2012/03/21.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import "MBProgressHUD.h"

@protocol InAppPurchaseViewControllerDelegate;

@interface InAppPurchaseViewController : UIViewController <UIAlertViewDelegate, SKRequestDelegate,
                                                           SKProductsRequestDelegate, SKPaymentTransactionObserver,
                                                           UITableViewDelegate, UITableViewDataSource,
                                                           MBProgressHUDDelegate>
{
    SKProductsRequest *m_request;
    NSMutableArray *m_products;
    NSNumberFormatter *_priceFormatter;
    MBProgressHUD *_hud;
    
    NSMutableDictionary *_identifierToProductMap;
    
    UIView *_blockView;
    UIActivityIndicatorView *_buyingIndicator;
    
    NSIndexPath *_selectedIndex;
}

@property (nonatomic, strong) IBOutlet UINavigationItem *navBar;
@property (nonatomic, strong) IBOutlet UITableView *table;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *doneButton;
@property (nonatomic, weak) id<InAppPurchaseViewControllerDelegate> delegate;

- (IBAction)done:(id)sender;
@end

@protocol InAppPurchaseViewControllerDelegate
- (void)finishIAP;
@end
