//
//  PHCalendarArithmetic.m
//  Services Locator
//
//  Created by Dan Park on 3/21/14.
//  Copyright (c) 2014 Phacil Inc. All rights reserved.
//

#import "PHCalendarCalculate.h"
@interface PHCalendarCalculate ()

@property (nonatomic, readonly) NSCalendar *gregorianCalendar;
@end

@implementation PHCalendarCalculate

+ (NSCalendar *)gregorianCalendar {
    static NSCalendar *calendar = nil;;
    if (! calendar) {
        calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    }
    return calendar;
}

+ (NSString*)monthString:(NSInteger)month {
    NSString *string = @"";
    static NSArray *months = nil;
    if (! months) {
        months = @[@"January", @"February", @"March", @"April", @"May", @"June", @"July", @"August", @"September", @"October", @"November", @"December"];
    }
    month = (month > [months count] - 1) ? [months count] - 1 : month;
    month = (month < 0) ? month = 0 : month;
    string = months[month];
    return string;
}

+ (NSUInteger)currentMonth {
    NSDate *date = [NSDate date];
    NSCalendarUnit unit = NSCalendarUnitMonth;
    NSDateComponents *components = [self.gregorianCalendar components:unit fromDate:date];
    NSUInteger month = [components month];
    return month;
}

+ (NSUInteger)currentYear {
    NSDate *date = [NSDate date];
    NSCalendarUnit unit = NSCalendarUnitYear;
    NSDateComponents *components = [self.gregorianCalendar components:unit fromDate:date];
    NSUInteger year = [components year];
    return year;
}

+ (NSArray*)monthYearTuples:(NSNumber*)month year:(NSNumber*)year {
    NSArray *array = @[month, year];
    return array;
}

#define TuplesMonthIndex 0
#define TuplesYearIndex 1
+ (NSNumber*)monthFromTuples:(NSArray*)tuples {
    NSUInteger index = TuplesMonthIndex;
    NSNumber* number = tuples[index];
    return number;
}

+ (NSNumber*)yearFromTuples:(NSArray*)tuples {
    NSUInteger index = TuplesYearIndex;
    NSNumber* number = tuples[index];
    return number;
}

+ (NSString*)dateStringFromTuples:(NSArray*)tuples {
    NSNumber *year = tuples[TuplesYearIndex];
    NSNumber *month = tuples[TuplesMonthIndex];
    NSString *monthString = [self monthString:[month integerValue] - 1];
    NSString *string = [NSString stringWithFormat:@"%@ %lu", monthString, (unsigned long)[year unsignedIntegerValue]];
    return string;
}

+ (NSString*)queryDateStringFromTuples:(NSArray*)tuples {
    NSNumber *year = tuples[TuplesYearIndex];
    NSNumber *month = tuples[TuplesMonthIndex];
    unsigned int monthInt = [month intValue];
    unsigned long yearLong = [year unsignedIntegerValue];
    NSString *string = [NSString stringWithFormat:@"%2d-%lu", monthInt, yearLong];
    DLOG(@"string:%@", string);
    return string;
}


+ (NSArray*)yearsFromPastYearToCurrentYear:(NSUInteger)pastYear {
    NSUInteger currentYear = [self currentYear];
    NSUInteger count = currentYear - pastYear;
    NSMutableArray *mutable = [NSMutableArray arrayWithCapacity:count];
    
    for (NSUInteger year = pastYear; year <= currentYear; year++) {
        NSNumber *number = [NSNumber numberWithUnsignedInteger:year];
        [mutable addObject:number];
    }
    
    return mutable;
}

+ (NSArray*)monthsArrayToThisMonth:(NSUInteger)month{
    NSUInteger currentMonth = month;
    NSUInteger count = currentMonth;
    NSMutableArray *mutable = [NSMutableArray arrayWithCapacity:count];
    
    for (NSUInteger month = 1; month <= currentMonth; month++) {
        NSNumber *number = [NSNumber numberWithUnsignedInteger:month];
        [mutable addObject:number];
    }
    
    return mutable;
}

+ (NSArray*)allMonthsInYear {
#define DefaultEndMonth 12
    NSUInteger currentMonth = DefaultEndMonth;
    NSArray *array = [self monthsArrayToThisMonth:currentMonth];
    return array;
}

+ (NSArray*)monthsToCurrentMonth {
    NSUInteger currentMonth = [self currentMonth];
    NSArray *array = [self monthsArrayToThisMonth:currentMonth];
    return array;
}

+ (NSDateComponents*)componentsFromSelectedMonthAndYear:(NSUInteger)year andMonth:(NSUInteger)month {
    NSDateComponents *components = [[NSDateComponents alloc] init];
    [components setCalendar:self.gregorianCalendar];
    [components setYear:year];
    [components setMonth:month];
    return components;
}

+ (NSDate*)dateFromSelectedMonthAndYear:(NSUInteger)year andMonth:(NSUInteger)month {
    NSDateComponents *components = [self componentsFromSelectedMonthAndYear:year andMonth:month];
    NSDate *date = [self.gregorianCalendar dateFromComponents:components];
    return date;
}

