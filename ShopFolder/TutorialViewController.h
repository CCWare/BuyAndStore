//
//  TutorialViewController.h
//  ShopFolder
//
//  Created by Michael on 2011/12/07.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol TutorialViewControllerDelegate;

@interface TutorialViewController : UIViewController <UIWebViewDelegate>
{
    UIWebView *contentView;
    UIBarButtonItem *prevButton;
    UIBarButtonItem *indexItem;
    UIBarButtonItem *nextButton;
    
    NSMutableArray *pages; //page URLs
    NSUInteger currentPageIndex;
}

@property (nonatomic, strong) IBOutlet UIWebView *contentView;
@property (nonatomic, strong) IBOutlet UIToolbar *toolbar;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *prevButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *indexItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *nextButton;
@property (nonatomic, weak) id <TutorialViewControllerDelegate> delegate;

- (id)initWithPages:(NSArray *)pageStrings;

- (void)done:(id)sender;
- (IBAction)prev:(id)sender;
- (IBAction)next:(id)sender;
@end

@protocol TutorialViewControllerDelegate
- (void)endTutorial;
@end