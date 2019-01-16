//
//  PickLocationViewController.m
//  ShopFolder
//
//  Created by Michael Tsai on 2012/01/16.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "PickLocationViewController.h"
#import "CoreDataDatabase.h"
#import "PreferenceConstant.h"
#import "FlurryAnalytics.h"
#import "VersionCompare.h"
#import <AddressBookUI/AddressBookUI.h>
#import "DBLocation+SetAndGet.h"

@interface PickLocationViewController ()
- (void)_enterEditMode;
- (void)_leaveEditMode;
- (void)_toggleEditMode:(BOOL)editing animated:(BOOL)animate;

- (void)_willShowKeyboard:(NSNotification *)notification;
- (void)_willHideKeyboard:(NSNotification *)notification;
- (void)_enableCancelButtonInSearchbar:(UISearchBar *)searchBar;

- (void)_addGeoInfoToLocation;
- (void)_editLocation:(DBLocation *)location;
- (void)_showAddButton:(BOOL)show animated:(BOOL)animate;
- (void)_doAddNewLocation:(DBLocation *)location;

- (void)_showHUDWithMessage:(NSString *)message detailedMessage:(NSString *)subMsg;
- (void)_stopUpdatingLocation;
- (void)_showLocateError;

- (void)_dismissSearchBarKeyboard;
@end

@implementation PickLocationViewController
@synthesize table;
@synthesize customizedSearchBar;
@synthesize delegate;
@synthesize searchBarColor;

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.table = nil;
    self.customizedSearchBar = nil;
    locationList = nil;
    displayList = nil;
    
    [self _leaveEditMode];
    editButton = nil;
    doneButton = nil;
    
    [hud hide:NO];
    hud.delegate = nil;
    hud = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    
    locationManager.delegate = nil;
    [locationManager stopUpdatingLocation];
    locationManager = nil;
}

