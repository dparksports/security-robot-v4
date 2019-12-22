//
//  PHCalendarArithmetic.h
//  Services Locator
//
//  Created by Dan Park on 3/21/14.
//  Copyright (c) 2014 Phacil Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
// debug
#import "MJDebugHeader.h"

@interface PHCalendarCalculate : NSObject

+ (NSString*)monthString:(NSInteger)month;
+ (NSUInteger)currentYear;
+ (NSArray*)allMonthsInYear;
+ (NSArray*)monthsToCurrentMonth;
+ (NSArray*)yearsFromPastYearToCurrentYear:(NSUInteger)pastYear;
+ (NSString*)dateStringFromMonthAndYear:(NSUInteger)year andMonth:(NSUInteger)month useNewFormat:(BOOL)useNewFormat;

+ (NSArray*)monthYearTuples:(NSNumber*)month year:(NSNumber*)year;
+ (NSString*)dateStringFromTuples:(NSArray*)tuples;
+ (NSString*)queryDateStringFromTuples:(NSArray*)tuples;

+ (NSString*)timestampInMilitaryFormat:(NSString*)dateString;
+ (NSString*)timestampInPosixFormat;

+ (NSString*)timestampInShortMediumFormat;
+ (NSString*)timestampInShortShortFormat;
+ (NSString*)timestampInShortFormat;
+ (NSString*)timestampInMediumFormat;
+ (NSString*)timestampInFullFormat;
+ (NSString*)timestampInFileNameFormat;
@end
