//
//  MapAnnotation.m
//  ShopFolder
//
//  Created by Michael Tsai on 2012/01/21.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "MapAnnotation.h"
#import "DBLocation+SetAndGet.h"

@implementation MapAnnotation
@synthesize location;

- (id)initWithLocation:(DBLocation *)newLocation
{
    if((self = [super init])) {
        self.location = newLocation;
    }
    
    return self;
}

- (CLLocationCoordinate2D)coordinate
{
    return [self.location getLocation].coordinate;
}

- (void)setCoordinate:(CLLocationCoordinate2D)newCoordinate
{
    self.location.latitude = newCoordinate.latitude;
    self.location.longitude = newCoordinate.longitude;
}

- (NSString *)title
{
    return self.location.name;
}

- (NSString *)subtitle
{
    return self.location.address;
}
@end