- (void)dealloc
{
    [hud hide:NO];
    hud.delegate = nil;
    
    locationManager.delegate = nil;
    [locationManager stopUpdatingLocation];
    locationManager = nil;
}
#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    canUseGPS = ([CLLocationManager locationServicesEnabled] &&
                 [CLLocationManager authorizationStatus] != kCLAuthorizationStatusDenied);

    self.customizedSearchBar.placeholder = NSLocalizedString(@"Filter or add a new place", nil);
    self.table.allowsSelectionDuringEditing = YES;
    locationList = [NSMutableArray array];
    displayList = [NSMutableArray array];
    
    self.customizedSearchBar.text = searchToken;    //Recover from low memory
    [self _showAddButton:([self.customizedSearchBar.text length] > 0) animated:NO];
    
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    
    editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                               target:self
                                                               action:@selector(_enterEditMode)];
    self.navigationItem.rightBarButtonItem = editButton;
    
    if(self.searchBarColor) {
        self.customizedSearchBar.tintColor = self.searchBarColor;
    }
    
    //Detect and import locations
    NSString *countryCode = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    if([CoreDataDatabase shouldImportLocationsForCountry:countryCode]) {
        [CoreDataDatabase importLocationsInCountry:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
        [CoreDataDatabase commitChanges:nil];
    }
    
    locationList = [CoreDataDatabase getAllLocations];
    
    //Correct list positions
    [locationList sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        DBLocation *location1 = (DBLocation *)obj1;
        DBLocation *location2 = (DBLocation *)obj2;
        
        if(location1.listPosition < location2.listPosition) {
            return NSOrderedAscending;
        }
        
        if(location1.listPosition > location2.listPosition) {
            return NSOrderedDescending;
        }
        
        return NSOrderedSame;   //Should never happen
    }];
    
    DBLocation *location;
    BOOL hasConflict = NO;
    for(int nIndex = [locationList count]-1; nIndex >= 0; nIndex--) {
        location = [locationList objectAtIndex:nIndex];
        if(location.listPosition != nIndex) {
            hasConflict = YES;
            location.listPosition = nIndex;
        }
    }
    
    if(hasConflict) {
        [CoreDataDatabase commitChanges:nil];
    }
    
    [displayList addObjectsFromArray:locationList];
    
    [self.table reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.table deselectRowAtIndexPath:[self.table indexPathForSelectedRow] animated:NO];
    
    //Register notifications for keyboard show/hide (iOS 5 suooprts "change")
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_willShowKeyboard:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_willHideKeyboard:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [self _stopUpdatingLocation];
    [hud hide:NO];

    [super viewWillDisappear:animated];
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
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DBLocation *selectLocation = [displayList objectAtIndex:indexPath.row];
    editIndex = indexPath;

    if(self.table.editing) {
        [self _editLocation:selectLocation];
    } else {
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
            [FlurryAnalytics logEvent:@"Select place"
                       withParameters:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:([displayList count]==[locationList count])] 
                                                                  forKey:@"Filtered"]];
        }

        [self.delegate pickLocation:selectLocation];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return tableView.rowHeight;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self.customizedSearchBar resignFirstResponder];
    [self _enableCancelButtonInSearchbar:self.customizedSearchBar];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.customizedSearchBar resignFirstResponder];
    [self _enableCancelButtonInSearchbar:self.customizedSearchBar];
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
    static NSString *CellTableIdentitifier = @"LocationCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
    if(cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellTableIdentitifier];
    }

    DBLocation *location = [displayList objectAtIndex:indexPath.row];
    cell.textLabel.text = location.name;
    cell.detailTextLabel.text = location.address;
    
    if(self.delegate == nil &&
       !self.table.editing)
    {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [displayList count];
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(self.delegate == nil &&
       !self.table.editing)
    {
        [tableView cellForRowAtIndexPath:indexPath].selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        [tableView cellForRowAtIndexPath:indexPath].selectionStyle = UITableViewCellSelectionStyleBlue;
    }

    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(editingStyle == UITableViewCellEditingStyleDelete) {
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
            [FlurryAnalytics logEvent:@"Remove place"];
        }

        [tableView beginUpdates];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                         withRowAnimation:UITableViewRowAnimationFade];
        
        DBLocation *location = [displayList objectAtIndex:indexPath.row];
        [displayList removeObjectAtIndex:indexPath.row];
        [locationList removeObject:location];
        [CoreDataDatabase removeLocation:location];
        [CoreDataDatabase commitChanges:nil];

        [tableView endUpdates];
    } else {
        
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    //Cannot reorder list when filtered
    if([displayList count] != [locationList count]) {
        return NO;
    }

    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    DBLocation *movedLocation = [displayList objectAtIndex:sourceIndexPath.row];
    [CoreDataDatabase moveLocation:movedLocation to:destinationIndexPath.row];

    //Sync position
    [displayList removeObject:movedLocation];
    [displayList insertObject:movedLocation atIndex:destinationIndexPath.row];
    
    [locationList removeObject:movedLocation];
    [locationList insertObject:movedLocation atIndex:destinationIndexPath.row];
}

//--------------------------------------------------------------
//  [END] UITableViewDataSource
//==============================================================

//==============================================================
//  [BEGIN] UISearchBarDelegate
#pragma mark - UISearchBarDelegate
//--------------------------------------------------------------
- (void)_enableCancelButtonInSearchbar:(UISearchBar *)searchBar
{
    for(UIView *view in [searchBar subviews]) {
        if([view isKindOfClass:[UIButton class]]) {
            ((UIButton *)view).enabled = YES;
            break;
        }
    }
}

