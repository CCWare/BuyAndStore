//
//  EditLocationViewController.m
//  ShopFolder
//
//  Created by Michael Tsai on 2012/01/16.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "EditLocationViewController.h"
#import "CoreDataDatabase.h"
#import <AddressBookUI/AddressBookUI.h>
#import <QuartzCore/QuartzCore.h>   //For using CALayer
#import "Reachability.h"    //Requires SystemConfiguration framework
#import "VersionCompare.h"
#import "DBLocation+SetAndGet.h"
#import "ColorConstant.h"

#define kMaxLocateTime  10.0   //second

#define kEditCellVerticalSpace      4
#define kEditCellHorizontalSpace    4

@interface EditLocationViewController ()
- (void)_saveLocation;
- (void)_cancelEditingLocation;
- (void)_textFieldEndEditing:(UITextField *)textfield;

- (void)_displayLocation:(CLLocation *)location animated:(BOOL)animate;
- (void)_replacePin;
- (void)_updatePinAnimated:(BOOL)animate;
- (void)_startToGetAddressFromLocation:(CLLocationCoordinate2D)coorinate;
- (void)_stopUpdatingLocation;
- (void)_stopGettingAddress;

- (void)_tapOnMap:(UITapGestureRecognizer *)sender;

- (void)_showHUDWithMessage:(NSString *)message detailedMessage:(NSString *)subMsg;

- (void)_showError:(NSString *)errorMsg;
- (void)_locateTimeout;

- (void)_checkNetworkStatus:(NSNotification *)notice;

@property (nonatomic, strong) UITextField *_nameField;
@property (nonatomic, strong) UITextField *_addressField;
@end

@implementation EditLocationViewController
@synthesize delegate;
@synthesize editTable;
@synthesize mapView;
@synthesize hintView;
@synthesize hintLabel;
@synthesize removePinButton;
@synthesize errorLabel;

@synthesize _nameField;
@synthesize _addressField;

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    [self.mapView removeAnnotation:mapPin];
    mapPin = nil;

    self.editTable = nil;
    self.mapView.delegate = nil;
    self.mapView = nil;
    self.hintView = nil;
    self.hintLabel = nil;
    self.removePinButton = nil;
    self.errorLabel = nil;
    
    self._nameField = nil;
    self._addressField = nil;
    
    locationManager.delegate = nil;
    [locationManager stopUpdatingLocation];
    locationManager = nil;
    
    [self _stopGettingAddress];
    
    hud.delegate = nil;
    [hud hide:NO];
    hud = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    alertNameField = nil;
    alertNetwork.delegate = nil;
    alertNetwork = nil;
}

