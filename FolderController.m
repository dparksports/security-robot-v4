//
//  FolderController.m
//  Flash Drive
//
//  Created by Dan Park on 1/10/15.
//  Copyright (c) 2015 magicpoint.us. All rights reserved.
//

#import "FileAttributes.h"
#import "DirectoryWatcher.h"
#import "FileManager.h"
#import "FolderTableCell.h"
#import "FolderController.h"

@interface FolderController ()
<QLPreviewControllerDataSource, QLPreviewControllerDelegate, DirectoryWatcherDelegate, UIDocumentInteractionControllerDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) DirectoryWatcher *docWatcher;
@property (nonatomic, strong) NSMutableArray *sortAttributes;
@property (nonatomic, strong) NSMutableDictionary *fileAttributes;
//@property (nonatomic, strong) NSMutableDictionary *fileAttributeIndex;
@property (nonatomic, strong) UIDocumentInteractionController *documentInteractionController;
@end

@implementation FolderController{
    BOOL showFree;
    NSString *availableTitle;
    NSString *totalTitle;
    __weak IBOutlet UIProgressView *progressView;
    __weak IBOutlet UIButton *availableButton;
    __weak IBOutlet UITableView *tableView;
}

#pragma mark - dealloc

- (void)dealloc {
    NSLog(@"%s", __func__);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"%s", __func__);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    NSLog(@"%s", __func__);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (! _fileAttributes)
        self.fileAttributes = [NSMutableDictionary dictionary];
    if (! _sortAttributes) {
        self.sortAttributes = [NSMutableArray array];
        [self toggleFreeOrTotal:nil];
    }
    
    if (! _folderAtPath) {
        NSArray *files = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [files firstObject];
        [self setFolderAtPath:documentsDirectory];
    }
    
    NSLog(@"%s: _documentInteractionController:%@", __func__, _documentInteractionController);
    if (! _documentInteractionController) {
        NSURL *fileURL = [NSURL fileURLWithPath:_folderAtPath];
        self.documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
        self.documentInteractionController.delegate = self;
    }
    
    if (! _docWatcher) {
        self.docWatcher = [DirectoryWatcher watchFolderWithPath:_folderAtPath delegate:self];
        [self directoryDidChange:self.docWatcher];
    }
    
    UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                                    style:UIBarButtonItemStyleDone
                                                                   target:self
                                                                   action:@selector(closeView:)];
    NSArray *barButtonItems = @[buttonItem];
    self.navigationItem.leftBarButtonItems = barButtonItems;
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.navigationItem.title = [_folderAtPath lastPathComponent];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    NSLog(@"%s", __func__);
    [tableView setEditing:editing animated:YES];
}

#pragma mark - UITableViewDataSource

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title = nil;
    title = [NSString stringWithFormat:@"%@ folder", [_folderAtPath lastPathComponent]];
    return title;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSUInteger count = 1;
    return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUInteger count = [self.sortAttributes count];
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    FolderTableCell *cell = [aTableView dequeueReusableCellWithIdentifier:@"FolderTableCellID"];
    if (cell) {
        FileAttributes *attributes = [self.sortAttributes objectAtIndex:indexPath.row];
        self.documentInteractionController.URL = attributes.fileURL;
        cell.titleLabel.text = [self.documentInteractionController name];
        if ([self.documentInteractionController.icons count] > 0)
            cell.iconView.image = [self.documentInteractionController.icons lastObject];
        
        cell.titleLabel.text = [attributes displayName];
        cell.timetampLabel.text = [attributes modifiedDateString];
//        NSString* pathExtension = [self.documentInteractionController.UTI pathExtension];
//        cell.timetampLabel.text = [NSString stringWithFormat:@"%@ - %@", pathExtension, [attributes modifiedDateString]];
        
        NSString* filePath = [attributes path];
        if ([FileManager isDirectoryUTIAtPath:filePath withUTI:self.documentInteractionController.UTI])
            cell.sizeLabel.text = [NSString stringWithFormat:@"%lu File(s)", (unsigned long)[FileManager fileCountAtPath:filePath]];
        else {
            long long fileSize = [attributes fileSize];
            NSString *fileSizeString = [NSByteCountFormatter stringFromByteCount:fileSize countStyle:NSByteCountFormatterCountStyleBinary];
            cell.sizeLabel.text = fileSizeString;
        }
    }
    return cell;
}

