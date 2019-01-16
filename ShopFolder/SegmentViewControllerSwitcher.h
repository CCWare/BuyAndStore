//
//  SegmentViewControllerSwitcher.h
//  ShopFolder
//
//  Created by Michael on 2011/10/20.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SegmentViewControllerSwitcher : NSObject
{
    NSArray *viewControllers;
    UINavigationController *navigationController;
}

@property (nonatomic, strong, readonly) NSArray *viewControllers;
@property (nonatomic, strong, readonly) UINavigationController *navigationController;

/**
 * Usage:
 *  Step 1: Prepare view controller array
 *  Step 2: Initialize a navigation controller (or use self.navigationController is not nil)
 *  Step 3: New a SegmentViewControllerSwitcher with data from step 1 and 2
 *  Step 4: New a UISegmentedControl and set its style and target
 *  Step 5: Set selection index of the segment controller
 *  Step 6: Calls indexChangedInSegmentedControl: to select segment
 */
- (id)initWithNavigationController:(UINavigationController *)navCtrl
                   viewControllers:(NSArray *)inViewControllers;

- (void)indexChangedInSegmentedControl:(UISegmentedControl *)segCtrl;
@end
