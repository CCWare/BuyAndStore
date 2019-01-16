//
//  TimeUtil.m
//  ShopFolder
//
//  Created by Michael on 2011/10/06.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import "TimeUtil.h"
#import "PreferenceConstant.h"

#define kSecondsPerDay  86400

@implementation TimeUtil

+(NSDate *)today
{
    return [TimeUtil timeInDate:[NSDate date] hour:0 minute:0 second:0];
}

+ (NSDate *)tomorrow
{
    return [TimeUtil dateFromToday:1];
}

+ (NSDate *)yesterday
{
    return [TimeUtil dateFromToday:-1];
}

+ (NSDate *)dateFromToday: (int)days
{
    NSDate *today = [TimeUtil today];
    
    NSDateComponents *comps =[[NSDateComponents alloc] init];
    [comps setDay:days];

    NSDate *date = [[NSCalendar currentCalendar] dateByAddingComponents:comps toDate:today options:0];
    return date;
}

+ (NSDate *)dateFromString: (NSString *)string withFormat: (NSString *)format
{
    if(!string || !format) {
        return nil;
    }

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:format];
    NSDate *date = [dateFormatter dateFromString:string];
    
    return date;
}

+ (NSDate *)dateOfYear: (int)yy month:(int)mm day:(int)dd
{
    NSDateComponents *comps =[[NSDateComponents alloc] init];
    [comps setYear:yy];
    [comps setMonth:mm];
    [comps setDay:dd];
    NSDate *date = [[NSCalendar currentCalendar] dateFromComponents:comps];
    
    return date;
}

+ (NSDate *)nextDayOfDate: (NSDate *)date
{
    if(!date) {
        return nil;
    }

    return [TimeUtil dateFromDate:date inDays:1];
}

+ (NSDate *)dateFromDate: (NSDate *)date inDays:(int)days
{
    if(!date) {
        return nil;
    }

    NSDateComponents *comps = [[NSDateComponents alloc] init];
    [comps setDay:days];
    NSDate *newDate = [[NSCalendar currentCalendar] dateByAddingComponents:comps
                                                                 toDate:[TimeUtil timeInDate:date hour:0 minute:0 second:0]
                                                                options:0];
    return newDate;
}

+ (NSDate *)timeInDate: (NSDate *)date hour:(int)hr minute:(int)min second:(int)sec
{
    if(!date) {
        return nil;
    }

    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *comps = [cal components:(NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit)
                                     fromDate:date];

    [comps setHour:hr];
    [comps setMinute:min];
    [comps setSecond:sec];
    return [cal dateFromComponents:comps];
}

+ (NSDate *)thisWeekOfDate:(NSDate *)date
{
    if(!date) {
        return nil;
    }
    
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *result = nil;
    [cal rangeOfUnit:NSWeekCalendarUnit startDate:&result interval:NULL forDate:date];
    return result;
}

+ (NSDate *)lastWeekOfDate:(NSDate *)date
{
    if(!date) {
        return nil;
    }
    
    return [self dateFromDate:[self thisWeekOfDate:date] inDays:-7];
}

+ (NSDate *)nextWeekOfDate:(NSDate *)date
{
    if(!date) {
        return nil;
    }
    
    return [self dateFromDate:[self thisWeekOfDate:date] inDays:7];
}

+ (NSDate *)thisMonthOfDate:(NSDate *)date
{
    if(!date) {
        return nil;
    }
    
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *result = nil;
    [cal rangeOfUnit:NSMonthCalendarUnit startDate:&result interval:NULL forDate:date];
    return result;
}

+ (NSDate *)lastMonthOfDate:(NSDate *)date
{
    if(!date) {
        return nil;
    }
    
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *comps = [cal components:NSYearCalendarUnit | NSMonthCalendarUnit fromDate:date];
    if([comps month] > 1) {
        [comps setMonth:[comps month] - 1];
    } else {
        [comps setMonth:12];
        [comps setYear:[comps year] - 1];
    }
    
    return [cal dateFromComponents:comps];
}

