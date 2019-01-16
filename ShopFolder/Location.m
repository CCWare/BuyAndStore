//
//  Location.m
//  ShopFolder
//
//  Created by Michael on 2012/1/6.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "Location.h"

@implementation Location
@synthesize ID;
@synthesize name;
@synthesize locationData;
@synthesize address;
@synthesize nListPosition;

- (id)copyWithZone: (NSZone *)zone
{
    Location* cloneLocation = [[[self class] allocWithZone:zone] init];
    cloneLocation.ID = self.ID;
    cloneLocation.name = self.name;
    cloneLocation.locationData = self.locationData;
    cloneLocation.address = self.address;
    cloneLocation.nListPosition = self.nListPosition;

    return cloneLocation;
}

- (void) copyFrom:(Location *)source
{
    self.ID = source.ID;
    self.name = source.name;
    self.locationData = source.locationData;
    self.address = source.address;
    self.nListPosition = source.nListPosition;
}

@end
