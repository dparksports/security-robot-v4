//
//  MJCaptureSession.m
//  SecurityCam
//
//  Created by Dan Park on 11/13/14.
//  Copyright (c) 2014 MagicPoint. All rights reserved.
//

#import "MJCaptureDevice.h"
#import "MJFormatDescription.h"
#import "MJAssetWriter.h"
#import "MJLogFileManager.h"
#import "MJDeviceModel.h"
#import "MJFormatDescription.h"
#import "MJStatusManager.h"
#import "PHCalendarCalculate.h"
#import "MJCameraTorch.h"
#import "MJCaptureSessionPreset.h"
#import "MJCaptureSession.h"

#include <TargetConditionals.h>

#if TARGET_RT_BIG_ENDIAN
#   define FourCC2Str(fourcc) (const char[]){*((char*)&fourcc), *(((char*)&fourcc)+1), *(((char*)&fourcc)+2), *(((char*)&fourcc)+3),0}
#else
#   define FourCC2Str(fourcc) (const char[]){*(((char*)&fourcc)+3), *(((char*)&fourcc)+2), *(((char*)&fourcc)+1), *(((char*)&fourcc)+0),0}
#endif

static CGFloat DegreesToRadians(CGFloat degrees) {
    return degrees * M_PI / 180;
};

@interface MJCaptureSession ()
<AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDevice *videoCaptureDevice;
@property (nonatomic, strong) AVCaptureDeviceInput *inputDevice;

@property (nonatomic, strong) CIDetector *detector;
@property (nonatomic, strong) MJAssetWriter *videoWriter;

@property (nonatomic, strong) NSString *drawString1, *drawString2, *drawTitle;
@property (nonatomic, strong) NSTimer *timer, *maxRateTimer;
@end

@implementation MJCaptureSession {
    dispatch_queue_t audioCaptureQueue;
    dispatch_queue_t videoCaptureQueue;
    dispatch_queue_t fileWritingQueue;
    
    // MJAssetWriter
    BOOL finishWritingInProcess;
    
    // didOutputSampleBuffer
    BOOL isPlanar;
    size_t bytesPerRow;
    size_t width;
    size_t height;
    CGSize size;
    CVPixelBufferRef pixelBuffer;
    CTFontRef fontRef;
    CGFloat fontSize;

    NSUInteger countStatus;
    volatile BOOL updateDrawString1;
    const char *cDrawString1, *cDrawString2, *cDrawTitle;
    char drawStringArray1[100], drawStringArray2[100], titleArray[100];
    size_t drawStringLength1, drawStringLength2, drawTitleLength;
    
    NSUInteger countDroppedSampleBuffer;
    UIInterfaceOrientation interfaceOrientation;
}

- (void)dealloc {
    [self setCaptureSession:nil];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // In a multi-threaded producer consumer system it's generally a good idea to make sure that producers do not get starved of CPU time by their consumers.
        // In this app we start with VideoDataOutput frames on a high priority queue, and downstream consumers use default priority queues.
        // Audio uses a default priority queue because we aren't monitoring it live and just want to get it into the movie.
        // AudioDataOutput can tolerate more latency than VideoDataOutput as its buffers aren't allocated out of a fixed size pool.
        videoCaptureQueue = dispatch_queue_create( "magicpoint.videoCaptureQueue", DISPATCH_QUEUE_SERIAL );
        dispatch_set_target_queue(videoCaptureQueue, dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 ) );
        audioCaptureQueue = dispatch_queue_create( "magicpoint.audioCaptureQueue", DISPATCH_QUEUE_SERIAL );
        [self setCaptureSession:[AVCaptureSession new]];
        
    }
    return self;
}

+ (instancetype)sharedInstance {
    static id sharedInstance = nil;
    if (! sharedInstance) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sharedInstance = [self.class new];
        });
    }
    return sharedInstance;
}

#pragma mark - AVCaptureDevice

- (CGFloat)calculateFontSize {
    float standardFontSize = 12;

    float aspectRatio = width / (height * 1.0);
    float standardRowsH = 10.0;
    float standardRowsW = aspectRatio * standardRowsH;
    
    float rowH = height / standardRowsH;
    float rowW = width / standardRowsW;

    // 1920x1080: factor = 9
    // 1024x968: factor = 3?
    int factorH = rowH / standardFontSize;
    int factorW = rowW / standardFontSize;

    if (self.captureSession.sessionPreset == AVCaptureSessionPresetHigh) {
        if (UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation])) {
            fontSize = standardFontSize * (factorH - 3);
        } else {
            fontSize = standardFontSize * (factorW - 3);
        }
    } else {
        if (self.captureSession.sessionPreset == AVCaptureSessionPresetMedium) {
            if (UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation])) {
                fontSize = standardFontSize * (factorH - 3);
            } else {
                fontSize = standardFontSize * (factorW - 3);
            }
        } else {
            if (self.captureSession.sessionPreset == AVCaptureSessionPresetLow) {
                if (UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation])) {
                    fontSize = standardFontSize * 1;
                } else {
                    fontSize = standardFontSize - 1;
                }
            } else {
                
                fontSize = standardFontSize * 3;
            }
        }
    }
    
    return fontSize;
}