+ (NSDate *)nextMonthOfDate:(NSDate *)date
{
    if(!date) {
        return nil;
    }
    
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *comps = [cal components:NSYearCalendarUnit | NSMonthCalendarUnit fromDate:date];
    if([comps month] < 12) {
        [comps setMonth:([comps month] + 1)];
    } else {
        [comps setMonth:1];
        [comps setYear:([comps year] + 1)];
    }
    
    return [cal dateFromComponents:comps];
}

+ (NSDate *)thisYearOfDate:(NSDate *)date
{
    if(!date) {
        return nil;
    }
    
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *result = nil;
    [cal rangeOfUnit:NSYearCalendarUnit startDate:&result interval:NULL forDate:date];
    return result;
}

+ (NSDate *)nextYearOfDate:(NSDate *)date
{
    if(!date) {
        return nil;
    }
    
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *comps = [cal components:NSYearCalendarUnit fromDate:date];
    [comps setYear:([comps year] + 1)];
    
    return [cal dateFromComponents:comps];
}

+ (int)yearOfDate: (NSDate *)date
{
    if(!date) {
        return 0;
    }

    return [[[NSCalendar currentCalendar] components:NSYearCalendarUnit fromDate:date] year];
}
+ (int)monthOfDate: (NSDate *)date
{
    if(!date) {
        return 0;
    }

    return [[[NSCalendar currentCalendar] components:NSMonthCalendarUnit fromDate:date] month];
}
+ (int)dayOfDate: (NSDate *)date
{
    if(!date) {
        return 0;
    }

    return [[[NSCalendar currentCalendar] components:NSDayCalendarUnit fromDate:date] day];
}

+ (NSString *)dateToString:(NSDate *)date inFormat:(NSString *)format
{
    if(!date) {
        return nil;
    }
    
//    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    static NSDateFormatter *dateFormatter = nil;
    if(dateFormatter == nil) {
        dateFormatter = [[NSDateFormatter alloc] init];
    }

    [dateFormatter setDateFormat:format];
    NSString *strDate = [dateFormatter stringFromDate:date];
    
    return strDate;
}

+ (NSString *)dateToStringInCurrentLocale:(NSDate *)date dateStyle:(NSDateFormatterStyle)style
{
    if(date == nil) {
        return nil;
    }
    
    //    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    static NSDateFormatter *dateFormatter = nil;
    if(dateFormatter == nil) {
        dateFormatter = [[NSDateFormatter alloc] init];
    }
    
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    [dateFormatter setDateStyle:style];
    [dateFormatter setLocale:[NSLocale currentLocale]];
    
    NSString *strDate = [dateFormatter stringFromDate:date];
    return strDate;
}

+ (NSString *)dateToStringInCurrentLocale:(NSDate *)date
{
    return [self dateToStringInCurrentLocale:date dateStyle:NSDateFormatterMediumStyle];
}

+ (NSString *)stringFromHour:(int)hh minute:(int)mm
{
    NSString *strTime;
//    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    static NSDateFormatter *dateFormatter = nil;
    if(dateFormatter == nil) {
        dateFormatter = [[NSDateFormatter alloc] init];
    }

    [dateFormatter setLocale:[NSLocale currentLocale]];
    [dateFormatter setDateFormat:@"h:mm a"];
    NSDate *date = [TimeUtil timeInDate:[NSDate date] hour:hh minute:mm second:0];
    strTime = [dateFormatter stringFromDate:date];
    return strTime;
}

