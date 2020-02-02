//
//  ViewController.m
//  SecurityCam
//
//  Created by Dan Park on 11/11/14.
//  Copyright (c) 2014 MagicPoint. All rights reserved.
//

#import "MJCaptureDevice.h"
#import "MJPreviewLayerView.h"
#import "MJAssetWriter.h"
#import "MJCaptureSession.h"
#import "MJLogFileManager.h"
#import "MJStatusManager.h"
#import "MJCameraTorch.h"

// custom views
#import "MJRoundPane.h"
#import "MJCirclePane.h"
#import "MJStartButtonPanel.h"
#import "SDRecordButton.h"

#import "FolderController.h"
#import "CamController.h"
@import Firebase;

static void *SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;

@interface CamController ()
@property (nonatomic, strong) NSTimer *statusTimer;
@property (nonatomic) CAShapeLayer *maskLayer;
@property (nonatomic) id sessionRuntimeErrorHandler;
@property (nonatomic, strong) NSOperationQueue *notificationQueue;
@property (nonatomic, strong) UIImage *saveImage;
@end

@implementation CamController {
    __weak IBOutlet UILabel *recordingLabel;
    __weak IBOutlet UILabel *batteryLabel;
    __weak IBOutlet UILabel *memLabel;
    __weak IBOutlet UILabel *runTimeLabel;
    __weak IBOutlet SDRecordButton *recordButton;
    __weak IBOutlet UIButton *torchButton;
    __weak IBOutlet MJPreviewLayerView *previewLayerView;
    __weak IBOutlet UIImageView *imageView;
    __weak IBOutlet MJCirclePane *iCirclePanel;
    __weak IBOutlet MJStartButtonPanel *startButtonPanel;
    
    UIBackgroundTaskIdentifier backgroundTaskID;
    AVCaptureSession *session;
    MJCaptureSession *captureSession;
    
    BOOL dimScreen;
    CGFloat originalBrightness;
    CGPoint lastFocusPointOnDevice;
    CGFloat progress;

}

#pragma mark - Controller

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *string = [NSString stringWithFormat:@"%s", __func__];
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    
//    [self restoreScreenDim];
    [self saveBrightness];
    [self configureButtonWithColor:[UIColor whiteColor] progressColor:[UIColor redColor]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    NSString *string = [NSString stringWithFormat:@"%s", __func__];
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (! _notificationQueue) {
        NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
        [operationQueue setMaxConcurrentOperationCount:1];
        [self setNotificationQueue:operationQueue];
        [self addGauges];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (! session) {
        captureSession = [MJCaptureSession sharedInstance];
        [captureSession addCaptureVideoDataToSession];
        
        session = [captureSession captureSession];
        [previewLayerView setCaptureSession:session];
        
        UIInterfaceOrientation interfaceOrientation = [self interfaceOrientation];
        [self resetVideoOrientation:interfaceOrientation];
    }
    
    if (! [session isRunning]) {
        [session startRunning];
        [previewLayerView enableCaptureConnection:YES];
        [self updateStatus];
    }
    
    if ([captureSession isTorchAvailable])
        [torchButton setHidden:NO];
    
    [self addKeyValueObserver];
    [self registerApplicationBackgrounded];
    [self registerApplicationWillTerminate];
    [self registerApplicationWillResign];
    [self registerApplicationDidBecomeActive];
    [self registerApplicationWillEnterForegroundActive];
    
    [captureSession enableTracking];
    // support asset writer rotation transform
//    [captureSession createNewWriterIfNotCreatedAndRotateInterface];
    
    [[FIRAuth auth] signInAnonymouslyWithCompletion:^(FIRUser *_Nullable user, NSError *_Nullable error) {
        if (error){
            NSString *string = [NSString stringWithFormat:@"%s: error:%@", __func__, [error localizedDescription]];
            [MJLogFileManager logStringToFile:string file:@"log.txt"];
        }
    }];
    
    UIApplication.sharedApplication.idleTimerDisabled = NO;
    UIApplication.sharedApplication.idleTimerDisabled = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self imageLibraryCheckAccessWithHandler:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {
                    NSString *string = [NSString stringWithFormat:@"%s : PHAuthorizationStatusAuthorized", __func__];
                    [MJLogFileManager logStringToFile:string file:@"log.txt"];
                }
        }];
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    NSString *string = [NSString stringWithFormat:@"%s", __func__];
    [MJLogFileManager logStringToFile:string file:@"log.txt"];

    [self removeKeyValueObserver];
    [captureSession disableTracking];
    
    // disabled: stops recording