- (void)dealloc
{
    [self _stopGettingAddress];

    self.mapView.delegate = nil;
    locationManager.delegate = nil;
    [locationManager stopUpdatingLocation];
    locationManager = nil;
    
    hud.delegate = nil;
    [hud hide:NO];
    hud = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initToAddNewLocationWithName:(NSString *)name
{
    if((self = [super initWithNibName:nil bundle:nil])) {
        editLocation = [CoreDataDatabase obtainLocation];
        editLocation.name = name;
        self.title = NSLocalizedString(@"Add Place", nil);
    }
    
    return self;
}

- (id)initToEditLocation:(DBLocation *)location
{
    if((self = [super initWithNibName:nil bundle:nil])) {
        editLocation = location;
        self.title = NSLocalizedString(@"Edit Place", nil);
    }
    
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                  target:self
                                                                                  action:@selector(_cancelEditingLocation)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                target:self
                                                                                action:@selector(_saveLocation)];
    self.navigationItem.rightBarButtonItem = saveButton;
    self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
    self.navigationController.navigationBar.tintColor = kColorNavigationBarTintColor;
    
    self.navigationItem.rightBarButtonItem.enabled = ([editLocation.name length] > 0);

    editFieldFont = [UIFont systemFontOfSize:17];
    fEditCellHeight = editFieldFont.lineHeight + 2*kEditCellVerticalSpace;

    self._nameField = [[UITextField alloc] initWithFrame:CGRectMake(kEditCellHorizontalSpace+10, kEditCellVerticalSpace,
                                                                    300-kEditCellHorizontalSpace,
                                                                    editFieldFont.lineHeight)];
    self._nameField.font = editFieldFont;
    self._nameField.placeholder = NSLocalizedString(@"Name(Required)", nil);
    self._nameField.delegate = self;
    self._nameField.clearButtonMode = UITextFieldViewModeNever;
    self._nameField.returnKeyType = UIReturnKeyDone;
    [self._nameField addTarget:self action:@selector(_textFieldEndEditing:) forControlEvents:UIControlEventEditingDidEndOnExit];
//    self._nameField.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:0.2];
    self._nameField.text = editLocation.name;

    self._addressField = [[UITextField alloc] initWithFrame:CGRectMake(kEditCellHorizontalSpace+10, kEditCellVerticalSpace,
                                                                       300-kEditCellHorizontalSpace,
                                                                       editFieldFont.lineHeight)];
    self._addressField.font = editFieldFont;
    self._addressField.placeholder = NSLocalizedString(@"Address(Optional)", nil);
    self._addressField.delegate = self;
    self._addressField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self._addressField.returnKeyType = UIReturnKeyDone;
    [self._addressField addTarget:self action:@selector(_textFieldEndEditing:) forControlEvents:UIControlEventEditingDidEndOnExit];
//    self._addressField.backgroundColor = [UIColor colorWithRed:0 green:1 blue:0 alpha:0.2];
    self._addressField.text = editLocation.address;
    
    mapPin = [[MapAnnotation alloc] initWithLocation:editLocation];
    
    //Add tap gesture to map
    UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tapOnMap:)];
    tapGR.numberOfTapsRequired = 1;
    [self.mapView addGestureRecognizer:tapGR];
    
    self.hintLabel.text = NSLocalizedString(@"Tap on the map to drop the pin", nil);
    [self.removePinButton setTitle:NSLocalizedString(@"Remove Pin", nil) forState:UIControlStateNormal];
    self.removePinButton.titleLabel.textColor = [UIColor whiteColor];
    self.removePinButton.layer.cornerRadius = 10.0;
    self.removePinButton.layer.borderColor = [UIColor whiteColor].CGColor;
    self.removePinButton.layer.borderWidth = 1;

    shouldCheckNetwork = YES;
    CLLocation *locationData = [editLocation getLocation];
    if(locationData) {
        [self _displayLocation:locationData animated:NO];
        self.hintLabel.hidden = YES;
        self.removePinButton.hidden = NO;
        [self.mapView addAnnotation:mapPin];
        
        if([editLocation.address length] == 0) {
            [self _startToGetAddressFromLocation:locationData.coordinate];
        }
    } else if([CLLocationManager locationServicesEnabled]) {
        if([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
            [self _showError:NSLocalizedString(@"Deny to use location service.", nil)];
            shouldCheckNetwork = NO;
        } else {
            [self _showHUDWithMessage:NSLocalizedString(@"Getting current location...", nil) detailedMessage:nil];

            currentLocation = nil;
            locationManager = [[CLLocationManager alloc] init];
            locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
            locationManager.delegate = self;
            [locationManager startUpdatingLocation];
            
            [self performSelector:@selector(_locateTimeout) withObject:nil afterDelay:kMaxLocateTime+0.5];
        }
    } else {
        [self _showError:NSLocalizedString(@"Location service disabled.", nil)];
        shouldCheckNetwork = NO;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if(shouldCheckNetwork) {
        // check for internet connection
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_checkNetworkStatus:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];
        
        internetReachable = [Reachability reachabilityForInternetConnection];
        [internetReachable startNotifier];
        
        // check if a pathway to a random host exists
        hostReachable = [Reachability reachabilityWithHostName: @"www.google.com"];
        [hostReachable startNotifier];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [hud hide:NO];
    locationManager.delegate = nil;
    [locationManager stopUpdatingLocation];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self]; //Remove network status watcher

    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

//==============================================================
//  [BEGIN] UITableViewDelegate
#pragma mark - UITableViewDelegate
//--------------------------------------------------------------
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return fEditCellHeight;
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
    static NSString *CellTableIdentitifier = @"EditLocationTableCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
    if(cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellTableIdentitifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        if(indexPath.row == 0) {
            [cell addSubview:self._nameField];
        } else {
            [cell addSubview:self._addressField];
        }
    }

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 2;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(editingStyle == UITableViewCellEditingStyleDelete) {
    }
}
//--------------------------------------------------------------
//  [END] UITableViewDataSource
//==============================================================

