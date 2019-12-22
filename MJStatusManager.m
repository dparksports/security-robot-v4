//
//  MJStatusManager.m
//  Encoder Demo
//
//  Created by Dan Park on 9/1/14.
//  Copyright (c) 2014 Magic Point. All rights reserved.
//

#import "MJStatusManager.h"

@interface MJStatusManager ()
@end

@implementation MJStatusManager

// dp: instancetype is supported from iOS 6.1
+ (instancetype)sharedManager {
    static id singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[self.class alloc] init];
    });
    return singleton;
}

- (id)init {
    self = [super init];
    if (self) {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
//        [UIApplication sharedApplication].idleTimerDisabled = YES;
    }
    return self;
}

+ (NSString*)batteryPercentage {
    float batteryLevel = [UIDevice currentDevice].batteryLevel * 100.0;
    NSString *string = [@(batteryLevel) stringValue];
    return string;
}

+ (NSString*)charcterBatteryState {
    NSString *string = nil;
    UIDeviceBatteryState state = [UIDevice currentDevice].batteryState;
    switch (state) {
        case UIDeviceBatteryStateUnknown:
            string = @"K";
            break;
        case UIDeviceBatteryStateUnplugged:
            string = @"U";
            break;
        case UIDeviceBatteryStateCharging:
            string = @"C";
            break;
        case UIDeviceBatteryStateFull:
            string = @"F";
            break;
        default:
            string = @"D";
            break;
    }
    return string;
}

+ (NSString*)shortStringBatteryState {
    NSString *string = nil;
    UIDeviceBatteryState state = [UIDevice currentDevice].batteryState;
    switch (state) {
        case UIDeviceBatteryStateUnknown:
            string = @"UNK";
            break;
        case UIDeviceBatteryStateUnplugged:
            string = @"UNP";
            break;
        case UIDeviceBatteryStateCharging:
            string = @"CHR";
            break;
        case UIDeviceBatteryStateFull:
            string = @"FUL";
            break;
        default:
            string = @"DFT";
            break;
    }
    return string;
}

+ (NSString*)stringBatteryState {
    NSString *string = nil;
    UIDeviceBatteryState state = [UIDevice currentDevice].batteryState;
    switch (state) {
        case UIDeviceBatteryStateUnknown:
            string = @"Unknown";
            break;
        case UIDeviceBatteryStateUnplugged:
            string = @"Unplugged";
            break;
        case UIDeviceBatteryStateCharging:
            string = @"Charging";
            break;
        case UIDeviceBatteryStateFull:
            string = @"Full";
            break;
        default:
            string = @"Unassigned";
            break;
    }
    return string;
}

- (NSString*) elapsedTimeString:(NSDate*) endDate{
    NSTimeInterval passedInterval = [endDate timeIntervalSinceDate:self.startDate];
    
    NSUInteger remainedSeconds = passedInterval;
    NSUInteger hours = remainedSeconds / 3600;
    remainedSeconds = remainedSeconds - (hours * 3600);
    
    NSInteger minutes = remainedSeconds / 60;
    remainedSeconds = remainedSeconds % 60;

    NSString *string = [NSString stringWithFormat:@"%lu:%02ld:%02lu",
                        (unsigned long)hours, (long)minutes, (unsigned long)remainedSeconds];
    return string;
}

- (NSString*) elapsedTimeString{
    if (self.startDate) {
        if (self.endDate) {
            return [self elapsedTimeString:self.endDate];
        } else {
            return [self elapsedTimeString:[NSDate date]];
        }
    } else {
        return @"0:00:00";
    }
}

- (NSString*) description {
    NSUInteger usedKB = [MJMemoryManager usedMemoryInKB];
    
    NSString *batteryLevel = [self.class batteryPercentage];
    NSString *state = [self.class shortStringBatteryState];
    NSString *elapsedTimeString = [self elapsedTimeString];
    
    NSString *string = [NSString stringWithFormat:@"%@ %@%@  %luKB ",
                        elapsedTimeString, state, batteryLevel,  (unsigned long) usedKB];
    return string;
}

- (NSString*) sizeDescriptionWithShortTimestamp:(NSString*) sizeString {
    NSString *state = [self.class charcterBatteryState];
    NSString *elapsedTimeString = [self elapsedTimeString];
    
    NSUInteger usedKB = [MJMemoryManager usedMemoryInKB];
    NSString *batteryLevel = [self.class batteryPercentage];
    
    NSString *string = [NSString stringWithFormat:@"%@ %@%@ %@ %@KB ",
                        sizeString,
                        batteryLevel,
                        state,
                        elapsedTimeString,
                        @(usedKB)];
    NSString *timestamp = [PHCalendarCalculate timestampInShortShortFormat];
    NSString *concatenated = [NSString stringWithFormat:@"%@ %@", timestamp, string];
    return concatenated;
}

- (NSString*) descriptionWithShortTimestamp {
    NSString *state = [self.class charcterBatteryState];
    NSString *elapsedTimeString = [self elapsedTimeString];
    
    NSUInteger usedKB = [MJMemoryManager usedMemoryInKB];
    NSString *batteryLevel = [self.class batteryPercentage];
    
    NSString *string = [NSString stringWithFormat:@"%@ %@%% %@ %@ KB ",
                        state,
                        batteryLevel,
                        elapsedTimeString,
                        @(usedKB)];
    NSString *timestamp = [PHCalendarCalculate timestampInShortShortFormat];
    NSString *concatenated = [NSString stringWithFormat:@"%@ %@", timestamp, string];
    return concatenated;
}

- (NSString*) descriptionWithTimestamp {
    NSUInteger usedKB = [MJMemoryManager usedMemoryInKB];
    
    NSString *state = [self.class shortStringBatteryState];
    NSString *elapsedTimeString = [self elapsedTimeString];
    
    NSString *batteryLevel = [self.class batteryPercentage];
    NSString *string = [NSString stringWithFormat:@"%@ %@  %@  %luKB",
                         batteryLevel, state, elapsedTimeString,
                        (unsigned long) usedKB];
    NSString *timestamp = [PHCalendarCalculate timestampInShortShortFormat];
    NSString *concatenated = [NSString stringWithFormat:@"%@  %@", timestamp, string];
    return concatenated;
}

- (NSString*) batteryLevelString {
    NSString *state = [self.class charcterBatteryState];
    NSString *batteryLevel = [self.class batteryPercentage];
    NSString *string = [NSString stringWithFormat:@"%@%@",
                        batteryLevel, state];
    return string;
}

- (NSString*) usedMemoryInKBString {
    NSUInteger usedKB = [MJMemoryManager usedMemoryInKB];
    NSString *string = [NSString stringWithFormat:@"%luKB",
                        (unsigned long) usedKB];
    return string;
}
@end
