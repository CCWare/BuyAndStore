//
//  Location.h
//  ShopFolder
//
//  Created by Michael on 2012/1/6.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface Location : NSObject
{
    int ID;
    NSString *name;
    CLLocation *locationData;
    NSString *address;
    
    int nListPosition;
}

@property (nonatomic, assign) int ID;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) CLLocation *locationData;
@property (nonatomic, strong) NSString *address;
@property (nonatomic, assign) int nListPosition;

- (void) copyFrom:(Location *)source;
@end