//    if ([session isRunning]) {
//        [previewLayerView enableCaptureConnection:NO];
//        [session stopRunning];
//    }
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (AVCaptureVideoOrientation)convertToVideoOrientation:(UIInterfaceOrientation)interfaceOrientation {
    switch (interfaceOrientation) {
        case UIInterfaceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeLeft;
        default:
        case UIInterfaceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeRight;
        case UIInterfaceOrientationPortrait:
            return AVCaptureVideoOrientationPortrait;
        case UIInterfaceOrientationPortraitUpsideDown :
            return AVCaptureVideoOrientationPortraitUpsideDown;
    }
}

- (void)resetVideoOrientation:(UIInterfaceOrientation)interfaceOrientation {
    AVCaptureVideoOrientation videoOrientation = [self convertToVideoOrientation:interfaceOrientation];
    AVCaptureVideoPreviewLayer *layer = (AVCaptureVideoPreviewLayer *) [previewLayerView layer];
    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    AVCaptureConnection *captureConnection = [layer connection];
    [captureConnection setVideoOrientation:videoOrientation];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    NSLog(@"%s", __func__);
    [self resetVideoOrientation:toInterfaceOrientation];
    [captureSession resetWriterInputTransform:toInterfaceOrientation];
}

#pragma mark - addGauge

- (void)addGauges {
    [iCirclePanel constructPanel];
    [startButtonPanel constructPanel];
}

#pragma mark - KVO

- (void)removeKeyValueObserver {
    NSLog(@"%s", __func__);
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    id<NSObject> observer = [self sessionRuntimeErrorHandler];
    [center removeObserver:observer];
    [center removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:nil];
}

- (void)addKeyValueObserver {
    NSString *string = [NSString stringWithFormat:@"%s", __func__];
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    id<NSObject> observer = [center addObserverForName:AVCaptureSessionRuntimeErrorNotification
                                                object:nil
                                                 queue:nil
                                            usingBlock:^(NSNotification *note) {
                                                NSString *string = [NSString stringWithFormat:@"%s: userInfo:%@", __func__, [note.userInfo debugDescription]];
                                                [MJLogFileManager logStringToFile:string file:@"log.txt"];
                                            }];
    [self setSessionRuntimeErrorHandler:observer];

    
    [self addObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" options:(NSKeyValueObservingOptionNew) context:SessionRunningAndDeviceAuthorizedContext];
    [center addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:nil];
}

#pragma mark - captureConnection

- (void) enableCaptureConnection {
    NSLog(@"%s", __func__);
    AVCaptureVideoPreviewLayer *layer = (AVCaptureVideoPreviewLayer *) [previewLayerView layer];
    AVCaptureConnection *captureConnection = [layer connection];
    captureConnection.enabled = YES;
}

- (void)disableCaptureConnection {
    NSLog(@"%s", __func__);
    AVCaptureVideoPreviewLayer *layer = (AVCaptureVideoPreviewLayer *) [previewLayerView layer];
    AVCaptureConnection *captureConnection = [layer connection];
    captureConnection.enabled = NO;
}

- (void)restoreScreenDim {
    NSLog(@"%s", __func__);

//    originalBrightness = 0.7;
    [self undimScreen];
}

- (void)saveBrightness {
    NSLog(@"%s", __func__);
    originalBrightness = [UIScreen mainScreen].brightness;
    NSLog( @"originalBrightness: %f", originalBrightness);
}

- (void)undimScreen {
    NSLog(@"%s", __func__);
    UIScreen *screen = [UIScreen mainScreen];
    screen.wantsSoftwareDimming = YES;
    screen.brightness = originalBrightness; // crashes on app resign
    self.view.alpha = 1.0;
    [self enableCaptureConnection];
}

- (void)dimScreen {
    NSLog(@"%s", __func__);
    UIScreen *screen = [UIScreen mainScreen];
    screen.wantsSoftwareDimming = YES;
    //    screen.wantsSoftwareDimming = NO;
    originalBrightness = screen.brightness;
    screen.brightness = 0;
    self.view.alpha = 1/40.0; //1/20.0
    [self disableCaptureConnection];
    [imageView setHidden:YES];
}

- (void)disableStatus {
    NSLog(@"%s", __func__);
    if (self.statusTimer) {
        [self.statusTimer invalidate];
        [self setStatusTimer:nil];
    }
}

- (void)updateTimer:(NSTimer *)timer {
    [self updateStatus];
}

- (void)updateStatus {
    MJStatusManager *manager = [MJStatusManager sharedManager];
    
//    runTimeLabel.text = ([captureSession isRecording]) ? [manager elapsedTimeString] : @"0:00:00";
    runTimeLabel.text = [manager elapsedTimeString];
    recordingLabel.text = ([captureSession isRecording]) ? @"Recording ON" : @"Recording OFF";
    batteryLabel.text = [manager batteryLevelString];
    memLabel.text = [manager usedMemoryInKBString];
    
    if (! self.statusTimer) {
        NSTimeInterval interval = 1.0;
        SEL sel = @selector(updateTimer:);
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:sel userInfo:nil repeats:YES];
        [self setStatusTimer:timer];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^() {
        if ([captureSession isRecording]) {
            progress += 0.05/1.0;
            progress = (progress > 1) ? (progress - 1) : progress;
            [recordButton setProgress:progress];
        }
    });
}

