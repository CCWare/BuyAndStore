//
//  DBLocation+SetAndGet.h
//  ShopFolder
//
//  Created by Michael on 2012/10/15.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBLocation.h"
#import <CoreLocation/CoreLocation.h>

@interface DBLocation (SetAndGet)
- (void)setLocation:(CLLocation *)location;
- (CLLocation *)getLocation;
@end
