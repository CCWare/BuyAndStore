//
//  PickLocationViewController.h
//  ShopFolder
//
//  Created by Michael Tsai on 2012/01/16.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EditLocationViewController.h"
#import "DBLocation.h"
#import "MBProgressHUD.h"

@protocol PickLocationViewControllerDelegate;

@interface PickLocationViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate,
                                                          UIActionSheetDelegate, CLLocationManagerDelegate, UIAlertViewDelegate,
                                                          EditLocationViewControllerDelegate, MBProgressHUDDelegate>
{
    NSMutableArray *locationList;   //List of Location
    NSMutableArray *displayList;

    NSIndexPath *selectedPath;
    NSString *searchToken;

    UIBarButtonItem *editButton;
    UIBarButtonItem *doneButton;
    
    CGFloat fTableHeight;
    
    MBProgressHUD *hud;
    CLLocationManager *locationManager;
    CLLocation *currentLocation;
    
    NSIndexPath *editIndex;
    
    BOOL canUseGPS;
}

@property (nonatomic, strong) IBOutlet UITableView *table;
@property (nonatomic, strong) IBOutlet UISearchBar *customizedSearchBar;
@property (nonatomic, weak) id<PickLocationViewControllerDelegate> delegate;

@property (nonatomic, strong) UIColor *searchBarColor;

@end


@protocol PickLocationViewControllerDelegate
- (void)pickLocation:(DBLocation *)location;
@optional
- (void)cancelPickingLocation;
@end