#pragma mark - CAAnimationDelegate

- (void)animationDidStart:(CAAnimation *)anim {
    //    NSLog(@"%s", __func__);
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    //    NSLog(@"%s", __func__);
}

- (void)animateTap:(CGPoint)locationInView {
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *) [previewLayerView layer];
    CGRect maskBounds = previewLayer.bounds;
//    CGRect maskBounds = previewLayer.frame;
//    NSLog(@"%s: maskBounds:%@", __func__, NSStringFromCGRect(maskBounds));
    
    CGFloat maskWidth = (maskBounds.size.height > maskBounds.size.width) ? maskBounds.size.width : maskBounds.size.height;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        maskWidth *= 1/5.0;
    else
        maskWidth *= 1/10.0;
    
    maskBounds.size = CGSizeMake(maskWidth, maskWidth);
//    NSLog(@"%s: maskBounds:%@", __func__, NSStringFromCGRect(maskBounds));
    
    //    maskBounds.origin = locationInView;
    NSLog(@"%s: locationInView:%@", __func__, NSStringFromCGPoint(locationInView));
//    NSLog(@"%s: maskBounds:%@", __func__, NSStringFromCGRect(maskBounds));
    
    if (! self.maskLayer) {
        CAShapeLayer *layer = [CAShapeLayer layer];
        //        [self.maskLayer setFrame:maskBounds];
        layer.delegate = self;
        [self setMaskLayer:layer];
        
        CGPoint center;
        UIBezierPath *endPath;
        endPath = [[UIBezierPath alloc] init];
        
        center.x = maskWidth*2/5.0;
        center.y = maskWidth/2.0;
        [endPath moveToPoint:center];
        
        center.x = maskWidth*3/5.0;
        center.y = maskWidth/2.0;
        [endPath addLineToPoint:center];
        
        center.x = maskWidth/2.0;
        center.y = maskWidth*2/5.0;
        [endPath moveToPoint:center];
        
        center.x = maskWidth/2.0;
        center.y = maskWidth*3/5.0;
        [endPath addLineToPoint:center];
        [endPath closePath];
        
        CGPathRef pathRef = [endPath CGPath];
        [self.maskLayer setPath:pathRef];
        [previewLayer addSublayer:self.maskLayer];
        
        layer.lineWidth = 1.0;
        //        layer.borderWidth = 0.5;
        layer.cornerRadius = maskWidth/2.0;
        [layer setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:1/4.0].CGColor];
        //        [layer setBorderColor:[UIColor lightGrayColor].CGColor];
        [layer setStrokeColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:1].CGColor];
    }
    [self.maskLayer setFrame:maskBounds];
    [self.maskLayer setPosition:locationInView];
    [self.maskLayer setOpacity:0];
    
    NSTimeInterval interval = 1/2.0; //1.0
    CABasicAnimation *tapAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    tapAnimation.fromValue = [NSNumber numberWithFloat:1];
    tapAnimation.toValue = [NSNumber numberWithFloat:0];
    tapAnimation.removedOnCompletion = YES;
    tapAnimation.duration = interval;
    tapAnimation.delegate = self;
    [self.maskLayer addAnimation:tapAnimation forKey:nil];
}

