//
//  ChangeLog.h
//  ShopFolder
//
//  Created by Michael on 2012/11/23.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ChangeLog : NSObject
{
    NSDate *time;
    NSString *log;
}

@property (nonatomic, strong) NSDate *time;
@property (nonatomic, strong) NSString *log;

- (id)initWithTime:(NSDate *)aTime log:(NSString *)aLog;

@end
