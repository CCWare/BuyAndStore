//
//  DBLocation+SetAndGet.m
//  ShopFolder
//
//  Created by Michael on 2012/10/15.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBLocation+SetAndGet.h"

@implementation DBLocation (SetAndGet)
- (void)setLocation:(CLLocation *)location
{
    self.hasGeoInfo = (location != nil);
    if(location) {
        self.latitude = location.coordinate.latitude;
        self.longitude = location.coordinate.longitude;
        self.altitude = location.altitude;
        self.verticalAccuracy = location.verticalAccuracy;
        self.horizontalAccuracy = location.horizontalAccuracy;
    }
}

- (CLLocation *)getLocation
{
    if(!self.hasGeoInfo) {
        return nil;
    }
    
    CLLocationCoordinate2D coordinate;
    coordinate.longitude = self.longitude;
    coordinate.latitude = self.latitude;
    
    return [[CLLocation alloc] initWithCoordinate:coordinate
                                         altitude:self.altitude
                               horizontalAccuracy:self.horizontalAccuracy
                                 verticalAccuracy:self.verticalAccuracy
                                        timestamp:nil];
}
@end
