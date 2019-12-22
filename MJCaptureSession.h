//
//  MJCaptureSession.h
//  SecurityCam
//
//  Created by Dan Park on 11/13/14.
//  Copyright (c) 2014 MagicPoint. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import <CoreImage/CoreImage.h>
#import <Vision/Vision.h>
#import "sys/stat.h"

@interface MJCaptureSession : NSObject

@property (nonatomic, readonly) AVCaptureSession *captureSession;
@property (nonatomic, readonly) AVCaptureConnection *audioConnection;
@property (nonatomic, readonly) AVCaptureConnection *videoConnection;
@property (nonatomic, strong) UIImage *createdImage;
@property (nonatomic, readwrite) BOOL createImage;
@property (nonatomic, readwrite) NSInteger facecount;

+ (instancetype)sharedInstance;
//- (void)addCaptureAudioDataToSession;
- (void)addCaptureVideoDataToSession;
- (void)toggleHighResoutionMode;
- (void)setMaxFrameRate;
- (void)setMinFrameRate;
- (void)initStatusText;

- (BOOL)isTorchAvailable;
- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point;

- (void)enableTracking;
- (void)disableTracking;

- (void)startRecord;
- (void)stopRecord;
- (BOOL)isRecording;

- (void)createNewWriterIfNotCreatedAndRotateInterface;
- (void)resetWriterInputTransform:(UIInterfaceOrientation)interfaceOrientation;

@end