#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)atableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"%s", __func__);
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        FileAttributes *attributes = [self.sortAttributes objectAtIndex:indexPath.row];
        NSString *filePath = [attributes.fileURL path];
        [self performSelectorInBackground:@selector(deleteSelectedFileName:) withObject:filePath];
        
        [self.sortAttributes removeObjectAtIndex:indexPath.row];
        NSArray *indexPathsToDelete = [NSArray arrayWithObject:indexPath];
        [atableView deleteRowsAtIndexPaths:indexPathsToDelete withRowAnimation:UITableViewRowAnimationTop];
    }
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"%s: _folderAtPath:%@", __func__, _folderAtPath);
    
    [aTableView deselectRowAtIndexPath:indexPath animated:YES];
    FileAttributes *attributes = [self.sortAttributes objectAtIndex:indexPath.row];
    self.documentInteractionController.URL = attributes.fileURL;
    
    NSString *filePath = [attributes.fileURL path];
    if ([FileManager isDirectoryUTIAtPath:filePath withUTI:self.documentInteractionController.UTI]) {
        FolderController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"FolderControllerID"];
        [controller setFolderAtPath:filePath];
        [self.navigationController pushViewController:controller animated:YES];
    }
    else {
        NSString *lastPathComponent = [_folderAtPath lastPathComponent];
        if ([lastPathComponent isEqualToString:@"Inbox"]) {
            [self loadSelectedFileName:filePath];
        } else {
            BOOL canPreviewItem = [QLPreviewController canPreviewItem:attributes.fileURL];
            if (canPreviewItem)
                [self previewDocumentAtIndexPath:indexPath];
            else
                [self loadSelectedFileName:filePath];
        }
    }
}

#pragma mark - UIDocumentInteractionControllerDelegate

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)interactionController {
    NSLog(@"%s", __func__);
    return self;
}

#pragma mark - QLPreviewControllerDelegate

- (void)previewControllerWillDismiss:(QLPreviewController *)controller{
    NSLog(@"%s", __func__);
}

- (void)previewControllerDidDismiss:(QLPreviewController *)controller {
    NSLog(@"%s", __func__);
}

- (BOOL)previewController:(QLPreviewController *)controller shouldOpenURL:(NSURL *)url forPreviewItem:(id <QLPreviewItem>)item {
    BOOL canPreviewItem = [QLPreviewController canPreviewItem:item];
    NSLog(@"%s: canPreviewItem:%d", __func__, canPreviewItem);
    
    return canPreviewItem;
}

- (CGRect)previewController:(QLPreviewController *)controller frameForPreviewItem:(id <QLPreviewItem>)item inSourceView:(UIView **)view {
    NSLog(@"%s", __func__);
    return CGRectZero;
}

- (UIImage *)previewController:(QLPreviewController *)controller transitionImageForPreviewItem:(id <QLPreviewItem>)item contentRect:(CGRect *)contentRect {
    NSLog(@"%s", __func__);
    return nil;
}

#pragma mark - QLPreviewControllerDataSource

// Returns the number of items that the preview controller should preview
- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)previewController {
    NSInteger numToPreview = self.sortAttributes.count;
    return numToPreview;
}

// returns the item that the preview controller should preview
- (id)previewController:(QLPreviewController *)previewController previewItemAtIndex:(NSInteger)index {
    FileAttributes *attributes = [self.sortAttributes objectAtIndex:index];
    NSURL *documentURL = attributes.fileURL;
    return documentURL;
}

#pragma mark - directoryDidChange

- (void)directoryDidChange:(DirectoryWatcher *)folderWatcher {
    NSLog(@"%s", __func__);
    [self.sortAttributes removeAllObjects];
    [self.fileAttributes removeAllObjects];
    
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *documentsDirectoryContents = [fileManager contentsOfDirectoryAtPath:_folderAtPath error:&error];
    if (error)
        NSLog(@"%s: error:%@", __func__, [error localizedDescription]);
    
    NSMutableArray *documentURLs = [NSMutableArray new];
    for (NSString* fileName in documentsDirectoryContents) {
        NSString *filePath = [_folderAtPath stringByAppendingPathComponent:fileName];
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        [documentURLs addObject:fileURL];
    }

    for (NSURL *fileURL in documentURLs) {
        FileAttributes *attributes = [self.fileAttributes objectForKey:fileURL];
        if (! attributes) {
            NSString *filePath = [fileURL path];
            attributes = [FileManager onefileAttributesAtPath:filePath];
            attributes.fileURL = fileURL;
            [self.fileAttributes setObject:attributes forKey:fileURL];
            [self.sortAttributes addObject:attributes];
        }
    }
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"modifiedDate" ascending:TRUE];
    [self.sortAttributes sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [tableView reloadData];
}