- (void)registerApplicationBackgrounded {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:self.notificationQueue
                                                  usingBlock:
     ^(NSNotification *notif) {
         NSString *string = [NSString stringWithFormat:@"%s", __func__];
         [MJLogFileManager logStringToFile:string file:@"log.txt"];
         [self stopRecording:nil];
         
     }];
}


- (void)registerApplicationWillTerminate {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil
                                                       queue:self.notificationQueue
                                                  usingBlock:
     ^(NSNotification *notif) {
         NSString *string = [NSString stringWithFormat:@"%s", __func__];
         [MJLogFileManager logStringToFile:string file:@"log.txt"];
         [self stopRecording:nil];
     }];
}

- (void)registerApplicationWillResign {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                      object:nil
                                                       queue:self.notificationQueue
                                                  usingBlock:
     ^(NSNotification *notif) {
         NSString *string = [NSString stringWithFormat:@"%s", __func__];
         [MJLogFileManager logStringToFile:string file:@"log.txt"];
         
//         [self restoreScreenDim]; // crashes on app resign
     }];
}

- (void)registerApplicationDidBecomeActive {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:self.notificationQueue
                                                  usingBlock:
     ^(NSNotification *notif) {
         NSString *string = [NSString stringWithFormat:@"%s", __func__];
         [MJLogFileManager logStringToFile:string file:@"log.txt"];
         
         
         dispatch_queue_t queue = dispatch_get_main_queue();
         dispatch_async(queue, ^() {
             [self restoreScreenDim];
         });
     }];
}

- (void)registerApplicationWillEnterForegroundActive {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification
                                                      object:nil
                                                       queue:self.notificationQueue
                                                  usingBlock:
     ^(NSNotification *notif) {
         NSString *string = [NSString stringWithFormat:@"%s", __func__];
         [MJLogFileManager logStringToFile:string file:@"log.txt"];
         
         
         dispatch_queue_t queue = dispatch_get_main_queue();
         dispatch_async(queue, ^() {
             [self restoreScreenDim];
         });
     }];
}



#pragma mark - subjectAreaDidChange

- (void)focusAndExposeAtLastFocusPoint {
    NSString *string = [NSString stringWithFormat:@"%s", __func__];
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    
    if (lastFocusPointOnDevice.x == 0 && lastFocusPointOnDevice.y == 0)
        lastFocusPointOnDevice = CGPointMake(0.5, 0.5);
    [captureSession focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:lastFocusPointOnDevice];
}

- (void)imageSavedToPhotosAlbum:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSString *string = [NSString stringWithFormat:@"%s", __func__];
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    
    if (error)
        [MJLogFileManager logErrorToFile:error file:@"log.txt"];
}

- (void)imageLibraryCheckAccessWithHandler:(void (^)(PHAuthorizationStatus status))handler {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status == PHAuthorizationStatusNotDetermined) {
                [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                        if (status != PHAuthorizationStatusAuthorized) {
                                if (handler != nil)
                                        handler(status);
                            
                            dispatch_async(dispatch_get_main_queue(), ^(void) {
                                [[[UIAlertView alloc] initWithTitle:@"Photos access"
                                                            message:@"You explicitly disabled photo library access. This results in inability to work with photos."
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil] show];
                            });
                        } else if (status == PHAuthorizationStatusAuthorized) {
                                if (handler != nil)
                                        handler(status);
                        }
                }];
        } else if (status != PHAuthorizationStatusAuthorized) {
                if (handler != nil)
                        handler(status);
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [[[UIAlertView alloc] initWithTitle:@"Photos access"
                                            message:@"Photo library access is disabled. Please check the application permissions or parental control settings in order to work with photos."
                                           delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil] show];
            });
        } else if (status == PHAuthorizationStatusAuthorized) {
                if (handler != nil)
                        handler(status);
        }
}

