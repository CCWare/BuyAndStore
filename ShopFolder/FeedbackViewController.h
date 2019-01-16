//
//  FeedbackViewController.h
//  ShopFolder
//
//  Created by Michael on 2011/12/10.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"

@protocol FeedbackViewControllerDelegate;

@interface FeedbackViewController : UIViewController <UIWebViewDelegate, UIAlertViewDelegate, MBProgressHUDDelegate>
{
    MBProgressHUD *_hud;
    UIWebView *webview;
}

@property (nonatomic, strong) IBOutlet UIWebView *webview;
@property (nonatomic, weak) id<FeedbackViewControllerDelegate> delegate;

@end

@protocol FeedbackViewControllerDelegate
- (void)endFeedback;
@end