//==============================================================
//  [BEGIN] UITextFieldDelegate
#pragma mark - UITextFieldDelegate
//--------------------------------------------------------------
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *candidateString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if([@"\n" isEqualToString:candidateString]) {
        //User hit "Done" with no text
        candidateString = nil;
    }

    if(textField == self._nameField) {
        editLocation.name = ([candidateString length]==0) ? nil : candidateString;
        self.navigationItem.rightBarButtonItem.enabled = ([editLocation.name length] > 0);
    } else if(textField == self._addressField) {
        editLocation.address = ([candidateString length]==0) ? nil : candidateString;
    }
    
    [self _updatePinAnimated:NO];

    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    if(textField == self._addressField) {
        editLocation.address = nil;
    }
    
    [self _updatePinAnimated:NO];

    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self _stopGettingAddress];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
//    if(textField == self._addressField &&
//       [textField.text length] > 0)
//    {
//        if([VersionCompare compareVersion:[[UIDevice currentDevice] systemVersion]
//                                toVersion:@"5.0"] != NSOrderedAscending)
//        {
//            [self _showHUDWithMessage:NSLocalizedString(@"Getting location from address...", nil) detailedMessage:nil];
//
//            CLGeocoder *newGeoCoder = [[CLGeocoder alloc] init];
//            [newGeoCoder geocodeAddressString:textField.text
//                            completionHandler:^(NSArray *placemarks, NSError *error) {
//                                for(CLPlacemark *placemark in placemarks) {
//                                    editLocation.locationData = [[CLLocation alloc] initWithLatitude:placemark.location.coordinate.latitude 
//                                                                                           longitude:placemark.location.coordinate.longitude];
//
//                                    //Update pin without animation
//                                    [mapPin setCoordinate:editLocation.locationData.coordinate];
//                                    
//                                    if([[self.mapView annotations] count] > 0) {
//                                        [self _updatePinAnimated:YES];
//                                    } else {
//                                        [self.mapView addAnnotation:mapPin];
//                                    }
//                                    
//                                    //Update pin with animation
//                                    [self _replacePin];
//                                }
//
//                                [hud hide:YES];
//                            }];
//        }
//    }
}
//--------------------------------------------------------------
//  [END] UITextFieldDelegate
//==============================================================

//==============================================================
//  [BEGIN] MKMapViewDelegate
#pragma mark - MKMapViewDelegate
//--------------------------------------------------------------
- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
    //Show callout when pin drops
    [self.mapView selectAnnotation:mapPin animated:NO];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    [hud hide:YES]; //Hide hud when pin appears
    
