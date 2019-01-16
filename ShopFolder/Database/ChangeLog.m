//
//  ChangeLog.m
//  ShopFolder
//
//  Created by Michael on 2012/11/23.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "ChangeLog.h"

@implementation ChangeLog
@synthesize time;
@synthesize log;

- (id)initWithTime:(NSDate *)aTime log:(NSString *)aLog
{
    if((self = [super init])) {
        self.time = aTime;
        self.log = aLog;
    }
    
    return self;
}
@end
