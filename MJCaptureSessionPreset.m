//
//  MJCaptureSessionPreset.m
//  MJLibrary
//
//  Created by Dan Park on 8/26/14.
//  Copyright (c) 2014 Magic Point. All rights reserved.
//

#import "MJCaptureSessionPreset.h"
#import "MJDeviceModel.h"

@implementation MJCaptureSessionPreset

+ (CGFloat)radiansFromVideoOrientation:(AVCaptureVideoOrientation)videoOrientation {
    CGFloat degrees = 0;
    switch (videoOrientation) {
        case AVCaptureVideoOrientationLandscapeLeft:
            degrees = 0;
            break;
        case AVCaptureVideoOrientationLandscapeRight:
            degrees = 180;
            break;
        case AVCaptureVideoOrientationPortrait:
            degrees = 90;
            break;
        case AVCaptureVideoOrientationPortraitUpsideDown :
            degrees = -90;
            break;
        default:
            degrees = 0;
            break;
    }
    
    NSString *string = [MJCaptureSessionPreset videoOrientationOrientationString:videoOrientation];
    NSLog(@"%s: videoOrientation:%@", __func__, string);
    NSLog(@"%s: degrees:%lf", __func__, degrees);
    
    CGFloat angleInRadians = degrees * 3.1415926/180.0;
    return angleInRadians;
}

+ (NSString*)deviceOrientationString:(UIDeviceOrientation)deviceOrientation {
    switch (deviceOrientation) {
        case UIDeviceOrientationUnknown:
            return @"UIDeviceOrientationUnknown";
        case UIDeviceOrientationFaceUp:
            return @"UIDeviceOrientationFaceUp";
        case UIDeviceOrientationFaceDown:
            return @"UIDeviceOrientationFaceDown";
        case UIDeviceOrientationLandscapeRight:
            return @"UIDeviceOrientationLandscapeRight";
        case UIDeviceOrientationLandscapeLeft:
            return @"UIDeviceOrientationLandscapeLeft";
        case UIDeviceOrientationPortrait:
            return @"UIDeviceOrientationPortrait";
        case UIDeviceOrientationPortraitUpsideDown :
            return @"UIDeviceOrientationPortraitUpsideDown";
        default:
            return @"UIDeviceOrientationDefault";
    }
}

+ (NSString*)interfaceOrientationString:(UIInterfaceOrientation)interfaceOrientation {
    switch (interfaceOrientation) {
        case UIInterfaceOrientationPortrait:
            return @"UIInterfaceOrientationPortrait";
        case UIInterfaceOrientationPortraitUpsideDown:
            return @"UIInterfaceOrientationPortraitUpsideDown";
        case UIInterfaceOrientationLandscapeLeft:
            return @"UIInterfaceOrientationLandscapeLeft";
        case UIInterfaceOrientationLandscapeRight :
            return @"UIInterfaceOrientationLandscapeRight";
        case UIInterfaceOrientationUnknown :
            return @"UIInterfaceOrientationUnknown";
        default:
            return @"UIDeviceOrientationDefault";
    }
}

+ (NSString*)videoOrientationOrientationString:(AVCaptureVideoOrientation)videoOrientation {
    switch (videoOrientation) {
        case AVCaptureVideoOrientationLandscapeLeft:
            return @"AVCaptureVideoOrientationLandscapeLeft";
        case AVCaptureVideoOrientationLandscapeRight:
            return @"AVCaptureVideoOrientationLandscapeRight";
        case AVCaptureVideoOrientationPortrait:
            return @"AVCaptureVideoOrientationPortrait";
        case AVCaptureVideoOrientationPortraitUpsideDown :
            return @"AVCaptureVideoOrientationPortraitUpsideDown";
        default:
            return @"AVCaptureVideoOrientationDefault";
    }
}