- (void)saveImageView{
    if (self.saveImage) {
        UIImageWriteToSavedPhotosAlbum(
                self.saveImage,
                self,
                @selector(imageSavedToPhotosAlbum: didFinishSavingWithError: contextInfo:),
                NULL);
        imageView.image = nil;
        NSString *string = [NSString stringWithFormat:@"%s: UIImageWriteToSavedPhotosAlbum", __func__];
        [MJLogFileManager logStringToFile:string file:@"log.txt"];
    }
}

- (void)subjectAreaDidChange:(NSNotification *)notification {
    NSString *string = [NSString stringWithFormat:@"%s", __func__];
    [MJLogFileManager logStringToFile:string file:@"log.txt"];

    [captureSession startMaxRateTimer];

    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self setSaveImage:captureSession.createdImage];
//        [self saveImageView];
        
    });
    [captureSession setCreateImage:YES];
    
    [self focusAndExposeAtLastFocusPoint];
}

#pragma mark - IBAction

- (IBAction)openFolderController:(id)sender {
    NSString *string = [NSString stringWithFormat:@"%s", __func__];
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    [self stopRecording:nil];

    FolderController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"FolderControllerID"];
    controller.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:controller animated:YES completion:^(void){
    }];
}

- (IBAction)stopRecording:(id)sender {
    NSString *string = NSStringFromSelector(_cmd);
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    
    BOOL isRecording = [captureSession isRecording];
    if (isRecording) {
        [captureSession stopRecord];

        // Make sure we have time to finish saving the movie if the app is backgrounded during recording
        if ([[UIDevice currentDevice] isMultitaskingSupported]) {
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskID];
            backgroundTaskID = UIBackgroundTaskInvalid;
        }
        
        progress = 0;
        [recordButton setProgress:progress];
//        [startButtonPanel toggleLogoPanel:NO];
    }
}

- (IBAction)toggleRecord:(id)sender {

    NSString *string = NSStringFromSelector(_cmd);
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    
    BOOL isRecording = [captureSession isRecording];
    if (isRecording) {
        [self stopRecording:nil];
        [captureSession setMaxFrameRate];
    } else {
//        [captureSession setMinFrameRate]; // works
//        [captureSession setMediumFrameRate]; // works
        [captureSession set5MaxFrameRate];
        
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
            [captureSession startRecord];
        }
        else {
            NSString *string = [NSString stringWithFormat:@"%s: NOT UIApplicationStateActive", __func__];
            [MJLogFileManager logStringToFile:string file:@"log.txt"];
        }
    }
}

- (void)configureButtonWithColor:(UIColor*)color progressColor:(UIColor *)progressColor {

    recordButton.buttonColor = color;
    recordButton.progressColor = progressColor;
    
    [recordButton addTarget:self action:@selector(toggleRecord:) forControlEvents:UIControlEventTouchDown];
//    [recordButton addTarget:self action:@selector(stopRecording:) forControlEvents:UIControlEventTouchUpInside];
//    [recordButton addTarget:self action:@selector(stopRecording:) forControlEvents:UIControlEventTouchUpOutside];
}

- (IBAction)swipeGesture:(UIGestureRecognizer *)gestureRecognizer {
    NSString *string = [NSString stringWithFormat:@"%s: dimScreen:%d", __func__, dimScreen];
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    
    dimScreen = !dimScreen;
    if (dimScreen) {
        [self dimScreen];
    } else {
        [self undimScreen];
    }
}

- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer {
    NSString *string = NSStringFromSelector(_cmd);
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    
    if (previewLayerView) {
        UIView *view = [gestureRecognizer view];
        CGPoint locationInView = [gestureRecognizer locationInView:view];
        [self animateTap:locationInView];
        
        AVCaptureVideoPreviewLayer *layer = (AVCaptureVideoPreviewLayer *) [previewLayerView layer];
        lastFocusPointOnDevice = [layer captureDevicePointOfInterestForPoint:locationInView];
        [captureSession focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:lastFocusPointOnDevice];
    }
}

- (IBAction)toggleLight:(id)sender {
//    [[MJCameraTorch sharedManager] toggleTorch];
//    [captureSession setMaxFrameRate];
//    [captureSession setMediumFrameRate];
    [captureSession toggleZoom];
}

@end
