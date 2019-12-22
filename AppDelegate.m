//
//  AppDelegate.m
//  SecurityCam
//
//  Created by Dan Park on 11/11/14.
//  Copyright (c) 2014 MagicPoint. All rights reserved.
//

#import "AppDelegate.h"
#import "getRated.h"
@import Firebase;

@interface AppDelegate ()

// Used for sending Google Analytics traffic in the background.
@property(nonatomic, assign) BOOL okToWait;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [FIRApp configure];
    
    [getRated sharedInstance].promptAtLaunch = NO;
//    [getRated sharedInstance].usesUntilPrompt = 2;
    
    //enable preview mode - *** FOR TESTING ONLY ***
//    [getRated sharedInstance].previewMode = YES;
    /* _required_ */
    //start GetRated - should be called AFTER any optional configuration options (above)
    [[getRated sharedInstance] start];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    UIScreen *screen = [UIScreen mainScreen];
    screen.brightness = 0.8;
    
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