+ (AVCaptureVideoOrientation)convertToVideoOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    // video orientation is always in the direction of gravity for the viewer.
    // to support so: Landscape right is video orientation left.
    // and vice versa: Landscape left is  video orientation right
    switch (fromInterfaceOrientation) {
        case UIDeviceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeLeft;
        default:
        case UIDeviceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeRight;
        case UIDeviceOrientationPortrait:
            return AVCaptureVideoOrientationPortrait;
        case UIDeviceOrientationPortraitUpsideDown :
            return AVCaptureVideoOrientationPortraitUpsideDown;
    }
}

+ (NSString*)sizeStringByPreset:(NSString*)preset {
    CGSize size = [self.class sizeBySessionPreset:preset];
    NSString *string = [NSString stringWithFormat:@"%.0f", size.height];
    return string;
}

+ (CGSize)sizeBySessionPreset:(NSString*)preset {
    CGSize size = CGSizeMake(720, 480);
    if ([preset rangeOfString:AVCaptureSessionPreset1920x1080].location != NSNotFound)
        size = CGSizeMake(1920, 1080);
    if ([preset rangeOfString:AVCaptureSessionPreset1280x720].location != NSNotFound)
        size = CGSizeMake(1280, 720);
    if ([preset rangeOfString:AVCaptureSessionPreset640x480].location != NSNotFound) {
        if ([MJDeviceModel isClassThree] || [MJDeviceModel isClassFour]) {
            // class three and four
            size = CGSizeMake(640, 480);
        } else {
            // class five and six
            size = CGSizeMake(640, 480);
//            size = CGSizeMake(720, 480);
//            size = CGSizeMake(1280, 720);
//            size = CGSizeMake(1920, 1080);
        }
    }
    if ([preset rangeOfString:AVCaptureSessionPreset352x288].location != NSNotFound){
        if ([MJDeviceModel isClassThree] || [MJDeviceModel isClassFour]) {
            // class three and four
            size = CGSizeMake(352, 288);
        } else {
            // class five and six
//            size = CGSizeMake(352, 288);
//            size = CGSizeMake(640, 480);
//            size = CGSizeMake(720, 480);
//            size = CGSizeMake(1280, 720);
            size = CGSizeMake(1920, 1080);
        }
    }
    
    if ([preset rangeOfString:AVCaptureSessionPresetiFrame1280x720].location != NSNotFound)
        size = CGSizeMake(1280, 720);
    if ([preset rangeOfString:AVCaptureSessionPresetiFrame960x540].location != NSNotFound)
        size = CGSizeMake(960, 540);
    
    if ([preset rangeOfString:AVCaptureSessionPresetHigh].location != NSNotFound) {
        if ([MJDeviceModel isClassThree] || [MJDeviceModel isClassFour]) {
            size = CGSizeMake(1280, 720);
        } else {
            // class five and six
            size = CGSizeMake(1920, 1080);
        }
    }
    if ([preset rangeOfString:AVCaptureSessionPresetMedium].location != NSNotFound) {
        if ([MJDeviceModel isClassThree] || [MJDeviceModel isClassFour]) {
            // class three and four
//            size = CGSizeMake(352, 288);
            size = CGSizeMake(480, 360);
        } else {
            // class five and six
//            size = CGSizeMake(352, 288);
            size = CGSizeMake(480, 360);
//            size = CGSizeMake(640, 480);
//            size = CGSizeMake(720, 480);
//            size = CGSizeMake(1280, 720);
//            size = CGSizeMake(1920, 1080);
        }
    }
    if ([preset rangeOfString:AVCaptureSessionPresetLow].location != NSNotFound) {
        if ([MJDeviceModel isClassThree]) {
            // 4V: Class Three
            size = CGSizeMake(192, 144);
//            size = CGSizeMake(352, 288);
//            size = CGSizeMake(640, 480);
//            size = CGSizeMake(720, 480);
//            size = CGSizeMake(1280, 720); // frequent connection drops
//            size = CGSizeMake(1920, 1080); // asset write error
        } else {
            if ([MJDeviceModel isClassFour]) {
                // iPod4G: Class 4
                size = CGSizeMake(192, 144);
//                size = CGSizeMake(352, 288);
            } else {
                size = CGSizeMake(192, 144);
//                size = CGSizeMake(352, 288);
//                size = CGSizeMake(640, 480);
//                size = CGSizeMake(720, 480);
//                size = CGSizeMake(1280, 720);
//                size = CGSizeMake(1920, 1080);
            }
        }
    }

//    NSLog(@"%s: size:%@", __func__, NSStringFromCGSize(size));
    return size;
}