//    if(annotation == self.mapView.userLocation) {
//        //Return default blue circle
//        return nil;
//    }

    self.hintLabel.hidden = YES;
    self.removePinButton.hidden = NO;

    static NSString *PinIdentifier = @"MapPin";

    MKPinAnnotationView *pinView = (MKPinAnnotationView *)[self.mapView dequeueReusableAnnotationViewWithIdentifier:PinIdentifier];
    if(pinView) {
        pinView.annotation = annotation;
    } else {
        pinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:PinIdentifier];
        pinView.draggable = YES;
        pinView.pinColor = MKPinAnnotationColorRed;
        pinView.animatesDrop = YES;
        pinView.canShowCallout = YES;
        [pinView setSelected:YES animated:YES];
    }
    
    return pinView;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState
{
    //If user drags the pin, stop locating
    currentLocation = nil;
    [self _stopUpdatingLocation];
    
    if(newState == MKAnnotationViewDragStateStarting) {
        self._addressField.text = nil;
        editLocation.address = nil;
    } else if(newState == MKAnnotationViewDragStateEnding) {
        CLLocationCoordinate2D droppedAt = view.annotation.coordinate;
        [editLocation setLocation:[[CLLocation alloc] initWithLatitude:droppedAt.latitude longitude:droppedAt.longitude]];
        [self _updatePinAnimated:NO];

        [self _startToGetAddressFromLocation:droppedAt];
    }
}

- (void)mapViewWillStartLoadingMap:(MKMapView *)mapView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

- (void)mapViewDidFailLoadingMap:(MKMapView *)mapView withError:(NSError *)error
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

    [self _showError:NSLocalizedString(@"Fail to load map.", nil)];
}
//--------------------------------------------------------------
//  [END] MKMapViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] CLLocationManagerDelegate
#pragma mark - CLLocationManagerDelegate
//--------------------------------------------------------------
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    NSDate* eventDate = newLocation.timestamp;
    NSTimeInterval howRecent = [eventDate timeIntervalSinceNow];
    
    if(howRecent >= 0.0 || howRecent < -10.0) {
        NSLog(@"Location is too old");
        return;
    }
    
    if(newLocation.horizontalAccuracy < 0) {
        NSLog(@"Useless accuracy");
        return;
    }
    
    if(currentLocation == nil ||
       currentLocation.horizontalAccuracy > newLocation.horizontalAccuracy)
    {
        NSLog(@"Get location, recent %f, accuracy: %f", howRecent, newLocation.horizontalAccuracy);
        currentLocation = newLocation;
        [self _displayLocation:currentLocation animated:YES];
        
        if(newLocation.horizontalAccuracy <= locationManager.desiredAccuracy) {
            NSLog(@"Reach desired accuracy");
            [self _stopUpdatingLocation];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    currentLocation = nil;
    [self _stopUpdatingLocation];
    
    if(error.code == kCLErrorDenied) {
        [self _showError:NSLocalizedString(@"Location service access denied.", nil)];
    } else {
        [self _showError:NSLocalizedString(@"Fail to get current location.", nil)];
    }
}
//--------------------------------------------------------------
//  [END] CLLocationManagerDelegate
//==============================================================

//==============================================================
//  [BEGIN] MKReverseGeocoderDelegate
#pragma mark - MKReverseGeocoderDelegate
//--------------------------------------------------------------
- (void)_stopGettingAddress
{
    if([newGeoCoder isGeocoding]) {
        [newGeoCoder cancelGeocode];
    }
    newGeoCoder = nil;

    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

//--------------------------------------------------------------
//  [END] MKReverseGeocoderDelegate
//==============================================================

//==============================================================
//  [BEGIN] UIAlertViewDelegate
#pragma mark - UIAlertViewDelegate
//--------------------------------------------------------------
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if(alertNameField == alertView) {
        [self._nameField becomeFirstResponder];
    } else if(alertNetwork == alertView) {
        alertNetwork = nil;
        if(buttonIndex == alertView.cancelButtonIndex) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"prefs:root=General&path=Network"]];
        }
    }
}
//--------------------------------------------------------------
//  [END] UIAlertViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] MBProgressHUDDelegate
#pragma mark - MBProgressHUDDelegate
//--------------------------------------------------------------
- (void)_showHUDWithMessage:(NSString *)message detailedMessage:(NSString *)subMsg
{
    if(hud != nil) {
        //self.hud will set to nil after being hidden
        return;
    }
    
    hud = [[MBProgressHUD alloc] initWithFrame:self.mapView.frame];
    hud.labelText = message;
    hud.detailsLabelText = subMsg;
    hud.removeFromSuperViewOnHide = YES;
    hud.delegate = self;
    [self.view addSubview:hud];
    [hud show:YES];
}

