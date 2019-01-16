//
//  DropboxBackupFilePicker.m
//  ShopFolder
//
//  Created by Michael on 2012/12/24.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DropboxBackupFilePicker.h"

@interface DropboxBackupFilePicker ()
@property (nonatomic, strong) DBRestClient *_restClient;
@end

@implementation DropboxBackupFilePicker
@synthesize _restClient;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    hud.labelText = NSLocalizedString(@"Connecting to Dropbox", nil);
    hud.detailsLabelText = NSLocalizedString(@"Please wait", nil);
    [hud show:YES];
    
    [self._restClient loadMetadata:@"/"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (DBRestClient *)_restClient
{
    if (!_restClient) {
        _restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        _restClient.delegate = self;
    }
    
    return _restClient;
}

- (void)restClient:(DBRestClient *)client loadedMetadata:(DBMetadata *)metadata
{
    if (metadata.isDirectory) {
        NSLog(@"Folder '%@' contains:", metadata.path);
        [fileList removeAllObjects];
        BackupFileProperty *fileProp;
        for (DBMetadata *file in metadata.contents) {
            NSLog(@"\t%@", file.filename);
            if([file.filename hasPrefix:kBackupFileNamePrefix] &&
               [file.filename hasSuffix:kBackupFileNameSuffix])
            {
                fileProp = [BackupFileProperty new];
                fileProp.name = file.filename;
                fileProp.sizeInByte = [NSNumber numberWithUnsignedLongLong:file.totalBytes];
                [fileList addObject:fileProp];
            }
        }
        
        //List newest backup file at top
        [fileList sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [(BackupFileProperty *)obj2 compare:(BackupFileProperty *)obj1];
        }];
    }
    
    [self.table reloadData];
    [hud hide:YES];
}

- (void)restClient:(DBRestClient *)client loadMetadataFailedWithError:(NSError *)error
{
    NSLog(@"Error loading metadata: %@", error);
    [hud hide:YES];
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Dropbox Error"
                                                        message:@"Cannot get file list from Dropbox"
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Dismiss", nil)
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [self.delegate selectBackupFile:nil];
}

@end