- (void)_dismissSearchBarKeyboard
{
    [self.customizedSearchBar resignFirstResponder];
    [self _enableCancelButtonInSearchbar:self.customizedSearchBar];

    [displayList removeAllObjects];
    [displayList addObjectsFromArray:locationList];
    [self.table reloadData];
    
    [self _showAddButton:NO animated:YES];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if([searchText length] == 0) { //User press "Clear" button or clears all text
        [self _dismissSearchBarKeyboard];
    } else {
        searchToken = searchText;
        
        [displayList removeAllObjects];
        for(DBLocation *location in locationList) {
            if(([location.name length] > 0 && [location.name rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) ||
               ([location.address length] > 0 && [location.address rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound))
            {
                [displayList addObject:location];
            }
        }
        
        [self.table reloadData];
        [self _showAddButton:YES animated:YES];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];

    if([searchBar.text length] > 0) {
        UIActionSheet *askForLocationSheet;
        if(canUseGPS) {
            askForLocationSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Add More Information?", nil)
                                                              delegate:self
                                                     cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                destructiveButtonTitle:nil
                                                     otherButtonTitles:NSLocalizedString(@"Add Map/Address", nil),
                                                                       NSLocalizedString(@"Current Location", nil),
                                                                       NSLocalizedString(@"Name Only", @"Just add place without location"),
                                                                       nil];
        } else {
            askForLocationSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Add More Information?", nil)
                                                              delegate:self
                                                     cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                destructiveButtonTitle:nil
                                                     otherButtonTitles:NSLocalizedString(@"Add Address", nil),
                                                                       NSLocalizedString(@"Name Only", @"Just add place without location"),
                                                                       nil];
        }
                                                                         
        [askForLocationSheet showInView:self.view];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    //User presses "Search" on keybaord
    [searchBar resignFirstResponder];
    [self _enableCancelButtonInSearchbar:self.customizedSearchBar];
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    [self _showAddButton:([searchBar.text length] > 0) animated:YES];
    return YES;
}
//--------------------------------------------------------------
//  [END] UISearchBarDelegate
//==============================================================

//==============================================================
//  [BEGIN] EditLocationViewControllerDelegate
#pragma mark - EditLocationViewControllerDelegate
//--------------------------------------------------------------
- (void)finishEditingLocation:(DBLocation *)location
{
    [self dismissModalViewControllerAnimated:YES];

    if([location.objectID isTemporaryID]) {
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
            [FlurryAnalytics logEvent:@"Add place"
                       withParameters:[NSDictionary dictionaryWithObject:@"Map" 
                                                                  forKey:@"Source"]];
        }

        [self _doAddNewLocation:location];
    } else {
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
            [FlurryAnalytics logEvent:@"Update place from map"];
        }

        [CoreDataDatabase commitChanges:nil];
        [self.table beginUpdates];
        [self.table reloadRowsAtIndexPaths:[NSArray arrayWithObject:editIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
        [self.table endUpdates];
    }
}

- (void)cancelEditingLocation
{
    [self dismissModalViewControllerAnimated:YES];
}
//--------------------------------------------------------------
//  [END] EditLocationViewControllerDelegate
//==============================================================

//==============================================================
//  [BEGIN] UIActionSheetDelegate
#pragma mark - UIActionSheetDelegate
//--------------------------------------------------------------
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    self.customizedSearchBar.text = nil;
    [self _dismissSearchBarKeyboard];

    if(actionSheet.cancelButtonIndex == buttonIndex) {
        return;
    }
    
    switch (buttonIndex) {
        case 0:
            [self _addGeoInfoToLocation];
            break;
        case 1:
            if(canUseGPS) {
                if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                    [FlurryAnalytics logEvent:@"Add place"
                               withParameters:[NSDictionary dictionaryWithObject:@"Current Location" 
                                                                          forKey:@"Source"]];
                }

                [self _showHUDWithMessage:NSLocalizedString(@"Getting current location...", nil) detailedMessage:nil];
                self.navigationItem.rightBarButtonItem.enabled = NO;
                
                currentLocation = nil;
                locationManager.delegate = self;
                [locationManager startUpdatingLocation];
                
                [self performSelector:@selector(_showLocateError) withObject:nil afterDelay:20];
            } else {
                if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                    [FlurryAnalytics logEvent:@"Add place"
                               withParameters:[NSDictionary dictionaryWithObject:@"Current Location(No GPS)" 
                                                                          forKey:@"Source"]];
                }

                DBLocation *location = [CoreDataDatabase obtainLocation];
                location.listPosition = 0;
                location.name = searchToken;
                [location setLocation:currentLocation];
                [self _doAddNewLocation:location];
            }

            break;
        case 2:
            if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                [FlurryAnalytics logEvent:@"Add place"
                           withParameters:[NSDictionary dictionaryWithObject:@"Name Only" 
                                                                      forKey:@"Source"]];
            }

            {
                DBLocation *location = [CoreDataDatabase obtainLocation];
                location.listPosition = 0;
                location.name = searchToken;
                [location setLocation:currentLocation];
                [self _doAddNewLocation:location];
            }
            break;
        default:
            break;
    }
}
//--------------------------------------------------------------
//  [END] UIActionSheetDelegate
//==============================================================