- (void)drawTextInContext:(CGContextRef)context fromConnection:(AVCaptureConnection *)connection {
    fontSize = [self calculateFontSize];
    int rows = height / fontSize;
    CGFloat titleYOffset = 0;
    CGFloat stampYOffset = ( rows - 1 ) * fontSize;  // for low res, stamp is clipped at top.

    CGFloat width5S = 320;
    CGFloat heigh5S = 568;
    CGFloat width6Plus = 414;
    CGFloat height6Plus = 736;
    CGFloat width11ProMax = 414;
    CGFloat height11ProMax = 896;

    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    switch (deviceOrientation) {
        case UIDeviceOrientationLandscapeRight: {
            // hide title, while scrubbing: (row - 2)
            // (rows - 2) : iPhone Max
            // (rows - 2.5) : iPad 2
            titleYOffset = ( rows - 2.5 ) * fontSize;
            
            // show stamp, while scrubbing:
            if (UIScreen.mainScreen.bounds.size.height == width5S) {
                // 5s: *2.6
                stampYOffset = fontSize * 2.6;
            } else {
                if (UIScreen.mainScreen.bounds.size.width == height11ProMax) {
                    // Pro11Max: *2.5
                    stampYOffset = fontSize * 1.5;
                } else {
                    // 6Plus: *0.6
                    stampYOffset = fontSize * 0.7;
                }
            }

            CGFloat tx = size.width * 1.0;
            CGFloat ty = size.height * (28/30.0);
            CGContextTranslateCTM(context, tx,ty);
            
            CGFloat degrees = 180;
            CGFloat angleInRadians = degrees * M_PI/180.0;
            CGContextRotateCTM(context, angleInRadians);
        }
            break;
        case UIDeviceOrientationLandscapeLeft: {
            // hide title, while scrubbing: (row - 1)
            titleYOffset = ( rows - 1 ) * fontSize;
            
            // show stamp, while scrubbing:
            if (UIScreen.mainScreen.bounds.size.height == width5S) {
                // 5s: *3.6
                stampYOffset = fontSize * 3.6;
            } else {
                if (UIScreen.mainScreen.bounds.size.width == height11ProMax) {
                    // Pro11Max: *2.5
                    stampYOffset = fontSize * 2.5;
                } else {
                    // 6Plus: *1.9
                    stampYOffset = fontSize * 1.7;
                }
            }

            CGFloat degrees = 0;
            CGFloat angleInRadians = degrees * M_PI/180.0;
            CGContextRotateCTM(context, angleInRadians);
        }
            break;
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationUnknown:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        default: {
            rows = width / fontSize;
            // show title, while scrubbing: (row - 3)
            titleYOffset = ( rows - 3.5 ) * fontSize;
            
            // show stamp, while scrubbing:
            if (UIScreen.mainScreen.bounds.size.height == heigh5S) {
                // 5s: *3.6
                stampYOffset = fontSize * 3.6;
            } else {
                if (UIScreen.mainScreen.bounds.size.height == height11ProMax) {
                    // Pro11Max: *1.0
                    stampYOffset = fontSize * 1.0;
                } else {
                    // 6Plus: *2.4
                    stampYOffset = fontSize * 2.4;
                }
            }

            CGFloat tx = size.width * (19/20.0);
            CGFloat ty = size.height * 0;
            CGContextTranslateCTM(context, tx,ty);
            
            CGFloat degrees = 90;
            CGFloat angleInRadians = degrees * M_PI/180.0;
            CGContextRotateCTM(context, angleInRadians);
        }
            break;
        case AVCaptureVideoOrientationPortraitUpsideDown :{
            CGFloat degrees = -90.;
            CGFloat angleInRadians = degrees * M_PI/180.0;
            CGContextRotateCTM(context, angleInRadians);
        }
            break;
            break;
    }
    
    CGContextSetRGBStrokeColor(context, 0, 0, 0, 1.0);
    CGContextSetRGBFillColor(context, 1, 1, 1, 1.0);
    CGContextSetTextDrawingMode(context, kCGTextFillStroke);
    
    NSString *fontName = @"Helvetica";
    fontRef = CTFontCreateWithName((CFStringRef)fontName, fontSize, NULL);
    CGContextSelectFont(context, "Helvetica", fontSize, kCGEncodingMacRoman);
    
    if (updateDrawString1)
        CGContextShowTextAtPoint(context, 0, stampYOffset, drawStringArray2, drawStringLength2);
    else
        CGContextShowTextAtPoint(context, 0, stampYOffset, drawStringArray1, drawStringLength1);
    CGContextShowTextAtPoint(context, 0, titleYOffset, titleArray, drawTitleLength);
}