+ (CMTime)frameDurationBySessionPreset:(NSString*)preset {
    // For single core systems like iPhone 3GS, iPhone 4 and iPod Touch 4th Generation we use a lower resolution and framerate to increase performance.
//    CMTime frameDuration = kCMTimeInvalid;
//    if ( [[NSProcessInfo processInfo] processorCount] == 1 ) {
//        if ( [_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480] )
//            _captureSession.sessionPreset = AVCaptureSessionPreset640x480;
//        frameDuration = CMTimeMake( 1, 15 );
//    }
//    else {
//        frameDuration = CMTimeMake( 1, 30 );
//    }
    
    CMTime frameDuration = CMTimeMake(1, 4);
    NSString *hardware = [MJDeviceModel hardwareString];
    
    if ([hardware isEqualToString:@"iPhone2,1"]) {
        // 3GS: GSM Long Duration (4)
        if ([preset rangeOfString:AVCaptureSessionPresetHigh].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 5 );
        if ([preset rangeOfString:AVCaptureSessionPresetMedium].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 5 );
        if ([preset rangeOfString:AVCaptureSessionPresetLow].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 5 );
        if ([preset rangeOfString:AVCaptureSessionPreset1280x720].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 5 );
        if ([preset rangeOfString:AVCaptureSessionPreset640x480].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 5 );
    }
    if ([hardware isEqualToString:@"iPhone3,3"]) {
        // GSM/CDMA:iPhone3,3(15), GSM Long Duration (4)
        if ([preset rangeOfString:AVCaptureSessionPresetHigh].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 6 );
        // GSM/CDMA:iPhone3,3(15), GSM Long Term (4:video freeze?, 5:)
        if ([preset rangeOfString:AVCaptureSessionPresetMedium].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 6 );
        if ([preset rangeOfString:AVCaptureSessionPresetLow].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 6 );
        if ([preset rangeOfString:AVCaptureSessionPreset1280x720].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 6 );
        if ([preset rangeOfString:AVCaptureSessionPreset640x480].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 6 );
    }
    if ([hardware isEqualToString:@"iPhone4,1"]) {
        // 4S(30), 4S Long Term (4:video freeze", 5:)
        if ([preset rangeOfString:AVCaptureSessionPreset1920x1080].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 5 );
        if ([preset rangeOfString:AVCaptureSessionPreset1280x720].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 5 );
        if ([preset rangeOfString:AVCaptureSessionPreset640x480].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 5 );
        if ([preset rangeOfString:AVCaptureSessionPresetHigh].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 5 );
    }
    // 5(30), 5 Long Term (4:video freeze, 6:)
    if ([hardware isEqualToString:@"iPhone5,2"]) {
        if ([preset rangeOfString:AVCaptureSessionPreset1920x1080].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 6 );
        if ([preset rangeOfString:AVCaptureSessionPreset1280x720].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 6 );
        if ([preset rangeOfString:AVCaptureSessionPreset640x480].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 8 );
        if ([preset rangeOfString:AVCaptureSessionPresetHigh].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 6 );
        if ([preset rangeOfString:AVCaptureSessionPresetMedium].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 8 );
        if ([preset rangeOfString:AVCaptureSessionPresetLow].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 8 );
    }
    // 5S(30), 5S Long Term (night mode:4-12)
    if ([hardware isEqualToString:@"iPhone6,1"]) {
        if ([preset rangeOfString:AVCaptureSessionPreset1920x1080].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 4 );
        if ([preset rangeOfString:AVCaptureSessionPreset1280x720].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 4 );
        if ([preset rangeOfString:AVCaptureSessionPreset640x480].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 12 );
        if ([preset rangeOfString:AVCaptureSessionPresetHigh].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 12 );
        if ([preset rangeOfString:AVCaptureSessionPresetMedium].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 12 );
        if ([preset rangeOfString:AVCaptureSessionPresetLow].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 12 );
    }
    // 6+(30), 6+ Long Term (4:video freeze?, 6:)
    if ([hardware isEqualToString:@"iPhone7,1"]) {
        if ([preset rangeOfString:AVCaptureSessionPreset1920x1080].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 24 );
        if ([preset rangeOfString:AVCaptureSessionPreset1280x720].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 24 );
        if ([preset rangeOfString:AVCaptureSessionPreset640x480].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 24 );
        if ([preset rangeOfString:AVCaptureSessionPresetMedium].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 12 );
    }
    if ([hardware isEqualToString:@"iPod4,1"]) {
        // iPod(30), iPod Long Term (4:video freeze", 5:)
        if ([preset rangeOfString:AVCaptureSessionPreset1280x720].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 4 );
        if ([preset rangeOfString:AVCaptureSessionPreset640x480].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 4 );
        if ([preset rangeOfString:AVCaptureSessionPresetHigh].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 4 );
        if ([preset rangeOfString:AVCaptureSessionPresetMedium].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 4 );
        if ([preset rangeOfString:AVCaptureSessionPresetLow].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 4 );
    }
    if ([hardware isEqualToString:@"iPad2,3"]) {
        if ([preset rangeOfString:AVCaptureSessionPreset1920x1080].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 5 );
        // 6+(30), 6+ Long Term (4:video freeze?, 6:)
        if ([preset rangeOfString:AVCaptureSessionPreset1280x720].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 5 );
        // 6+(30), 6+ Long Term (4:video freeze?, 6:)
        if ([preset rangeOfString:AVCaptureSessionPreset640x480].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 5 );
        // 6+(30), 6+ Long Term (4:video freeze?, 5:)
        if ([preset rangeOfString:AVCaptureSessionPresetMedium].location != NSNotFound)
            frameDuration = CMTimeMake( 1, 5 );
    }
    
    NSLog(@"%s: hardware:%@, processorCount:%lu, frameDuration:%lld/%d", __func__, hardware, (unsigned long)[[NSProcessInfo processInfo] processorCount], frameDuration.value, frameDuration.timescale);
    return frameDuration;
}