//==============================================================
//  [BEGIN] MBProgressHUDDelegate
#pragma mark - MBProgressHUDDelegate
//--------------------------------------------------------------
- (void)_showHUDWithMessage:(NSString *)message detailedMessage:(NSString *)subMsg
{
    [hud hide:NO];  //Remove last HUD
    
    hud = [[MBProgressHUD alloc] initWithView:self.view];
    hud.labelText = message;
    hud.detailsLabelText = subMsg;
    hud.removeFromSuperViewOnHide = YES;
    hud.delegate = self;
    [self.view addSubview:hud];
    [hud show:YES];
}

- (void)hudWasHidden
{
    hud = nil;
}
//--------------------------------------------------------------
//  [END] MBProgressHUDDelegate
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        hud.detailsLabelText = [NSString stringWithFormat:NSLocalizedString(@"Accuracy: %.2fM", nil), newLocation.horizontalAccuracy];
    });

    if(currentLocation == nil ||
       currentLocation.horizontalAccuracy > newLocation.horizontalAccuracy)
    {
        NSLog(@"Get location, recent %f, accuracy: %f", howRecent, newLocation.horizontalAccuracy);
        currentLocation = newLocation;
        
        if(newLocation.horizontalAccuracy <= locationManager.desiredAccuracy) {
            NSLog(@"Reach desired accuracy");
            [self _stopUpdatingLocation];

            //Save location to database
            DBLocation *location = [CoreDataDatabase obtainLocation];
            location.listPosition = 0;
            location.name = searchToken;
            [location setLocation:currentLocation];
            [self _doAddNewLocation:location];
            
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            dispatch_async(dispatch_get_main_queue(), ^{
                hud.labelText = NSLocalizedString(@"Getting address...", nil);
                hud.detailsLabelText = @"";
            });

            CLGeocoder *geoCoder = [[CLGeocoder alloc] init];
            [geoCoder reverseGeocodeLocation:currentLocation completionHandler:^(NSArray *placemarks, NSError *error) {
                for(CLPlacemark *placemark in placemarks) {
                    [self.table beginUpdates];
                    
                    //Hide country code
                    [placemark.addressDictionary setValue:nil forKey:(NSString *)kABPersonAddressCountryKey];
                    if([@"TW" isEqualToString:placemark.ISOcountryCode]) {
                        [placemark.addressDictionary setValue:nil forKey:(NSString *)kABPersonAddressStateKey];
                    }
                    
                    NSString *address = ABCreateStringWithAddressDictionary(placemark.addressDictionary, NO);
                    if([locationList count] > 0) {
                        DBLocation *location = [locationList objectAtIndex:0];
                        location.address = address;
                        
                        if([CoreDataDatabase commitChanges:nil]) {
                            UITableViewCell *cell = [self.table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
                            cell.detailTextLabel.text = address;
                            [self.table reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]]
                                              withRowAnimation:UITableViewRowAnimationNone];
                            [self.table endUpdates];
                        }
                    }
                }
                
                [hud hide:YES];
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                
                self.navigationItem.rightBarButtonItem.enabled = YES;
            }];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [self _showLocateError];
}
//--------------------------------------------------------------
//  [END] CLLocationManagerDelegate
//==============================================================

//==============================================================
//  [BEGIN] UIAlertViewDelegate
#pragma mark - UIAlertViewDelegate
//--------------------------------------------------------------
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == alertView.cancelButtonIndex) {
        return;
    }
    
    //Use name only
    DBLocation *location = [CoreDataDatabase obtainLocation];
    location.listPosition = 0;
    location.name = searchToken;
    [self _doAddNewLocation:location];
}
//--------------------------------------------------------------
//  [END] UIAlertViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] Private methods
#pragma mark - Private methods
//--------------------------------------------------------------
- (void)_enterEditMode
{
    if(!doneButton) {
        doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                   target:self
                                                                   action:@selector(_leaveEditMode)];
    }
    
    self.navigationItem.rightBarButtonItem = doneButton;
    [self _toggleEditMode:YES animated:YES];
}

