//
//  iTunesBackupFilePicker.m
//  ShopFolder
//
//  Created by Michael on 2012/12/24.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "iTunesBackupFilePicker.h"
#import "StringUtil.h"

@interface iTunesBackupFilePicker ()

@end

@implementation iTunesBackupFilePicker

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* documentsDirectory = [paths objectAtIndex:0];
        NSArray *fileNameList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
        [fileList removeAllObjects];
        BackupFileProperty *fileProp;
        NSDictionary *fileAttributes;
        for(NSString *fileName in fileNameList) {
            if([fileName hasPrefix:kBackupFileNamePrefix] &&
               [fileName hasSuffix:kBackupFileNameSuffix])
            {
                fileProp = [BackupFileProperty new];
                fileProp.name = fileName;
                
                fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[StringUtil fullPathInDocument:fileName]
                                                                                  error:nil];
                fileProp.sizeInByte = [NSNumber numberWithUnsignedLongLong:[fileAttributes fileSize]];
                [fileList addObject:fileProp];
            }
        }
        
        //List newest backup file at top
        [fileList sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [(BackupFileProperty *)obj2 compare:(BackupFileProperty *)obj1];
        }];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
