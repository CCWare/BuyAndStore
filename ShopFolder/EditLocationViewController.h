//
//  EditLocationViewController.h
//  ShopFolder
//
//  Created by Michael Tsai on 2012/01/16.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "DBLocation.h"
#import "MapAnnotation.h"
#import "MBProgressHUD.h"

@class Reachability;

@protocol EditLocationViewControllerDelegate;

@interface EditLocationViewController : UIViewController <UITextFieldDelegate, UITableViewDelegate,
                                                          UITableViewDataSource, MKMapViewDelegate, UIAlertViewDelegate,
                                                          CLLocationManagerDelegate,
                                                          MBProgressHUDDelegate>
{
    DBLocation *editLocation;
    CGFloat fEditCellHeight;
    UIFont *editFieldFont;

    CLLocationManager *locationManager;
    CLGeocoder *newGeoCoder;
    MapAnnotation *mapPin;
    
    CLLocation *currentLocation;
    
    MBProgressHUD *hud;
    
    Reachability* internetReachable;
    Reachability* hostReachable;
    
    BOOL shouldCheckNetwork;
    UIAlertView *alertNameField;
    UIAlertView *alertNetwork;
}

@property (nonatomic, weak) id<EditLocationViewControllerDelegate> delegate;
@property (nonatomic, strong) IBOutlet UITableView *editTable;
@property (nonatomic, strong) IBOutlet MKMapView *mapView;
@property (nonatomic, strong) IBOutlet UIView *hintView;
@property (nonatomic, strong) IBOutlet UILabel *hintLabel;
@property (nonatomic, strong) IBOutlet UIButton *removePinButton;
@property (nonatomic, strong) IBOutlet UILabel *errorLabel;

- (id)initToAddNewLocationWithName:(NSString *)name;
- (id)initToEditLocation:(DBLocation *)location;

- (IBAction)removePin:(id)sender;
@end

@protocol EditLocationViewControllerDelegate
- (void)finishEditingLocation:(DBLocation *)location;
- (void)cancelEditingLocation;
@end