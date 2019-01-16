//
//  BarcodeHelpViewController.h
//  ShopFolder
//
//  Created by Michael on 2012/1/4.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol BarcodeHelpViewController
- (void)leaveBarcodeHelp;
@end

@interface BarcodeHelpViewController : UIViewController <UIWebViewDelegate>
{
    UINavigationItem *barTitle;
    UIWebView *helpWebView;
    
    UIBarButtonItem *doneButton;
    UIView *blackView;
}

@property (nonatomic, weak) id<BarcodeHelpViewController> delegate;
@property (nonatomic, strong) IBOutlet UINavigationItem *barTitle;
@property (nonatomic, strong) IBOutlet UIWebView *helpWebView;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *doneButton;
@property (nonatomic, strong) IBOutlet UIView *blackView;

- (IBAction)done:(id)sender;
@end