- (void)hudWasHidden
{
    hud.delegate = nil;
    hud = nil;
}

//--------------------------------------------------------------
//  [END] MBProgressHUDDelegate
//==============================================================

//==============================================================
//  [BEGIN] IBActions
#pragma mark - IBActions
//--------------------------------------------------------------
- (IBAction)removePin:(id)sender
{
    [self.mapView removeAnnotation:mapPin];
    currentLocation = nil;
    
    [editLocation setLocation:nil];
    
    self.removePinButton.hidden = YES;
    self.hintLabel.hidden = NO;
}
//--------------------------------------------------------------
//  [END] IBActions
//==============================================================

//==============================================================
//  [BEGIN] Private Methods
#pragma mark - Private Methods
//--------------------------------------------------------------
- (void)_saveLocation
{
    editLocation.name = self._nameField.text;
    editLocation.address = ([self._addressField.text length]==0) ? nil : self._addressField.text;
    [self.delegate finishEditingLocation:editLocation];
}

- (void)_cancelEditingLocation
{
    if([editLocation.objectID isTemporaryID]) {
        [CoreDataDatabase removeLocation:editLocation];
    }
    [CoreDataDatabase cancelUnsavedChanges];
    [self.delegate cancelEditingLocation];
}

- (void)_textFieldEndEditing:(UITextField *)textfield
{
    
}

- (void)_displayLocation:(CLLocation *)location animated:(BOOL)animate
{
    MKCoordinateRegion local;
    local.center.latitude = location.coordinate.latitude;
    local.center.longitude = location.coordinate.longitude;
    local.span.latitudeDelta = 0.01;
    local.span.longitudeDelta = 0.01;
    
    self.mapView.hidden = NO;
    self.hintView.hidden = NO;
    [self.mapView setRegion:local animated:animate];
}

- (void)_updatePinAnimated:(BOOL)animate
{
    [self.mapView deselectAnnotation:mapPin animated:NO];
    [self.mapView selectAnnotation:mapPin animated:animate];
}

- (void)_startToGetAddressFromLocation:(CLLocationCoordinate2D)coorinate
{
    [self _stopGettingAddress];

    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];

    self._addressField.text = nil;

    newGeoCoder = [[CLGeocoder alloc] init];
    CLLocation *locationData = [editLocation getLocation];
    [newGeoCoder reverseGeocodeLocation:locationData completionHandler:^(NSArray *placemarks, NSError *error) {
        for(CLPlacemark *placemark in placemarks) {
            //Hide country code
            [placemark.addressDictionary setValue:nil forKey:(NSString *)kABPersonAddressCountryKey];
            if([@"TW" isEqualToString:placemark.ISOcountryCode]) {
                [placemark.addressDictionary setValue:nil forKey:(NSString *)kABPersonAddressStateKey];
            }
            NSString *address = ABCreateStringWithAddressDictionary(placemark.addressDictionary, NO);
            self._addressField.text = address;
            editLocation.address = self._addressField.text;
            
            [self _updatePinAnimated:NO];  //Show address as subtitle
        }
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    }];
}

- (void)_replacePin
{
    [self.mapView removeAnnotation:mapPin];
    [self.mapView addAnnotation:mapPin];
}

