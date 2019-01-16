//
//  SegmentViewControllerSwitcher.m
//  ShopFolder
//
//  Created by Michael on 2011/10/20.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "SegmentViewControllerSwitcher.h"
#import "ColorConstant.h"

@interface SegmentViewControllerSwitcher ()
@property (nonatomic, strong) NSArray *viewControllers;
@property (nonatomic, strong) UINavigationController *navigationController;

@end

@implementation SegmentViewControllerSwitcher
@synthesize viewControllers;
@synthesize navigationController;


- (id)initWithNavigationController:(UINavigationController *)navCtrl
                   viewControllers:(NSArray *)inViewControllers
{
    if((self = [super init])) {
        self.navigationController = navCtrl;
        self.viewControllers = inViewControllers;
        self.navigationController.navigationBar.tintColor = kColorNavigationBarTintColor;
    }
    
    return self;
}

- (void)indexChangedInSegmentedControl:(UISegmentedControl *)segCtrl
{
    NSUInteger index = segCtrl.selectedSegmentIndex;
    UIViewController *selectedViewController = [self.viewControllers objectAtIndex:index];

    NSArray *displayViewControllers = [NSArray arrayWithObject:selectedViewController];
    [self.navigationController setViewControllers:displayViewControllers animated:NO];

    selectedViewController.navigationItem.titleView = segCtrl;
}

@end