//- (void)addCaptureAudioDataToSession {
//    NSError *error = nil;
//    AVCaptureDevice *captureDevice = [[MJCaptureDevice new] audioDevice];
//    AVCaptureDeviceInput *captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
//    if (error)
//        NSLog(@"%s: error:%@", __func__, error);
//    
//    AVCaptureAudioDataOutput *captureDataOutput = [AVCaptureAudioDataOutput new];
//    [captureDataOutput setSampleBufferDelegate:self queue:audioCaptureQueue];
//    
//    if ([_captureSession canAddInput:captureDeviceInput])
//        [_captureSession addInput:captureDeviceInput];
//    if ([_captureSession canAddOutput:captureDataOutput])
//        [_captureSession addOutput:captureDataOutput];
//    
//    _audioConnection = [captureDataOutput connectionWithMediaType:AVMediaTypeAudio];
//}

CGFloat maxFrameRate = 20.0;
CGFloat mediumFrameRate = 5.0;
CGFloat minFrameRate = 5.0; //4.0

- (void)setMaxFrameRate{
    NSError *error = nil;
    if ( [self.videoCaptureDevice lockForConfiguration:&error] ) {
        CMTime frameDuration = CMTimeMake(1, maxFrameRate);
        self.videoCaptureDevice.activeVideoMaxFrameDuration = frameDuration;
        self.videoCaptureDevice.activeVideoMinFrameDuration = frameDuration;
        [self.videoCaptureDevice unlockForConfiguration];
    }
}

- (void)setMinFrameRate{
    NSError *error = nil;
    if ( [self.videoCaptureDevice lockForConfiguration:&error] ) {
        CMTime frameDuration = CMTimeMake(1, minFrameRate);
        self.videoCaptureDevice.activeVideoMaxFrameDuration = frameDuration;
        self.videoCaptureDevice.activeVideoMinFrameDuration = frameDuration;
        [self.videoCaptureDevice unlockForConfiguration];
    }
}

- (void)setMediumFrameRate{
    NSError *error = nil;
    if ( [self.videoCaptureDevice lockForConfiguration:&error] ) {
        CMTime frameDuration = CMTimeMake(1, mediumFrameRate);
        self.videoCaptureDevice.activeVideoMaxFrameDuration = frameDuration;
        self.videoCaptureDevice.activeVideoMinFrameDuration = frameDuration;
        [self.videoCaptureDevice unlockForConfiguration];
    }
}

CGFloat maxZoomFactor = 3.0;
CGFloat minZoomFactor = 1.0;

- (void)activateMainLens{
    dispatch_async(videoCaptureQueue, ^{
        [self.captureSession removeInput:self.inputDevice];

        AVCaptureDevice *device = [[MJCaptureDevice new] videoDeviceWithPosition:AVCaptureDevicePositionBack];
        [self setVideoCaptureDevice:device];

        NSError *error = nil;
        AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                                  error:&error];
        if (error)
            NSLog(@"%s: error:%@", __func__, error);
        else {
            self.inputDevice = deviceInput;
            if ([self.captureSession canAddInput:deviceInput])
                [self.captureSession addInput:deviceInput];
        }
    });
}

- (void)activateTelephotoLens{
    dispatch_async(videoCaptureQueue, ^{
        [self.captureSession removeInput:self.inputDevice];

        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInTelephotoCamera
                                   mediaType:AVMediaTypeVideo
                                    position:AVCaptureDevicePositionBack];

        NSError *error = nil;
        AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                                  error:&error];
        if (error)
            NSLog(@"%s: error:%@", __func__, error);
        else {
            self.inputDevice = deviceInput;
            if ([self.captureSession canAddInput:deviceInput])
                [self.captureSession addInput:deviceInput];
        }
    });
}

- (void)toggleZoom{
    if (self.videoCaptureDevice.videoZoomFactor == minZoomFactor) {
        [self setMaxZoom];
    } else {
        [self setMinZoom];
    }
}

