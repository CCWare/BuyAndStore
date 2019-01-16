//
//  MapAnnotation.h
//  ShopFolder
//
//  Created by Michael Tsai on 2012/01/21.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import "DBLocation.h"

@interface MapAnnotation : NSObject <MKAnnotation>

@property (nonatomic, strong) DBLocation *location;

- (id)initWithLocation:(DBLocation *)newLocation;
@end
