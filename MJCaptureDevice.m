//
//  MJCaptureDevice.m
//  SecurityCam
//
//  Created by Dan Park on 11/11/14.
//  Copyright (c) 2014 MagicPoint. All rights reserved.
//

#import "MJFormatDescription.h"
#import "MJCaptureDevice.h"

@implementation MJCaptureDevice

- (void)checkCameraAuthorizationStatus {
    NSLog(@"%s", __func__);
    SEL selector = @selector(requestAccessForMediaType:completionHandler:);
    if ([AVCaptureDevice respondsToSelector:selector]) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (! granted) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [[[UIAlertView alloc] initWithTitle:nil
                                                message:@"WebCam doesn't have permission to use Camera, please change privacy settings"
                                               delegate:self
                                      cancelButtonTitle:@"OK"
                                      otherButtonTitles:nil] show];
                    
                });
            }
        }];
    }
}

- (AVCaptureDevice *)videoDeviceWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
        if ([device position] == position)
            return device;
    
    return NULL;
}

- (AVCaptureDevice *)audioDevice {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ([devices count] > 0)
        return [devices firstObject];
    
    return nil;
}

- (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device {
    if ([device hasFlash] && [device isFlashModeSupported:flashMode]) {
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            [device setFlashMode:flashMode];
            [device unlockForConfiguration];
        }
        else NSLog(@"%s: error:%@", __func__, error);
    }
}

- (void)inspectFormats:(AVCaptureDevice *)videoDevice {
    NSArray *captureDeviceFormats = [videoDevice formats];
    NSString *string = nil;
    for (AVCaptureDeviceFormat *captureDeviceFormat in captureDeviceFormats) {
        string = [NSString stringWithFormat:@"fv:%.1f bn:%d st:%d zm:%.1f/mx:%.1f",
                  captureDeviceFormat.videoFieldOfView,
                  captureDeviceFormat.videoBinned,
                  captureDeviceFormat.videoStabilizationSupported,
                  captureDeviceFormat.videoZoomFactorUpscaleThreshold,
                  captureDeviceFormat.videoMaxZoomFactor];
        NSArray *array = captureDeviceFormat.videoSupportedFrameRateRanges;
        for (AVFrameRateRange *range in array)
            string = [string stringByAppendingString:[NSString stringWithFormat:@" rg:%.f - %.f",
                                                      [range minFrameRate], [range maxFrameRate]]];
        NSString *formatString = [[MJFormatDescription new] description:captureDeviceFormat.formatDescription];
        string = [formatString stringByAppendingString:string];
        NSLog(@"%@", string);
    }
}

- (void)inspectFullFormats:(AVCaptureDevice *)videoDevice {
    NSArray *captureDeviceFormats = [videoDevice formats];
    NSString *string = nil;
    for (AVCaptureDeviceFormat *captureDeviceFormat in captureDeviceFormats) {
        string = [NSString stringWithFormat:@"fv:%.1f bn:%d st:%d zm:%.1f-%.1f",
                  captureDeviceFormat.videoFieldOfView,
                  captureDeviceFormat.videoBinned,
                  captureDeviceFormat.videoStabilizationSupported,
                  captureDeviceFormat.videoZoomFactorUpscaleThreshold,
                  captureDeviceFormat.videoMaxZoomFactor];
        NSArray *array = captureDeviceFormat.videoSupportedFrameRateRanges;
        for (AVFrameRateRange *range in array)
            string = [string stringByAppendingString:[NSString stringWithFormat:@" rg:%.f-%.f",
                                                      [range minFrameRate], [range maxFrameRate]]];
        NSString *formatString = [[MJFormatDescription new] description:captureDeviceFormat.formatDescription];
        string = [formatString stringByAppendingString:string];
        NSLog(@"%@", string);
    }
}
@end