- (void)_leaveEditMode
{
    self.navigationItem.rightBarButtonItem = editButton;
    [self _toggleEditMode:NO animated:YES];
}

- (void)_toggleEditMode:(BOOL)editing animated:(BOOL)animate
{
    [self.table setEditing:editing animated:animate];
}

- (void)_willShowKeyboard:(NSNotification *)notification
{
    //1. Get keyboard frame
    CGRect keyboardFrame = ((NSValue *)[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey]).CGRectValue;
    double animDuration = [((NSNumber *)[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey]) doubleValue];
    
    //2. Adjust frame
    CGRect tableFrame = self.table.frame;
    tableFrame.size.height = [[UIScreen mainScreen] bounds].size.height - 44.0f - [[UIApplication sharedApplication] statusBarFrame].size.height - keyboardFrame.size.height;
    [UIView animateWithDuration:animDuration
                     animations:^{
                         self.table.frame = tableFrame;
                     }];
}

- (void)_willHideKeyboard:(NSNotification *)notification
{
    double animDuration = [((NSNumber *)[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey]) doubleValue];
    
    //2. Adjust frame
    CGRect tableFrame = self.table.frame;
    tableFrame.size.height = [[UIScreen mainScreen] bounds].size.height - 44.0f - [[UIApplication sharedApplication] statusBarFrame].size.height;
    [UIView animateWithDuration:animDuration
                     animations:^{
                         self.table.frame = tableFrame;
                     }];
}

- (void)_addGeoInfoToLocation
{
    EditLocationViewController *addVC = [[EditLocationViewController alloc] initToAddNewLocationWithName:searchToken];
    addVC.delegate = self;
    
    UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:addVC];
    [self presentModalViewController:navCon animated:YES];
}

- (void)_editLocation:(DBLocation *)location
{
    EditLocationViewController *editVC = [[EditLocationViewController alloc] initToEditLocation:location];
    editVC.delegate = self;
    
    UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:editVC];
    [self presentModalViewController:navCon animated:YES];
}

- (void)_showAddButton:(BOOL)show animated:(BOOL)animate
{
    [self.customizedSearchBar setShowsCancelButton:show animated:animate];

    if(show) {
        for(UIView *view in [self.customizedSearchBar subviews]) {
            if([view isKindOfClass:[UIButton class]]) {
                //addButton = view; //Cannot cache the button since it may be newed everytime appears
                [(UIButton *)view setTitle:NSLocalizedString(@"Add", @"Used when add a location") forState:UIControlStateNormal];  //must set after showing the button
                break;
            }
        }
    }
}

- (void)_stopUpdatingLocation
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];

    @synchronized(self) {
        locationManager.delegate = nil;
        [locationManager stopUpdatingLocation];
    }
}

- (void)_doAddNewLocation:(DBLocation *)location
{
    for(DBLocation *location in locationList) {
        location.listPosition++;
    }
    [CoreDataDatabase commitChanges:nil];
    
    if(self.delegate) {
        [self.delegate pickLocation:location];
    } else {
        [self.table scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
        
        [displayList insertObject:location atIndex:0];
        [locationList insertObject:location atIndex:0];
        [self.table beginUpdates];
        [self.table insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.table endUpdates];
    }
}

- (void)_showLocateError
{
    [self _stopUpdatingLocation];
    [hud hide:NO];

    UIAlertView *alertLocation = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Fail to locate", nil)
                                                            message:NSLocalizedString(@"Use name only?", nil)
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"No", nil)
                                                  otherButtonTitles:NSLocalizedString(@"Yes", nil), nil];
    [alertLocation show];
    
    self.navigationItem.rightBarButtonItem.enabled = YES;
}

- (void)_applicationDidBecomeActive
{
    //User may turn on GPS setting and return to this app
    canUseGPS = ([CLLocationManager locationServicesEnabled] &&
                 [CLLocationManager authorizationStatus] != kCLAuthorizationStatusDenied);
}
//--------------------------------------------------------------
//  [END] Private methods
//==============================================================
@end
