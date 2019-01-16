//
//  TimeUtil.h
//  ShopFolder
//
//  Created by Michael on 2011/10/06.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kDefaultRelativeTimeDescriptionRange    7   //days

@interface TimeUtil : NSObject {
    
}

+ (NSDate *)today;
+ (NSDate *)tomorrow;
+ (NSDate *)yesterday;
+ (NSDate *)dateFromToday: (int)days;
+ (NSDate *)dateFromString: (NSString *)string withFormat: (NSString *)format;
+ (NSDate *)dateOfYear: (int)yy month:(int)mm day:(int)dd;
+ (NSDate *)nextDayOfDate: (NSDate *)date;
+ (NSDate *)dateFromDate: (NSDate *)date inDays:(int)days;
+ (NSDate *)timeInDate: (NSDate *)date hour:(int)hr minute:(int)min second:(int)sec;
+ (int)yearOfDate: (NSDate *)date;
+ (int)monthOfDate: (NSDate *)date;
+ (int)dayOfDate: (NSDate *)date;
+ (NSString *)dateToString:(NSDate *)date inFormat:(NSString *)format;
+ (NSString *)dateToStringInCurrentLocale:(NSDate *)date;
+ (NSString *)dateToStringInCurrentLocale:(NSDate *)date dateStyle:(NSDateFormatterStyle)style;
+ (NSString *)stringFromHour:(int)hh minute:(int)mm;
+ (NSString *)timeToRelatedDescriptionFromNow:(NSDate *)date limitedRange:(int)days;

+ (int)daysBetweenDate:(NSDate *)date1 andDate:(NSDate *)date2;
+ (int)monthBetweenDate:(NSDate *)date1 andDate:(NSDate *)date2;

+ (NSDate *)thisWeekOfDate:(NSDate *)date;
+ (NSDate *)lastWeekOfDate:(NSDate *)date;
+ (NSDate *)nextWeekOfDate:(NSDate *)date;
+ (NSDate *)thisMonthOfDate:(NSDate *)date;
+ (NSDate *)lastMonthOfDate:(NSDate *)date;
+ (NSDate *)nextMonthOfDate:(NSDate *)date;
+ (NSDate *)thisYearOfDate:(NSDate *)date;
+ (NSDate *)nextYearOfDate:(NSDate *)date;

+ (BOOL)isExpired:(NSDate *)date;
+ (BOOL)isNearExpired:(NSDate *)expireDate nearExpiredDays:(int)day;
@end