+ (CGFloat)fontSizeBySessionPreset:(NSString*)preset {
    static CGFloat size = 18;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if ([preset rangeOfString:AVCaptureSessionPreset1920x1080].location != NSNotFound) {
            if ([MJDeviceModel isClassTwo]) {
                size = 22;
            }
            else if ([MJDeviceModel isClassFour] || [MJDeviceModel isClassThree]) {
                size = 44;
            } else {
                size = 67; // 67 max
            }
        }
        if ([preset rangeOfString:AVCaptureSessionPreset1280x720].location != NSNotFound){
            if ([MJDeviceModel isClassTwo]) {
                size = 17;
            }
            else if ([MJDeviceModel isClassFour] || [MJDeviceModel isClassThree]) {
                size = 34; // not supported?
            } else {
                size = 48; // 23 max
            }
        }
        if ([preset rangeOfString:AVCaptureSessionPreset640x480].location != NSNotFound){
            if ([MJDeviceModel isClassTwo]) {
                size = 22;
            }
            else if ([MJDeviceModel isClassThree]) {
                size = 22;
            }
            else if ([MJDeviceModel isClassFour]) {
                size = 22;
            }
            else if ([MJDeviceModel isClassFive]) {
                size = 31;
            }
            else if ([MJDeviceModel isClassSix]) {
                size = 31;
            }
            else if ([MJDeviceModel isClassSeven]) {
                size = 31;
            }
            else {
                size = 31;
            }
        }
        if ([preset rangeOfString:AVCaptureSessionPreset352x288].location != NSNotFound) {
            if ([MJDeviceModel isClassTwo]) {
                size = 13;
            }
            else if ([MJDeviceModel isClassThree]) {
                size = 17;
            }
            else if ([MJDeviceModel isClassFour]) {
                size = 17;
            }
            else if ([MJDeviceModel isClassFive]) {
                size = 18;
            }
            else if ([MJDeviceModel isClassSix]) {
                size = 18;
            }
            else if ([MJDeviceModel isClassSeven]) {
                size = 18;
            }
            else {
                size = 16; // 16 max
            }
        }
        
        if ([preset rangeOfString:AVCaptureSessionPresetiFrame1280x720].location != NSNotFound){
            if ([MJDeviceModel isClassFour] || [MJDeviceModel isClassThree]) {
                size = 34;
            } else {
                size = 45; // 45 max
            }
        }
        if ([preset rangeOfString:AVCaptureSessionPresetiFrame960x540].location != NSNotFound){
            if ([MJDeviceModel isClassFour] || [MJDeviceModel isClassThree]) {
                size = 32; 
            } else {
                size = 32; // 32 max
            }
        }
        
        // readability off at 10
        if ([preset rangeOfString:AVCaptureSessionPresetLow].location != NSNotFound)  {
            if ([MJDeviceModel isClassTwo]) {
                size = 8;
            }
            else if ([MJDeviceModel isClassThree]) {
                size = 10;  //4V: 8
            }
            else if ([MJDeviceModel isClassFour]) {
                size = 10;  //4V: 8
            }
            else if ([MJDeviceModel isClassFive]) {
                size = 10;  //4V: 8
            }
            else if ([MJDeviceModel isClassSix]) {
                size = 12;  //iPod4G: 10
            }
            else if ([MJDeviceModel isClassSeven]) {
                size = 12;  //iPod4G: 10
            }
            else {
                size = 12; // 16 max
            }
        }
        if ([preset rangeOfString:AVCaptureSessionPresetMedium].location != NSNotFound) {
            if ([MJDeviceModel isClassTwo]) {
                size = 20;
            }
            else if ([MJDeviceModel isClassThree]) {
                size = 22;
            }
            else if ([MJDeviceModel isClassFour]) {
                size = 24;
            }
            else if ([MJDeviceModel isClassFive]) {
                size = 24;
            }
            else if ([MJDeviceModel isClassSix]) {
                size = 24;
            }
            else if ([MJDeviceModel isClassSeven]) {
                size = 24;
            }
            else {
                size = 24;
            }
        }
        if ([preset rangeOfString:AVCaptureSessionPresetHigh].location != NSNotFound) {
            if ([MJDeviceModel isClassTwo]) {
                size = 12 * 3;
            }
            else if ([MJDeviceModel isClassThree]) {
                size = 36;      //manual size
            }
            else if ([MJDeviceModel isClassFour]) {
                size = 36;      //iPod:36, GSM:46
            }
            else if ([MJDeviceModel isClassFive]) {
                size = 54;      //manual size
            }
            else if ([MJDeviceModel isClassSix]) {
                size = 54;      //manual size
            }
            else if ([MJDeviceModel isClassSeven]) {
                size = 54;      //manual size
            }
            else {
                size = 12 * 4;      //manual size
            }
        }
    });

//    NSLog(@"%s: preset:%@, size:%.0f", __func__, preset, size);
    return size;
}
@end
