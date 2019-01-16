//
//  FolderListViewController.m
//  ShopFolder
//
//  Created by Michael on 2012/11/15.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "FolderListViewController.h"
#import "CoreDataDatabase.h"
#import "DBItemBasicInfo+SetAdnGet.h"
#import "LoadedBasicInfoData.h"
#import "UIImage+Resize.h"
#import "UIImage+RoundedCorner.h"
#import "ListItemInFolderViewController.h"
#import "UIView+ConverToImage.h"
#import <QuartzCore/QuartzCore.h>

@interface FolderListViewController ()
@end

@implementation FolderListViewController

- (id)initWithFolder:(DBFolder *)folder
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        // Custom initialization
        _folder = folder;
        basicInfoIDs = [NSMutableArray arrayWithArray:[CoreDataDatabase getBasicInfosInFolder:folder]];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.title = _folder.name;
    
    dispatch_async(loadBasicInfoQueue, ^{
        NSManagedObjectContext *moc = [CoreDataDatabase getContextForCurrentThread];
//        [basicInfos sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
//            NSManagedObjectID *objectID1 = (NSManagedObjectID *)obj1;
//            NSManagedObjectID *objectID2 = (NSManagedObjectID *)obj2;
//            
//            DBItemBasicInfo *basicInfo1 = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:objectID1 inContext:moc];
//            DBItemBasicInfo *basicInfo2 = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:objectID2 inContext:moc];
//            
//            LoadedBasicInfoData *info1 = [loadedBasicInfoMap valueForKey:[objectID1.URIRepresentation path]];
//            if(info1 == nil) {
//                info1 = [LoadedBasicInfoData new];
//                [loadedBasicInfoMap setValue:info1 forKey:[objectID1.URIRepresentation path]];
//                
//                info1.expiredCount = [CoreDataDatabase totalExpiredItemsOfBasicInfo:basicInfo1 inFolder:_folder];
//                info1.nearExpiredCount = [CoreDataDatabase totalNearExpiredOfBasicInfo:basicInfo1 inFolder:_folder];
//            }
//            
//            LoadedBasicInfoData *info2 = [loadedBasicInfoMap valueForKey:[objectID2.URIRepresentation path]];
//            if(info1 == nil) {
//                info2 = [LoadedBasicInfoData new];
//                [loadedBasicInfoMap setValue:info2 forKey:[objectID2.URIRepresentation path]];
//                
//                info2.expiredCount = [CoreDataDatabase totalExpiredItemsOfBasicInfo:basicInfo2 inFolder:_folder];
//                info2.nearExpiredCount = [CoreDataDatabase totalNearExpiredOfBasicInfo:basicInfo2 inFolder:_folder];
//            }
//            
//            if(info1.expiredCount > info2.expiredCount) {
//                return NSOrderedAscending;
//            } else if(info2.expiredCount > info1.expiredCount) {
//                return NSOrderedDescending;
//            } else {
//                if(info1.nearExpiredCount > info2.nearExpiredCount) {
//                    return NSOrderedAscending;
//                } else if(info2.nearExpiredCount > info1.nearExpiredCount) {
//                    return NSOrderedDescending;
//                }
//            }
//            
//            return NSOrderedSame;
//        }];
        
        int nIndex = 0;
        for(NSManagedObjectID *basicInfoID in basicInfoIDs) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:nIndex inSection:0];
            nIndex++;
            
            DBItemBasicInfo *basicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:basicInfoID inContext:moc];
            LoadedBasicInfoData *info = [self updateBasicInfo:basicInfo fullyUpdated:NO];
            info.stock = -1;    //For showing @"--" in stock
            
            dispatch_async(dispatch_get_main_queue(), ^{
                BasicInfoCell *cell = (BasicInfoCell *)[self.table cellForRowAtIndexPath:indexPath];
                [cell updateFromLoadedBasicInfo:info animated:NO];
            });
        }
        
        nIndex = 0;
        for(NSManagedObjectID *basicInfoID in basicInfoIDs) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:nIndex inSection:0];
            nIndex++;
            
            DBItemBasicInfo *basicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:basicInfoID inContext:moc];
            LoadedBasicInfoData *info = [self updateBasicInfo:basicInfo fullyUpdated:YES];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                BasicInfoCell *cell = (BasicInfoCell *)[self.table cellForRowAtIndexPath:indexPath];
                [cell updateFromLoadedBasicInfo:info animated:YES];
            });
        }
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    indexPathOfEditBasicInfo = indexPath;
    
    NSManagedObjectID *objectID = [basicInfoIDs objectAtIndex:indexPath.row];
    DBItemBasicInfo *basicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:objectID];
    LoadedBasicInfoData *preloadData = [loadedBasicInfoMap valueForKey:[[objectID URIRepresentation] path]];
    
    ListItemInFolderViewController *folderItemListVC = [[ListItemInFolderViewController alloc] initWithBasicInfo:basicInfo
                                                                                                          folder:_folder
                                                                                                     preloadData:preloadData];
    folderItemListVC.delegate = self;
    UITableViewCell *cell = [self.table cellForRowAtIndexPath:indexPath];
    CGRect cellFrame = [cell convertRect:cell.bounds toView:[self.table superview]];
    [folderItemListVC setInitBackgroundImage:tableImage cellPosition:cellFrame.origin];
    
    [self.navigationController pushViewController:folderItemListVC animated:NO];
}

- (LoadedBasicInfoData *)updateBasicInfo:(DBItemBasicInfo *)basicInfo fullyUpdated:(BOOL)isFull
{
    LoadedBasicInfoData *info = [super updateBasicInfo:basicInfo fullyUpdated:isFull];
    if(isFull) {
        info.stock = [CoreDataDatabase stockOfBasicInfo:basicInfo inFolder:_folder];
        info.expiredCount = [CoreDataDatabase totalExpiredItemsOfBasicInfo:basicInfo inFolder:_folder];
        info.nearExpiredCount = [CoreDataDatabase totalNearExpiredOfBasicInfo:basicInfo inFolder:_folder];
    }
    
    return info;
}

- (BOOL)shouldHandleFolderItem:(DBFolderItem *)folderItem
{
    if([folderItem.folder.objectID.URIRepresentation isEqual:_folder.objectID.URIRepresentation]) {
        return YES;
    }
    
    return NO;
}

@end
