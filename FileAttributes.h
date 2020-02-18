//
//  FileAttributes.h
//  FlashDrive
//
//  Created by randcuba on 11/10/10.
//  Copyright 2010 MagicPoint. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface FileAttributes : NSObject {
    NSURL *fileURL;
    NSString *path;
	NSString *fileName;
	NSString *displayName;
	
	unsigned long long fileSize;
	NSString *fileType;
	NSDate *createdDate;
	NSDate *modifiedDate;
}
@property (nonatomic, retain) NSURL *fileURL;
@property (nonatomic, copy) NSString *path, *fileName;
@property (nonatomic, copy) NSString *displayName;

@property (nonatomic, assign) unsigned long long fileSize;
@property (nonatomic, copy) NSString *fileType;
@property (nonatomic, retain) NSDate *createdDate;
@property (nonatomic, retain) NSDate *modifiedDate;

- (NSString*)fileSizeString;
- (NSString*)modifiedDateString;

@end