+ (NSString *)timeToRelatedDescriptionFromNow:(NSDate *)date limitedRange:(int)days
{
    NSDate *now = [NSDate date];
    
    if(days != 0 &&
       abs([self daysBetweenDate:date andDate:now]) >= abs(days))
    {
        return [self dateToStringInCurrentLocale:date];
    }
    
    NSString *description = nil;
    NSTimeInterval dateFromNow = [date timeIntervalSinceDate:now];
    if(dateFromNow < 0) {   //For the time before now:
        //0 ~ 1 hour: "Just now"
        /*
        if(dateFromNow > -7200) {    //60*60*2
            return NSLocalizedString(@"Just now", @"Related time description");
        }
        //2 ~ 8 Hours: "N hours ago"
        else if(dateFromNow > -28800) {  //60*60*8
            return [NSString stringWithFormat:NSLocalizedString(@"%d hours ago", @"Related time description"), dateFromNow/(3600.0f)];
        }
        //8+ but in today: "Today"
        else */
        if([date compare:[TimeUtil today]] == NSOrderedSame) {
            return NSLocalizedString(@"Today", @"Related time description");
        } else if([date compare:[TimeUtil today]] != NSOrderedAscending) {
            NSCalendar *calendar = [NSCalendar currentCalendar];
            NSDateComponents *components = [calendar components:(NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:date];
            NSInteger hour = [components hour];
            NSInteger minute = [components minute];
            return [self stringFromHour:hour minute:minute]; //NSLocalizedString(@"Today", @"Related time description");
        }
        //Yesterday: "Yesterday"
        else if([date compare:[TimeUtil yesterday]] != NSOrderedAscending) {
            return NSLocalizedString(@"Yesterday", @"Related time description");
        }
        //More than one day and in this week: "Saunday, Monday,..."
        else if([date compare:[TimeUtil thisWeekOfDate:now]] != NSOrderedAscending) {
            int daysIsThisWeek = [TimeUtil daysBetweenDate:[TimeUtil thisWeekOfDate:now] andDate:date];
            switch (daysIsThisWeek) {
                case 0:
                    return NSLocalizedString(@"Sunday", nil);
                case 1:
                    return NSLocalizedString(@"Monday", nil);
                case 2:
                    return NSLocalizedString(@"Tuesday", nil);
                case 3:
                    return NSLocalizedString(@"Wednesday", nil);
                case 4:
                    return NSLocalizedString(@"Thursday", nil);
                case 5:
                    //Should never comes here
                    return NSLocalizedString(@"Friday", nil);
                case 6:
                    //Should never comes here
                    return NSLocalizedString(@"Saturday", nil);
                default:
                    break;
            }
        }
        //More than one day and in last week: "Last week"
        else if([date compare:[TimeUtil lastWeekOfDate:now]] != NSOrderedAscending) {
            int daysIsThisWeek = [TimeUtil daysBetweenDate:[TimeUtil lastWeekOfDate:now] andDate:date];
            switch (daysIsThisWeek) {
                case 0:
                    return NSLocalizedString(@"Last Sunday", nil);
                case 1:
                    return NSLocalizedString(@"Last Monday", nil);
                case 2:
                    return NSLocalizedString(@"Last Tuesday", nil);
                case 3:
                    return NSLocalizedString(@"Last Wednesday", nil);
                case 4:
                    return NSLocalizedString(@"Last Thursday", nil);
                case 5:
                    return NSLocalizedString(@"Last Friday", nil);
                case 6:
                    return NSLocalizedString(@"Last Saturday", nil);
                default:
                    break;
            }
        }
        //More than one week and in this month: "Beginning of this month, Middle of this month"
        else if([date compare:[TimeUtil thisMonthOfDate:now]] != NSOrderedAscending) {
            int daysinThisMonth = [TimeUtil daysBetweenDate:[TimeUtil thisMonthOfDate:now] andDate:date];
            if(daysinThisMonth < 10) {
                return NSLocalizedString(@"Early this month", nil);
            } else if(daysinThisMonth < 20) {
                return NSLocalizedString(@"Middle this month", nil);
            } else {
                return NSLocalizedString(@"Earlier this month", nil);
            }
        }
        //More than one week and in last month: "Beginning of XXX, Middle of XXX, End of XXX", XX is the name of the month
        else if([date compare:[TimeUtil lastMonthOfDate:now]] != NSOrderedAscending) {
            int daysinThisMonth = [TimeUtil daysBetweenDate:[TimeUtil lastMonthOfDate:now] andDate:date];
            if(daysinThisMonth < 10) {
                return NSLocalizedString(@"Early last month", nil);
            } else if(daysinThisMonth < 20) {
                return NSLocalizedString(@"Middle last month", nil);
            } else {
                return NSLocalizedString(@"Late last month", nil);
            }
        }
        else {
            //Before last month but within one year: "N months ago"
            int months = [TimeUtil monthBetweenDate:date andDate:now];
            if(months <= 12) {
                return [NSString stringWithFormat:NSLocalizedString(@"%d months ago", nil), months];
            }
            //More than one year: "N year(s) M month(s) ago"
            else {
                int nYear = months/12;
                months = months % 12;
                NSMutableString *yearAndMonthString = [NSMutableString string];
                if(nYear  == 1) {
                    [yearAndMonthString appendString:NSLocalizedString(@"1 year ", nil)];
                } else {
                    [yearAndMonthString appendFormat:NSLocalizedString(@"%d years ", nil), nYear];
                }
                
                if(months > 0) {
                    if(months  == 1) {
                        [yearAndMonthString appendString:NSLocalizedString(@"1 month ", nil)];
                    } else {
                        [yearAndMonthString appendFormat:NSLocalizedString(@"%d months ", nil), months];
                    }
                }
                
                [yearAndMonthString appendString:NSLocalizedString(@"ago", nil)];
                
                return yearAndMonthString;
            }
        }
    } else {    //For the time after now:
        //In today: "Later"
        NSDate *tomorrow = [TimeUtil tomorrow];
        int daysDiff = 0;
        if([date compare:tomorrow] == NSOrderedAscending) {
//            return NSLocalizedString(@"Later today", nil);
            NSCalendar *calendar = [NSCalendar currentCalendar];
            NSDateComponents *components = [calendar components:(NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:date];
            NSInteger hour = [components hour];
            NSInteger minute = [components minute];
            return [self stringFromHour:hour minute:minute];
        }
        //Tomorrow: "Tomorrow"
        else if([date compare:[TimeUtil dateFromDate:tomorrow inDays:1]] == NSOrderedAscending) {
            return NSLocalizedString(@"Tomorrow", nil);
        }
        //More than one day and in this week: "Sunday, Monday..."
        else if((daysDiff = [TimeUtil daysBetweenDate:[TimeUtil thisWeekOfDate:now] andDate:date]) <= 7) {  //includes next Sunday
            switch (daysDiff) {
                case 0:
                    //Should never comes here, it'll goest to case 7
                    break;
                case 1:
                    //Should never comes here, it'll goest to "Next Monday"
                    break;
                case 2:
                    return NSLocalizedString(@"Tuesday", nil);
                case 3:
                    return NSLocalizedString(@"Wednesday", nil);
                case 4:
                    return NSLocalizedString(@"Thursday", nil);
                case 5:
                    return NSLocalizedString(@"Friday", nil);
                case 6:
                    return NSLocalizedString(@"Saturday", nil);
                case 7:
                    return NSLocalizedString(@"Sunday", nil);
                default:
                    break;
            }
        }
        //More than one day and in next week: "Next Sunday, Next Monday..."
        else if((daysDiff = [TimeUtil daysBetweenDate:[TimeUtil nextWeekOfDate:now] andDate:date]) < 7) {
            switch (daysDiff) {
                case 0:
                    //Should never comes here, it'll goest to "Sunday before"
                    break;
                case 1:
                    return NSLocalizedString(@"Next Monday", nil);
                case 2:
                    return NSLocalizedString(@"Next Tuesday", nil);
                case 3:
                    return NSLocalizedString(@"Next Wednesday", nil);
                case 4:
                    return NSLocalizedString(@"Next Thursday", nil);
                case 5:
                    return NSLocalizedString(@"Next Friday", nil);
                case 6:
                    return NSLocalizedString(@"Next Saturday", nil);
                default:
                    break;
            }
        }
        //More than next week and in the same month: "Later this month", "Middle this month", "Late this month"
        else if([date compare:[TimeUtil nextMonthOfDate:now]] == NSOrderedAscending) {
            int daysinThisMonth = [TimeUtil daysBetweenDate:[TimeUtil thisMonthOfDate:now] andDate:date];
            if(daysinThisMonth < 10) {
                return NSLocalizedString(@"Later this month", nil);
            } else if(daysinThisMonth < 20) {
                return NSLocalizedString(@"Middle this month", nil);
            } else {
                return NSLocalizedString(@"Late this month", nil);
            }
        }
        //More than next week and in next month: "Next month"
        else if([date compare:[TimeUtil nextMonthOfDate:[TimeUtil nextMonthOfDate:now]]] == NSOrderedAscending) {
            return NSLocalizedString(@"Next month", nil);
        } else {
            int months = [TimeUtil monthBetweenDate:now andDate:date];
            if(months < 12) {
                return [NSString stringWithFormat:NSLocalizedString(@"%d months later", nil), months];
            }
            //More than one year: "N year(s) M month(s) ago"
            else {
                int nYear = months/12;
                months = months % 12;
                NSMutableString *yearAndMonthString = [NSMutableString string];
                if(nYear  == 1) {
                    [yearAndMonthString appendString:NSLocalizedString(@"1 year ", nil)];
                } else {
                    [yearAndMonthString appendFormat:NSLocalizedString(@"%d years ", nil), nYear];
                }
                
                if(months > 0) {
                    if(months  == 1) {
                        [yearAndMonthString appendString:NSLocalizedString(@"1 month ", nil)];
                    } else {
                        [yearAndMonthString appendFormat:NSLocalizedString(@"%d months ", nil), months];
                    }
                }
                
                [yearAndMonthString appendString:NSLocalizedString(@"later", nil)];
                return yearAndMonthString;
            }
        }
        //More than next month but within a year: "N months later"
        //More than a year: "N year(s) M month(s) later"
    }
    
    return description;
}

+ (int)daysBetweenDate:(NSDate *)date1 andDate:(NSDate *)date2
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *difference = [calendar components:NSDayCalendarUnit
                                               fromDate:date1
                                                 toDate:date2
                                                options:0];
    
    return [difference day];
}

+ (int)monthBetweenDate:(NSDate *)date1 andDate:(NSDate *)date2
{
    NSDate *fromDate;
    NSDate *toDate;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    [calendar rangeOfUnit:NSDayCalendarUnit
                startDate:&fromDate
                 interval:NULL forDate:date1];
    [calendar rangeOfUnit:NSDayCalendarUnit
                startDate:&toDate
                 interval:NULL forDate:date2];
    
    NSDateComponents *monthDifference = [calendar components:NSMonthCalendarUnit|NSDayCalendarUnit
                                                   fromDate:fromDate
                                                     toDate:toDate
                                                    options:0];
    int month = [monthDifference month];
    if([monthDifference day] > 0) {
        month++;
    }
    return month;
}

+ (BOOL)isExpired:(NSDate *)date
{
    NSTimeInterval itemExpireTime = [date timeIntervalSinceReferenceDate];
    if(itemExpireTime > 0 &&
       itemExpireTime <= [[TimeUtil today] timeIntervalSinceReferenceDate])
    {
        return YES;
    }
    
    return NO;
}

+ (BOOL)isNearExpired:(NSDate *)expireDate nearExpiredDays:(int)day
{
    if([expireDate timeIntervalSinceReferenceDate] == 0) {
        return NO;
    }

    NSDate *nearExpiredDate = [TimeUtil dateFromDate:expireDate inDays:1-day]; //the expired date will alert as near-expired day
    if([nearExpiredDate compare:[TimeUtil today]] == NSOrderedDescending) {
        return NO;
    }
    
    return YES;
}
@end
