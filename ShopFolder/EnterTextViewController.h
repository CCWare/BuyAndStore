//
//  EnterTextViewController.h
//  ShopFolder
//
//  Created by Michael on 2011/12/01.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol EnterTextViewControllerDelegate;

@interface EnterTextViewController : UIViewController <UITextViewDelegate>
{
    UINavigationItem *navItem;
    UITextView *textView;
}

@property (nonatomic, strong) IBOutlet UINavigationItem *navItem;
@property (nonatomic, strong) IBOutlet UITextView *textView;
@property (nonatomic, weak) id<EnterTextViewControllerDelegate> delegate;

- (IBAction)cancel;
- (IBAction)done;

@end

@protocol EnterTextViewControllerDelegate
- (void)cancelEnteringText;
- (void)finishEnteringText:(NSString *)text;
@end