- (void)_tapOnMap:(UITapGestureRecognizer *)sender
{
    if(sender.state != UIGestureRecognizerStateEnded) {
        return;
    }
    
    self.hintLabel.hidden = YES;
    self.removePinButton.hidden = NO;
    
    currentLocation = nil;
    [self _stopUpdatingLocation];

    CGPoint tapPoint = [sender locationInView:sender.view];
    CLLocationCoordinate2D tapCoordinate = [self.mapView convertPoint:tapPoint toCoordinateFromView:self.mapView];
    [editLocation setLocation:[[CLLocation alloc] initWithLatitude:tapCoordinate.latitude longitude:tapCoordinate.longitude]];
    
    editLocation.address = nil;
    
    //Update pin without animation
//    [mapPin setCoordinate:editLocation.locationData.coordinate];
//    
//    if([[self.mapView annotations] count] > 0) {
//        [self _updatePinAnimated:YES];
//    } else {
//        [self.mapView addAnnotation:mapPin];
//    }
    
    //Update pin with animation
    [self _replacePin];

    [self _startToGetAddressFromLocation:tapCoordinate];
}

- (void)_stopUpdatingLocation
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];

    @synchronized(self) {
        [hud hide:NO];

        locationManager.delegate = nil;
        [locationManager stopUpdatingLocation];
        self.mapView.showsUserLocation = NO;
        
        if(currentLocation) {
            [editLocation setLocation:currentLocation];
            [self _displayLocation:currentLocation animated:NO];
        }
        currentLocation = nil;
    }
}

- (void)_showError:(NSString *)errorMsg
{
    [hud hide:YES];
    self.mapView.hidden = YES;
    self.hintView.hidden = YES;
    self.errorLabel.text = errorMsg;
    self.errorLabel.hidden = NO;
}

- (void)_locateTimeout
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    if(currentLocation) {
        [self _stopUpdatingLocation];
    } else {
        locationManager.delegate = nil;
        [locationManager stopUpdatingLocation];
        
        [hud hide:NO];
        
        [self _showError:NSLocalizedString(@"Fail to get current location.", nil)];
    }
}

- (void)_checkNetworkStatus:(NSNotification *)notice
{
    // called after network status changes
    NetworkStatus internetStatus = [internetReachable currentReachabilityStatus];
    switch (internetStatus) {
        case NotReachable:
        {
            NSLog(@"The internet is down.");
            if(alertNetwork == nil) {
                alertNetwork = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Internet is down", nil)
                                                          message:NSLocalizedString(@"Turn on \"cellular data\" or use \"Wi-Fi\" to access data.", nil)
                                                         delegate:self
                                                cancelButtonTitle:NSLocalizedString(@"Settings", nil)
                                                otherButtonTitles:NSLocalizedString(@"OK", nil), nil];

                [alertNetwork show];
            }
            break;
        }
        case ReachableViaWiFi:
        {
            NSLog(@"The internet is working via WIFI.");
            if(alertNetwork) {
                //Press OK
                [alertNetwork dismissWithClickedButtonIndex:1 animated:YES];
            }
            break;
        }
        case ReachableViaWWAN:
        {
            NSLog(@"The internet is working via WWAN.");
            if(alertNetwork) {
                //Press OK
                [alertNetwork dismissWithClickedButtonIndex:1 animated:YES];
            }
            break;
        }
    }
    
    NetworkStatus hostStatus = [hostReachable currentReachabilityStatus];
    switch (hostStatus) {
        case NotReachable:
        {
            NSLog(@"A gateway to the host server is down.");
//            if(alertNetwork == nil) {
//                alertNetwork = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Network Error", nil)
//                                                          message:NSLocalizedString(@"Cannot access service from Google", nil)
//                                                         delegate:self
//                                                cancelButtonTitle:NSLocalizedString(@"OK", nil)
//                                                otherButtonTitles:nil];
//                [alertNetwork show];
//            }
            break;
        }
        case ReachableViaWiFi:
        {
            NSLog(@"A gateway to the host server is working via WIFI.");
            break;
        }
        case ReachableViaWWAN:
        {
            NSLog(@"A gateway to the host server is working via WWAN.");
            break;
        }
    }
}

//--------------------------------------------------------------
//  [END] Private Methods
//==============================================================
@end
