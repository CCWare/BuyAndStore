//
//  FavoriteListViewController.m
//  ShopFolder
//
//  Created by Michael on 2012/12/03.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "FavoriteListViewController.h"
#import "CoreDataDatabase.h"
#import "UIView+navigationTitleViewWithImage.h"

@interface FavoriteListViewController ()
- (void)_dismissButtonPressed:(id)sender;
@end

@implementation FavoriteListViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        basicInfoIDs = [NSMutableArray arrayWithArray:[CoreDataDatabase getFavoriteList]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.navigationItem.titleView = [UIView navigationTitleViewWithImage:[UIImage imageNamed:@"favorite"]
                                                              titleLabel:NSLocalizedString(@"Favorite", nil)
                                                                maxWidth:240.0f];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", nil)
                                                                             style:UIBarButtonItemStyleBordered
                                                                                          target:self
                                                                                          action:@selector(_dismissButtonPressed:)];
    self.navigationItem.rightBarButtonItem = nil;
    
    dispatch_async(loadBasicInfoQueue, ^{
        NSManagedObjectContext *moc = [CoreDataDatabase getContextForCurrentThread];
        
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

- (void)_dismissButtonPressed:(id)sender
{
    [self.delegate shouldDismissFavoriteList];
}

- (void)setCell:(BasicInfoCell *)cell withIndexPath:(NSIndexPath *)indexPath
{
    cell.accessoryType = UITableViewCellAccessoryNone;
//    cell.hideEditButton = YES;
    [super setCell:cell withIndexPath:indexPath];
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObjectID *objectID = [basicInfoIDs objectAtIndex:indexPath.row];
    DBItemBasicInfo *basicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:objectID];
    [self.delegate didSelectItemBasicInfo:basicInfo];
}

- (LoadedBasicInfoData *)updateBasicInfo:(DBItemBasicInfo *)basicInfo fullyUpdated:(BOOL)isFull
{
    LoadedBasicInfoData *info = [super updateBasicInfo:basicInfo fullyUpdated:isFull];
    if(isFull) {
        info.stock = [CoreDataDatabase stockOfBasicInfo:basicInfo];
        info.expiredCount = [CoreDataDatabase totalExpiredItemsOfBasicInfo:basicInfo];
        info.nearExpiredCount = [CoreDataDatabase totalNearExpiredOfBasicInfo:basicInfo];
    }
    
    return info;
}

- (BOOL)shouldHandleFolderItem:(DBFolderItem *)folderItem
{
    return NO;
}

- (void)finishEditBasicInfo:(id)sender changedBasicIndo:(DBItemBasicInfo *)basicInfo
{
    int nIndex = [basicInfoIDs indexOfObject:basicInfo.objectID];
    if(nIndex != NSNotFound) {
        [self updateBasicInfo:basicInfo fullyUpdated:YES];
        [self.table beginUpdates];
        [self.table reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:nIndex inSection:0]]
                          withRowAnimation:UITableViewRowAnimationNone];
        [self.table endUpdates];
    } else {
        //Change to another basicInfo which is not in the list, add the basicInfo to favorite list
        [self.table beginUpdates];
        basicInfo.isFavorite = YES;
        [CoreDataDatabase commitChanges:nil];
        [self updateBasicInfo:basicInfo fullyUpdated:YES];
        [basicInfoIDs insertObject:basicInfo.objectID atIndex:0];
        [self.table insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationNone];
        [self.table endUpdates];
    }
    
    indexPathOfEditBasicInfo = nil;
    [self dismissViewControllerAnimated:YES completion:NULL];
}
@end