- (void)loadSelectedFileName:(NSString*)filePath {
    NSLog(@"filePath:%@", filePath);
    
    NSURL *documentPathURL = [NSURL fileURLWithPath:filePath isDirectory:NO];
    MPMoviePlayerViewController *controller = [[MPMoviePlayerViewController alloc] initWithContentURL:documentPathURL];
    [self presentViewController:controller animated:YES completion:^(void) {
    }];
}

- (void)deleteSelectedFileName:(NSString*)filePath {
    NSLog(@"%s:selectedFileName:%@", __FUNCTION__, filePath);
    [FileManager deleteFileAtPath:filePath];
}

- (void)previewDocumentAtIndexPath:(NSIndexPath *)indexPath  {
    NSLog(@"%s: indexPath.row:%ld", __func__,(long)indexPath.row);
    
    // three ways to present a preview:
    // 1. Don't implement this method and simply attach the canned gestureRecognizers to the cell
    //
    // 2. Don't use canned gesture recognizers and simply use UIDocumentInteractionController's
    //      presentPreviewAnimated: to get a preview for the document associated with this cell
    //
    // 3. Use the QLPreviewController to give the user preview access to the document associated
    //      with this cell and all the other documents as well.
    
    // for case 2 use this, allowing UIDocumentInteractionController to handle the preview:
    
    QLPreviewController *previewController = [[QLPreviewController alloc] init];
    previewController.dataSource = self;
    previewController.delegate = self;
    
    // start previewing the document at the current section index
    previewController.currentPreviewItemIndex = indexPath.row;
    [self presentViewController:previewController animated:YES completion:^(void) {
    }];

}

#pragma mark - IBAction

- (NSNumber *) totalDiskSpace {
    NSDictionary *fattributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    return [fattributes objectForKey:NSFileSystemSize];
}

- (NSNumber *) freeDiskSpace {
    NSDictionary *fattributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    
    return [fattributes objectForKey:NSFileSystemFreeSize];
}

- (void)refreshCapacity{
    NSNumber *totalDiskSpace = [self totalDiskSpace];
    NSNumber *freeDiskSpace = [self freeDiskSpace];
    
    // dpark: occupiedUnits doesn't count the 150MB reserve to exaggerate the free spacd graph.
    float occupiedUnits = ([totalDiskSpace floatValue] - [freeDiskSpace floatValue]) / [totalDiskSpace floatValue];
    progressView.progress = occupiedUnits;
    
    // dpark: in MBytes.
    float totalUnits = [totalDiskSpace floatValue] / 1024.0 / 1024.0;
    float freeUnits = [freeDiskSpace floatValue] / 1024.0 / 1024.0;
    // dpark: 180MB reserved for system?
    freeUnits -= 180;
    NSLog(@"%s:freeUnits:%lf", __FUNCTION__, freeUnits);
    
    if (freeUnits < 1024) {
        if (freeUnits < 1.0)  {
            freeUnits = freeUnits * 1024.0;
            
            if (freeUnits < 0)
                freeUnits = 0;
            
            availableTitle = [NSString stringWithFormat:@"%3.1fKB Free", freeUnits];
        }
        else
            availableTitle = [NSString stringWithFormat:@"%3.1fMB Free", freeUnits];
    }
    else {
        freeUnits = freeUnits / 1024.0;
        availableTitle = [NSString stringWithFormat:@"%3.1fGB Free", freeUnits];
    }
    
    if (totalUnits < 1024)
        totalTitle = [NSString stringWithFormat:@"%3.1fMB Total", totalUnits];
    else {
        totalUnits = totalUnits / 1024.0;
        totalTitle = [NSString stringWithFormat:@"%3.1fGB Total", totalUnits];
    }
}

- (IBAction)refreshFileManager:(id)sender {
    NSLog(@"%s", __func__);
    [self directoryDidChange:self.docWatcher];
    [tableView reloadData];
}

- (IBAction) toggleFreeOrTotal:(id)sender {
    NSLog(@"%s", __func__);
    [self refreshCapacity];
    
    showFree = ! showFree;
    NSString *title = (showFree) ? availableTitle : totalTitle;
    [availableButton setTitle:title forState:UIControlStateNormal];
}

- (IBAction)closeView:(id)sender {
    NSLog(@"%s", __func__);
    [self dismissViewControllerAnimated:YES completion:^(void){
    }];
}

@end
