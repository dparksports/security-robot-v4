//
//  MJAssetWriter.m
//  SecurityCam
//
//  Created by Dan Park on 11/12/14.
//  Copyright (c) 2014 MagicPoint. All rights reserved.
//

#import "MJLogFileManager.h"
#import "MJAssetWriter.h"

@interface MJAssetWriter ()

@property (nonatomic, assign) AVAssetWriterInput *assetWriterAudioInput;
@property (nonatomic, assign) AVAssetWriterInput *assetWriterVideoInput;
@end

@implementation MJAssetWriter{
    NSUInteger currentFileIndex;
    NSUInteger maxFileCount;
    NSUInteger maxFileSizeInByte;
}

- (void)dealloc {
    [self setAssetWriter:nil];
    NSLog(@"%s", __func__);
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSUInteger maxFileSizeInMB = 512 * 1; // 250
        maxFileSizeInByte = maxFileSizeInMB * 1024 * 1024;
        maxFileCount = [self maxFileCountBySize:maxFileSizeInMB];
    }
    return self;
}

- (NSFileHandle *)fileHandle {
    if (! self.assetWriter)
        return nil;
    if (! (self.assetWriter.status == AVAssetWriterStatusWriting ||
        self.assetWriter.status == AVAssetWriterStatusCompleted))
        return nil;

    NSError *error = nil;
    NSFileHandle *fileHandle  = [NSFileHandle fileHandleForReadingFromURL:self.assetWriter.outputURL error:&error];
    if (error) {
        NSLog(@"%s: error:%@", __func__, error);
        return nil;
    }
    else
        return fileHandle;
}

- (BOOL)isLargerThanMaxFileSize{
    BOOL isLarger = [self isLargerThan:maxFileSizeInByte];
    return isLarger;
}

- (BOOL)isLargerThan:(NSUInteger) maxSizeInByte{
    struct stat st;
    NSFileHandle *fileHandle = [self fileHandle];
    if (! fileHandle)
        return NO;
    
    int fileDescriptor = [fileHandle fileDescriptor];
    fstat(fileDescriptor, &st);
    BOOL isLarger = st.st_size > maxSizeInByte;
    return isLarger;
}

#pragma mark - rotateNewWriter

- (float) totalDiskSpaceInMB {
    NSDictionary *fattributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    NSNumber *number = [fattributes objectForKey:NSFileSystemSize];
    float units = [number floatValue] / 1024.0 / 1024.0;
    NSLog(@"%s: units: %.1f MB", __func__, units);
    return units;
}

- (float) freeDiskSpaceInMB {
    NSDictionary *fattributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    NSNumber *number = [fattributes objectForKey:NSFileSystemFreeSize];
    float units = [number floatValue] / 1024.0 / 1024.0;
    NSLog(@"%s: units: %.1f MB", __func__, units);
    return units;
}

- (NSInteger) maxFileCountBySize:(float)fileSizeInMB {
    float units = [self totalDiskSpaceInMB];
    units = [self freeDiskSpaceInMB] -  (1024 * 1); //1GB Free reserved
    float count = units / fileSizeInMB;
    NSLog(@"%s: fileCount: %.1f @ %.1f MB", __func__, count, fileSizeInMB);
    NSInteger fileCount = count;
    return fileCount;
}

- (NSString*)documentDirectory {
    BOOL expandTilde = YES;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, expandTilde);
    NSString *path = ([paths count] > 0) ? [paths firstObject] : nil;
    return path;
}

- (NSString*)rotateFilename:(NSUInteger)fileIndex {
    NSString *documentDirectory = [self documentDirectory];
    NSString *filename = [NSString stringWithFormat:@"video%lu.mp4", (unsigned long)fileIndex];
    NSString *pathString = [documentDirectory stringByAppendingPathComponent:filename];
    return pathString;
}

- (AVAssetWriter *)rotateNewWriter:(NSUInteger)fileIndex {
    NSString* pathString = [self rotateFilename:fileIndex];
    AVAssetWriter *writer = [self instanceWriter:pathString];
    [self setAssetWriter:writer];
    return writer;
}

- (AVAssetWriter *)createNewWriterByNextFileIndex{
    AVAssetWriter *writer = [self rotateNewWriter:currentFileIndex++];
    if (currentFileIndex >= maxFileCount)
        currentFileIndex = 1;
    return writer;
}

- (AVAssetWriter *)instanceWriter:(NSString*)pathString {
    NSString *string = [NSString stringWithFormat:@"%s: pathString:%@", __func__, pathString];
    [MJLogFileManager logStringToFile:string file:@"log.txt"];
    
    BOOL isDirectory;
    NSError *error = nil;
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:pathString isDirectory:&isDirectory]) {
        if (! [manager removeItemAtPath:pathString error:&error])
            NSLog(@"%s: error:%@", __func__, error);
    }
    
    NSURL* url = [NSURL fileURLWithPath:pathString];
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeQuickTimeMovie error:&error];
    if (error)
        NSLog(@"%s: error:%@", __func__, error);
    else {
        NSDictionary *settings = nil;
        settings = [NSDictionary dictionaryWithObjectsAndKeys:
                    AVVideoCodecH264, AVVideoCodecKey,
                    [NSNumber numberWithInt:1280], AVVideoWidthKey,
                    [NSNumber numberWithInt:720], AVVideoHeightKey,
                    nil];
        
//        if ([writer canApplyOutputSettings:settings forMediaType:AVMediaTypeAudio]) {
//            AVAssetWriterInput *assetWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:settings];
//            [self setAssetWriterAudioInput:assetWriterInput];
//            
//            _assetWriterAudioInput.expectsMediaDataInRealTime = YES;
//            if ([writer canAddInput:_assetWriterAudioInput])
//                [writer addInput:_assetWriterAudioInput];
//            else NSLog(@"assetWriterAudioInput: canAddInput failed.");
//        }
//        else NSLog(@"assetWriterAudioInput: canApplyOutputSettings failed.");

        if ([writer canApplyOutputSettings:settings forMediaType:AVMediaTypeVideo]) {
            AVAssetWriterInput *assetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
            [self setAssetWriterVideoInput:assetWriterInput];
            
            _assetWriterVideoInput.expectsMediaDataInRealTime = YES;
            if ([writer canAddInput:_assetWriterVideoInput]) {
                [writer addInput:_assetWriterVideoInput];
                return writer;
            }
            else NSLog(@"assetWriterVideoInput: canAddInput failed.");
        }
        else NSLog(@"assetWriterVideoInput: canApplyOutputSettings failed.");
    }
    return nil;
}

@end