- (void)setMinZoom{
    NSError *error = nil;
    if ( [self.videoCaptureDevice lockForConfiguration:&error] ) {
        self.videoCaptureDevice.videoZoomFactor = minZoomFactor;
        [self.videoCaptureDevice unlockForConfiguration];
    }
}

- (void)setMaxZoom{
    if (@available(iOS 11.0, *)) {
        NSLog( @"minAvailableVideoZoomFactor: %f", self.videoCaptureDevice.minAvailableVideoZoomFactor);
        NSLog( @"maxAvailableVideoZoomFactor: %f", self.videoCaptureDevice.maxAvailableVideoZoomFactor);
        NSLog( @"videoMaxZoomFactor: %f", self.videoCaptureDevice.activeFormat.videoMaxZoomFactor);
    }
    
    if (maxZoomFactor > self.videoCaptureDevice.activeFormat.videoMaxZoomFactor ) {
        maxZoomFactor = self.videoCaptureDevice.activeFormat.videoMaxZoomFactor;
    }
    
    NSError *error = nil;
    if ( [self.videoCaptureDevice lockForConfiguration:&error] ) {
        self.videoCaptureDevice.videoZoomFactor = maxZoomFactor;
        [self.videoCaptureDevice unlockForConfiguration];
    }
}

- (BOOL)isTelephotoLensAvailable {
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInTelephotoCamera
                                                                 mediaType:AVMediaTypeVideo
                                                                  position:AVCaptureDevicePositionBack];
    
    return captureDevice != NULL;
}

- (BOOL)isZoomAvailable {
    if ([self isTelephotoLensAvailable]) {
        return YES;
    } else {
        if (self.videoCaptureDevice) {
            return self.videoCaptureDevice.activeFormat.videoMaxZoomFactor > 1.0;
        } else {
            return NO;
        }
    }
}

- (void)addCaptureVideoDataToSession {
    AVCaptureDevice *captureDevice = [[MJCaptureDevice new] videoDeviceWithPosition:AVCaptureDevicePositionBack];
    [self setVideoCaptureDevice:captureDevice];

    NSError *error = nil;
    AVCaptureDeviceInput *captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.videoCaptureDevice error:&error];
    if (error)
        NSLog(@"%s: error:%@", __func__, error);
    self.inputDevice = captureDeviceInput;
    if ([self.captureSession canAddInput:captureDeviceInput])
        [self.captureSession addInput:captureDeviceInput];

    AVCaptureVideoDataOutput *captureDataOutput = [AVCaptureVideoDataOutput new];
    [captureDataOutput setSampleBufferDelegate:self queue:videoCaptureQueue];
    captureDataOutput.alwaysDiscardsLateVideoFrames = NO;
    captureDataOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    if ([self.captureSession canAddOutput:captureDataOutput])
        [self.captureSession addOutput:captureDataOutput];
    _videoConnection = [captureDataOutput connectionWithMediaType:AVMediaTypeVideo];
    
    if (! fileWritingQueue)
        fileWritingQueue = dispatch_queue_create("magicpoint.fileWritingQueue", DISPATCH_QUEUE_SERIAL);
    if (! _videoWriter)
        [self setVideoWriter:[MJAssetWriter new]];
    
    [self updateStatus];
    [[MJCameraTorch sharedManager] initWithCaptureDevice:self.videoCaptureDevice];
}

- (void)inspectCaptureDeviceFormats {
//    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
//        [[MJCaptureDevice new] inspectFullFormats:captureDevice];
//    NSLog(@"%s: videoSettings:%@", __func__, captureVideoDataOutput.videoSettings);
//    [[MJFormatDescription new] inspectPixelFormatType:captureVideoDataOutput.videoSettings[@"PixelFormatType"]];
//    NSLog(@"%s: availableVideoCodecTypes:%@", __func__, captureVideoDataOutput.availableVideoCodecTypes);
//    [[MJFormatDescription new] inspectPixelFormatTypes:captureVideoDataOutput.availableVideoCodecTypes];
//    NSLog(@"%s: availableVideoCVPixelFormatTypes:%@", __func__, captureVideoDataOutput.availableVideoCVPixelFormatTypes);
//    [[MJFormatDescription new] inspectPixelFormatTypes:captureVideoDataOutput.availableVideoCVPixelFormatTypes];
}

- (NSNumber *)exifOrientation:(UIDeviceOrientation)orientation
       usingFrontFacingCamera:(BOOL)isUsingFrontFacingCamera {
    int exifOrientation;
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants.
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
     
     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
    
    enum {
        PHOTOS_EXIF_0ROW_TOP_0COL_LEFT            = 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
        PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT            = 2, //   2  =  0th row is at the top, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
        PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
        PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
    };
    
    switch (orientation) {
        case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
            break;
        case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
            if (isUsingFrontFacingCamera)
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            break;
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
            if (isUsingFrontFacingCamera)
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            break;
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        default:
            exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
            break;
    }
    
    return [NSNumber numberWithInt:exifOrientation];
}

