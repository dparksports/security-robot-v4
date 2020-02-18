//
//  FileAttributes.m
//  FlashDrive
//
//  Created by randcuba on 11/10/10.
//  Copyright 2010 MagicPoint. All rights reserved.
//

#import "FileAttributes.h"


@implementation FileAttributes
@synthesize fileURL, path, fileName, displayName;
@synthesize fileSize, fileType, createdDate, modifiedDate;


- (NSString*)description{
	return displayName;
}

- (NSString*)fileSizeString{
	
	NSString *unitString = @"B";
	float size = fileSize;

	if (size > 1024) {
		unitString = @"KB";
		size = size / 1024.0;
		
		if (size > 1024) {
			unitString = @"MB";
			size = size / 1024.0;
			
			if (size > 1024) {
				unitString = @"GB";
				size = size / 1024.0;
			}
		}
	}
	
	return [NSString stringWithFormat:@"%3.1f %@",size, unitString];
}

- (NSString*)modifiedDateString{
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateStyle:NSDateFormatterShortStyle];
	[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
	
	NSString *formattedDateString = [dateFormatter stringFromDate:modifiedDate];
	return formattedDateString;
}

@end