+ (NSString*)dateStringFromSelectedMonthAndYear:(NSUInteger)year andMonth:(NSUInteger)month withDateFormat:(NSString*)format {
    static NSDateFormatter *formatter = nil;
    if (! formatter) {
        formatter = [[NSDateFormatter alloc] init];
    }
    [formatter setDateFormat:format];
    
    NSDate *date = [self dateFromSelectedMonthAndYear:year andMonth:month];
    NSString *string = [formatter stringFromDate:date];
    return string;
}

+ (NSString*)dateStringFromMonthAndYear:(NSUInteger)year andMonth:(NSUInteger)month useNewFormat:(BOOL)useNewFormat {
    NSString *format = nil;
    if (useNewFormat) {
        NSString *newFormat = @"MM-yyyy";
        format = newFormat;
    }
    else {
        NSString *oldFormat = @"MMM yyyy";
        format = oldFormat;
    }
    NSString *string = [self dateStringFromSelectedMonthAndYear:year andMonth:month withDateFormat:format];
    return string;
}

+ (NSDateFormatter*)dateUSFormattter {
	static NSDateFormatter *formatter = nil;
    if (! formatter) {
        formatter = [[NSDateFormatter alloc] init];
    }
    return formatter;
}

+ (NSDate*)dateInISOFormat:(NSString*)dateString {
    NSArray *components = [dateString componentsSeparatedByString:@"T"];
    if ([components count] > 0) {
        dateString = [components firstObject];
        NSDateFormatter *formatter = [self dateUSFormattter];
        [formatter setDateFormat:@"yyyy-MM-dd"];
        
        NSDate *date = [formatter dateFromString:dateString];
        return date;
    }
    else return nil;
}

+ (NSString*)timestampInISOFormat:(NSString*)dateString {
    NSDateFormatter *formatter = [self dateUSFormattter];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    
    NSDate *date = [self dateInISOFormat:dateString];
    if (date) {
        NSString *string = [formatter stringFromDate:date];
        return string;
    }
    else return NSLocalizedString(@"", @"");
}

+ (NSString*)timestampInMilitaryFormat:(NSString*)dateString {
    static NSDateFormatter *formatter = nil;
    if (! formatter)
        formatter = [[NSDateFormatter alloc] init];
    
    NSArray *components = [dateString componentsSeparatedByString:@"T"];
    if ([components count] > 0) {
        NSString *firstObject = [components firstObject];
        [formatter setDateFormat:@"yyyy-MM-dd"];
        NSDate *date = [formatter dateFromString:firstObject];
//        DLOG(@"date:%@", date)
        if (date) {
            [formatter setDateFormat:@"MMM yyyy"];
            NSString *string = [formatter stringFromDate:date];
//            DLOG(@"string:%@", string)
            return string;
        }
        else return NSLocalizedString(@"", @"");
    }
    else return NSLocalizedString(@"", @"");
}

+ (NSString*)timestampInFullFormat {
    NSDateFormatter *formatter = [self dateUSFormattter];
    [formatter setDateStyle:NSDateFormatterFullStyle];
    [formatter setTimeStyle:NSDateFormatterFullStyle];
    
    NSDate	*now = [NSDate date];
    NSString *string = [formatter stringFromDate:now];
    return string;
}

+ (NSString*)timestampInMediumFormat {
    NSDateFormatter *formatter = [self dateUSFormattter];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterFullStyle];
    
    NSDate	*now = [NSDate date];
    NSString *string = [formatter stringFromDate:now];
    return string;
}

+ (NSString*)timestampInShortMediumFormat {
    static NSDateFormatter *formatter = nil;
    if (! formatter) {
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterShortStyle];
        [formatter setTimeStyle:NSDateFormatterMediumStyle];
    }
    
    NSDate    *now = [NSDate date];
    NSString *string = [formatter stringFromDate:now];
    return string;
}

+ (NSString*)timestampInShortShortFormat {
    static NSDateFormatter *formatter = nil;
    if (! formatter) {
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterShortStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
    }
    
    NSDate	*now = [NSDate date];
    NSString *string = [formatter stringFromDate:now];
    return string;
}

+ (NSString*)timestampInShortFormat {
    static NSDateFormatter *formatter = nil;
    if (! formatter) {
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterShortStyle];
        [formatter setTimeStyle:NSDateFormatterLongStyle];
    }
    
    NSDate	*now = [NSDate date];
    NSString *string = [formatter stringFromDate:now];
    return string;
}

+ (NSString*)timestampInFileNameFormat {
    NSDateFormatter *formatter = [self dateUSFormattter];
    [formatter setDateFormat:@"yyyy-MM-dd=HH.mm.ss"];
    NSDate	*now = [NSDate date];
    NSString *string = [formatter stringFromDate:now];
    return string;
}

+ (NSString*)timestampInPosixFormat {
	NSDateFormatter *formatter = [self dateUSFormattter];
	[formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    
	NSDate	*now = [NSDate date];
	NSString *string = [formatter stringFromDate:now];
    return string;
}

+ (NSString*)timestampInLongPosixFormat {
	NSDateFormatter *formatter = [self dateUSFormattter];
	formatter.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'";
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    
	NSDate	*now = [NSDate date];
	NSString *string = [formatter stringFromDate:now];
    return string;
}
@end