- (CIDetector *)detector {
    if (!_detector) {
        NSDictionary *opts = @{ CIDetectorAccuracy : CIDetectorAccuracyHigh };
        _detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                       context:nil
                                       options:opts];
    }
    return _detector;
}

- (NSDictionary *)detectFacesFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
                               andPixelBuffer:(CVPixelBufferRef)pixelBuffer
                       usingFrontFacingCamera:(BOOL)isUsingFrontFacingCamera {
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer
                                                      options:(__bridge NSDictionary *)attachments];
    if (attachments) {
        CFRelease(attachments);
    }
    
    // make sure your device orientation is not locked.
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    
    NSDictionary *imageOptions = nil;
    
    imageOptions = [NSDictionary
                    dictionaryWithObject:[self exifOrientation:curDeviceOrientation usingFrontFacingCamera:isUsingFrontFacingCamera]
                    forKey:CIDetectorImageOrientation];
    
    NSArray *features = [self.detector featuresInImage:ciImage
                                               options:imageOptions];
    
    if ([features count]) {
        ciImage = [ciImage imageByApplyingOrientation:[self exifOrientation:[UIDevice currentDevice].orientation
                                                     usingFrontFacingCamera:isUsingFrontFacingCamera].intValue];
        return @{ @"count" : [NSNumber numberWithInteger:features.count],
                  @"image" : [UIImage imageWithCIImage:ciImage] };
    }
    
    return [NSDictionary dictionary];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    //    countDroppedSampleBuffer++;
}

