//
//  MJStatusManager.h
//  Encoder Demo
//
//  Created by Dan Park on 9/1/14.
//  Copyright (c) 2014 Magic Point. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// debug
#import "MJDebugHeader.h"
// memory
#import "MJMemoryManager.h"
// log
#import "MJLogFileManager.h"
// calendar
#import "PHCalendarCalculate.h"

@interface MJStatusManager : NSObject {
}
@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic, strong) NSDate *endDate;
@property (nonatomic, readwrite) float torchLevel;

+ (instancetype)sharedManager;
- (NSString*) description;
- (NSString*) descriptionWithTimestamp;
- (NSString*) descriptionWithShortTimestamp;
- (NSString*) sizeDescriptionWithShortTimestamp:(NSString*) sizeString;

- (NSString*) elapsedTimeString;
- (NSString*) elapsedTimeString:(NSDate*) endDate;

- (NSString*) usedMemoryInKBString;
+ (NSString*)batteryPercentage;
- (NSString*) batteryLevelString;
@end