- (void) captureOutput:(AVCaptureOutput *)captureOutput
 didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
        fromConnection:(AVCaptureConnection *)connection{

//    BOOL drawText = countStatus % 2;
    if (true) {
        pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
        width = CVPixelBufferGetWidth(pixelBuffer);
        height = CVPixelBufferGetHeight(pixelBuffer);
        size = CGSizeMake(width, height);
        isPlanar = CVPixelBufferIsPlanar(pixelBuffer);
//        NSLog( @"height: %zu", height);
//        NSLog( @"width: %zu", width);

        if (! isPlanar) {
            CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            void *sourceBaseAddr = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
            CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGContextRef contextRef = CGBitmapContextCreate(sourceBaseAddr, width, height, 8, bytesPerRow, colorSpace, bitmapInfo);
            if (contextRef) {
                [self drawTextInContext:contextRef fromConnection:connection];
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            CGContextRelease(contextRef);
        }
    }
    
    if (self.createImage) {
        [self setCreateImage:NO];
        
        pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
        width = CVPixelBufferGetWidth(pixelBuffer);
        height = CVPixelBufferGetHeight(pixelBuffer);
        size = CGSizeMake(width, height);
        isPlanar = CVPixelBufferIsPlanar(pixelBuffer);
        
        if (! isPlanar) {
            CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            void *sourceBaseAddr = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
            CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGContextRef contextRef = CGBitmapContextCreate(sourceBaseAddr, width, height, 8, bytesPerRow, colorSpace, bitmapInfo);

            CGImageRef imageRef = CGBitmapContextCreateImage(contextRef);
            UIImage *image = [UIImage imageWithCGImage:imageRef];
            [self setCreatedImage:image];
            CGImageRelease(imageRef);

            CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
            CGContextRelease(contextRef);
        }
    }
    
    CFRetain(sampleBuffer);
    dispatch_async(fileWritingQueue, ^{
        if (! finishWritingInProcess) {
            if (CMSampleBufferDataIsReady(sampleBuffer) &&
                self.videoWriter.assetWriter.status == AVAssetWriterStatusWriting) {
                if (! [self.videoWriter writerStartedSession]) {
                    self.videoWriter.writerStartedSession = YES;
                    CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                    [self.videoWriter.assetWriter startSessionAtSourceTime:startTime];
                }
                if (self.videoWriter.assetWriterVideoInput.readyForMoreMediaData) {
                    if ([self.videoWriter.assetWriterVideoInput appendSampleBuffer:sampleBuffer]) {
//                        NSLog(@"%s: self.writerProxy.assetWriterVideoInput:%@", __func__,
//                              self.videoWriter.assetWriterVideoInput);
                    }
                    else {
                        NSLog(@"%s: mainWriter.error: %@", __func__, self.videoWriter.assetWriter.error);
                    }
                }
            }
        }
        CFRelease(sampleBuffer);
    });
}

#pragma mark - createNewWriterIfLargerThanMax

- (void)createWriterIfEventAndStartWriting {
    dispatch_async(fileWritingQueue, ^{
        if (!finishWritingInProcess) {
            finishWritingInProcess = YES;
            NSLog(@"%s: finishWritingInProcess:%d", __func__, finishWritingInProcess);
            
            [self.videoWriter.assetWriter finishWritingWithCompletionHandler:^{
                self.videoWriter.writerStartedSession = NO;
                finishWritingInProcess = NO;
                
                NSError *error = self.videoWriter.assetWriter.error;
                NSLog(@"%s: error:%@", __func__, [error localizedDescription]);
                
                AVAssetWriter *writer = [self.videoWriter createNewWriterByNextFileIndex];
                [self resetWriterInputTransform:interfaceOrientation];
                if ([writer startWriting]) {
                    finishWritingInProcess = NO;
                    NSLog(@"%s: finishWritingInProcess:%d", __func__, finishWritingInProcess);
                    NSError *error = self.videoWriter.assetWriter.error;
                    NSLog(@"%s: error:%@", __func__, [error localizedDescription]);
                }
                else NSLog(@"%s: error:%@", __func__, writer.error);
            }];
        }
    });
}


- (void)createWriterIfLargerThanMaxAndStartWriting {
    dispatch_async(fileWritingQueue, ^{
        if (!finishWritingInProcess) {
            if ([self.videoWriter isLargerThanMaxFileSize]) {
                finishWritingInProcess = YES;
                NSLog(@"%s: finishWritingInProcess:%d", __func__, finishWritingInProcess);
                
                [self.videoWriter.assetWriter finishWritingWithCompletionHandler:^{
                    self.videoWriter.writerStartedSession = NO;
                    finishWritingInProcess = NO;
                    
                    NSError *error = self.videoWriter.assetWriter.error;
                    NSLog(@"%s: error:%@", __func__, [error localizedDescription]);
                    
                    AVAssetWriter *writer = [self.videoWriter createNewWriterByNextFileIndex];
                    [self resetWriterInputTransform:interfaceOrientation];
                    if ([writer startWriting]) {
                        finishWritingInProcess = NO;
                        NSLog(@"%s: finishWritingInProcess:%d", __func__, finishWritingInProcess);
                        NSError *error = self.videoWriter.assetWriter.error;
                        NSLog(@"%s: error:%@", __func__, [error localizedDescription]);
                    }
                    else NSLog(@"%s: error:%@", __func__, writer.error);
                }];
            }
        }
    });
}

- (void)createNewWriterIfNotCreatedAndRotateInterface {
    NSString *string = NSStringFromSelector(_cmd);
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    
    dispatch_async(fileWritingQueue, ^{
        if (! self.videoWriter.assetWriter) {
            [self.videoWriter createNewWriterByNextFileIndex];
            [self resetWriterInputTransform:interfaceOrientation];
        }
    });
}

- (void)startRecord {
    NSString *string = NSStringFromSelector(_cmd);
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    [[MJStatusManager sharedManager] setStartDate:[NSDate date]];
    [[MJStatusManager sharedManager] setEndDate:nil];

    dispatch_async(fileWritingQueue, ^{
        if (! self.videoWriter.assetWriter) {
            [self.videoWriter createNewWriterByNextFileIndex];
            [self resetWriterInputTransform:interfaceOrientation];
        }
        
        if (self.videoWriter.assetWriter.status == AVAssetWriterStatusCompleted ||
            self.videoWriter.assetWriter.status == AVAssetWriterStatusFailed ||
            self.videoWriter.assetWriter.status == AVAssetWriterStatusCancelled) {
            [self.videoWriter createNewWriterByNextFileIndex];
            [self resetWriterInputTransform:interfaceOrientation];
        }
        
        if (self.videoWriter.assetWriter.status == AVAssetWriterStatusUnknown) {
            if ([self.videoWriter.assetWriter startWriting]) {
            }
            else {
                NSString *string = [NSString stringWithFormat:@"%s: self.videoWriter.assetWriter.error:%@", __func__, self.videoWriter.assetWriter.error];
                [MJLogFileManager logStringToFile:string file:@"log.txt"];
            }
        }
    });
}

- (void)stopRecord {
    NSString *string = NSStringFromSelector(_cmd);
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    [[MJStatusManager sharedManager] setEndDate:[NSDate date]];

    dispatch_async(fileWritingQueue, ^{
        finishWritingInProcess = YES;
        NSLog(@"%s: finishWritingInProcess:%d", __func__, finishWritingInProcess);
        if (self.videoWriter.assetWriter.status == AVAssetWriterStatusWriting)
            [self.videoWriter.assetWriter finishWritingWithCompletionHandler:^{
                self.videoWriter.writerStartedSession = NO;
                finishWritingInProcess = NO;
                
                NSError *error = self.videoWriter.assetWriter.error;
                if (error) {
                    NSString *string = [NSString stringWithFormat:@"finishWritingWithCompletionHandler: error:%@", [error localizedDescription]];
                    [MJLogFileManager logStringToFile:string file:@"log.txt"];
                }
            }];
    });
}

#pragma mark - focusWithMode

- (BOOL)isTorchAvailable {
    return self.videoCaptureDevice.isTorchAvailable;
}

- (BOOL)isRecording {
    if (! self.videoWriter.assetWriter)
        return NO;
    return self.videoWriter.assetWriter.status == AVAssetWriterStatusWriting;
}

#pragma mark - focusWithMode

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point {

    dispatch_async(videoCaptureQueue, ^{
        
        NSError *error = nil;
        if ([self.videoCaptureDevice lockForConfiguration:&error]) {
            if ([self.videoCaptureDevice isFocusPointOfInterestSupported] &&
                [self.videoCaptureDevice isFocusModeSupported:focusMode]) {
                [self.videoCaptureDevice setFocusMode:focusMode];
                [self.videoCaptureDevice setFocusPointOfInterest:point];
            }
            if ([self.videoCaptureDevice isExposurePointOfInterestSupported] &&
                [self.videoCaptureDevice isExposureModeSupported:exposureMode]) {
                [self.videoCaptureDevice setExposureMode:exposureMode];
                [self.videoCaptureDevice setExposurePointOfInterest:point];
            }
            [self.videoCaptureDevice unlockForConfiguration];
        }
        else NSLog(@"%s: error:%@", __func__, error);
    });
}

#pragma mark - Status

- (void)disableStatus {
    NSLog(@"%s", __func__);
    if (self.timer) {
        [self.timer invalidate];
        [self setTimer:nil];
    }
}

- (void)updateTimer:(NSTimer *)timer {
    [self updateStatus];
}

- (void)updateStatus {
    MJStatusManager *manager = [MJStatusManager sharedManager];
    NSString *elapsedTimeString = [manager elapsedTimeString];
    NSString *batteryLevelString = [manager batteryLevelString];
    NSString *usedMemoryInKBString = [manager usedMemoryInKBString];
    NSString *dropLabelString = [NSString stringWithFormat:@"%@/m", @(countDroppedSampleBuffer)];
    
//    NSString *sessionPreset = self.captureSession.sessionPreset;
//    NSString *dimensionLabelString = [NSString stringWithFormat:@"%@, 1/%d",
//                           [MJCaptureSessionPreset sizeStringByPreset:sessionPreset],
//                           frameDuration.timescale];
    
    NSString *timestamp = [PHCalendarCalculate timestampInShortMediumFormat];
//    NSString *statusString = [NSString stringWithFormat:@"%@ %@ %@ %@ Security Robot (c) 2020",
//                        timestamp, elapsedTimeString, batteryLevelString, usedMemoryInKBString];
    NSString *statusString = [NSString stringWithFormat:@"%@ %@ %@",
                        timestamp, batteryLevelString, usedMemoryInKBString];
//    NSString *statusString = [NSString stringWithFormat:@"%@ %@",
//                        timestamp, batteryLevelString];

    updateDrawString1 = ! updateDrawString1;
    if (updateDrawString1) {
        [self setDrawString1:statusString];
        NSUInteger length = [self.drawString1 lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        drawStringLength1 = (size_t) length;
        cDrawString1 = [self.drawString1 cStringUsingEncoding:NSUTF8StringEncoding];
        if (cDrawString1) {
            memset(&drawStringArray1, 0, sizeof(drawStringArray1));
            memcpy(&drawStringArray1, cDrawString1, drawStringLength1);
        }
    } else {
        [self setDrawString2:statusString];
        NSUInteger length = [self.drawString2 lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        drawStringLength2 = (size_t) length;
        cDrawString2 = [self.drawString2 cStringUsingEncoding:NSUTF8StringEncoding];
        if (cDrawString2) {
            memset(&drawStringArray2, 0, sizeof(drawStringArray2));
            memcpy(&drawStringArray2, cDrawString2, drawStringLength2);
        }
    }
    
    if (drawTitleLength == 0) {
        NSString *title = @"SECURITY ROBOT (c) 2020";
        drawTitleLength = (size_t) [title lengthOfBytesUsingEncoding:NSASCIIStringEncoding];
        drawTitleLength = (drawTitleLength > 0) ? drawTitleLength : 23;
        cDrawTitle = [title cStringUsingEncoding:NSASCIIStringEncoding];
        memset(&titleArray, 0, sizeof(titleArray));
        memcpy(&titleArray, cDrawTitle, drawTitleLength);
    }

    if (! self.timer) {
        NSTimeInterval interval = 1.0; // 3
        SEL sel = @selector(updateTimer:);
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:sel userInfo:nil repeats:YES];
        [self setTimer:timer];
    }
    
    NSString *string = nil;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        string = [manager description];
    else
        string = [manager descriptionWithTimestamp];
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    
    [self createWriterIfLargerThanMaxAndStartWriting];
    countStatus++;
}

- (void)restoreMediumRate:(NSTimer *)timer {
    [timer invalidate];
    [self setMediumFrameRate];
}

- (void)restoreMinRate:(NSTimer *)timer {
    [timer invalidate];
    [self setMinFrameRate];
}

- (void)startMaxRateTimer{
    if (self.maxRateTimer.valid) {
        [self.maxRateTimer invalidate];
    }

    NSTimeInterval interval = 30.0 * 1;
    SEL sel = @selector(restoreMinRate:);
    [self setMaxRateTimer:[NSTimer scheduledTimerWithTimeInterval:interval target:self selector:sel userInfo:nil repeats:NO]];
    [self setMaxFrameRate];
//    [self setMaxZoom];
} 



#pragma mark - enableTracking

- (void)enableTracking{
//    NSString *string = [NSString stringWithFormat:@"%s", __func__];
//    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    
    NSError *error = nil;
    [self.videoCaptureDevice lockForConfiguration:&error];
    if (error)
        [MJLogFileManager logErrorToFile:error file:@"log.txt"];
    else
        self.videoCaptureDevice.subjectAreaChangeMonitoringEnabled = YES;
    [self.videoCaptureDevice unlockForConfiguration];
}

- (void)disableTracking{
//    NSString *string = [NSString stringWithFormat:@"%s", __func__];
//    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    
    NSError *error = nil;
    [self.videoCaptureDevice lockForConfiguration:&error];
    if (error)
        [MJLogFileManager logErrorToFile:error file:@"log.txt"];
    else
        self.videoCaptureDevice.subjectAreaChangeMonitoringEnabled = NO;
    [self.videoCaptureDevice unlockForConfiguration];
}

#pragma mark - resetWriterInputTransform

- (void)resetWriterInputTransform:(UIInterfaceOrientation)orientation {
    interfaceOrientation = orientation;
    NSString *string = [MJCaptureSessionPreset interfaceOrientationString:orientation];
    NSString *log = [NSString stringWithFormat:@"%s: interfaceOrientation:%@, self.videoWriter.assetWriter.status:%ld", __func__, string, self.videoWriter.assetWriter.status];
    [MJLogFileManager logStringToFile:log file:@"log.txt"];
    
    if (self.videoWriter.assetWriter.status == AVAssetWriterStatusUnknown) {
        UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
        string = [MJCaptureSessionPreset deviceOrientationString:deviceOrientation];
        NSLog(@"%s: deviceOrientation:%@", __func__, string);
        
        // specify the prefered transform for the output file
        CGFloat rotationDegrees;
        switch (deviceOrientation) {
            case UIDeviceOrientationPortraitUpsideDown:
                rotationDegrees = -90.;
                break;
            case UIDeviceOrientationLandscapeLeft: // no rotation
                rotationDegrees = 0.0;
                break;
            case UIDeviceOrientationLandscapeRight:
                rotationDegrees = 180.;
                break;
            case UIDeviceOrientationPortrait:
            case UIDeviceOrientationUnknown:
            case UIDeviceOrientationFaceUp:
            case UIDeviceOrientationFaceDown:
            default:
                rotationDegrees = 90.;
                break;
        }
        
        CGFloat rotationRadians = DegreesToRadians(rotationDegrees);
        if (self.videoWriter.assetWriter && self.videoWriter.assetWriterVideoInput) {
            CGAffineTransform transform = self.videoWriter.assetWriterVideoInput.transform;
//            transform = CGAffineTransformRotate(transform, rotationRadians);
            transform = CGAffineTransformMakeRotation(rotationRadians);
            [self.videoWriter.assetWriterVideoInput setTransform:transform];
            
            NSString *log = [NSString stringWithFormat:@"%s: rotationRadians:%lf, rotationDegrees:%lf", __func__, rotationRadians, rotationDegrees];
            [MJLogFileManager logStringToFile:log file:@"log.txt"];
        }
    }
}

@end
