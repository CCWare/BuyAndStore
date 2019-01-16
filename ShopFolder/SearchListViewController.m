//
//  SearchListViewController.m
//  ShopFolder
//
//  Created by Michael on 2012/11/21.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "SearchListViewController.h"
#import "CoreDataDatabase.h"
#import "ListSearchResultsViewController.h"
#import "LoadedBasicInfoData.h"
#import "DBItemBasicInfo+SetAdnGet.h"
#import "UIImage+Resize.h"
#import "UIImage+RoundedCorner.h"
#import "ListSearchResultsViewController.h"
#import "UIView+navigationTitleViewWithImage.h"

@interface SearchListViewController ()
- (void)_showNoResult;
@end

@implementation SearchListViewController

- (id)initToSearchName:(NSString *)name
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        // Custom initialization
        _searchName = name;
        basicInfoIDs = [NSMutableArray arrayWithArray:[CoreDataDatabase getItemBasicInfosContainsName:name]];
    }
    
    return self;
}

- (id)initToSearchBarcode:(Barcode *)barcode
{
    if((self = [super initWithNibName:nil bundle:nil])) {
        _searchBarcode = barcode;
        
        /*
         Since barcode and basicInfo is 1-to-1 mapping, so we directly shows basicInfo and its folderItems from main screen.
         For the reason above, the basicInfo here will be nil.
         And we just show "No result" message here
         */
        DBItemBasicInfo *basicInfo = [CoreDataDatabase getItemBasicInfoByBarcode:barcode];
        if(basicInfo) {
            basicInfoIDs = [NSMutableArray arrayWithObject:basicInfo];
        }
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    if(_searchName) {
        self.title = [NSString stringWithFormat:NSLocalizedString(@"Search: %@", nil), _searchName];
        self.navigationItem.titleView = [UIView navigationTitleViewWithImage:[UIImage imageNamed:@"search_text"]
                                                                  titleLabel:_searchName
                                                                    maxWidth:240.0f];
        
        dispatch_async(loadBasicInfoQueue, ^{
            NSManagedObjectContext *moc = [CoreDataDatabase getContextForCurrentThread];
            
//            int nIndex = 0;
//            for(NSManagedObjectID *basicInfoID in basicInfos) {
//                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:nIndex inSection:0];
//                nIndex++;
//                
//                DBItemBasicInfo *basicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:basicInfoID inContext:moc];
//                LoadedBasicInfoData *info = [self updateBasicInfo:basicInfo];
//                
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    BasicInfoCell *cell = (BasicInfoCell *)[self.table cellForRowAtIndexPath:indexPath];
//                    [cell updateFromLoadedBasicInfo:info];
//                });
//            }
            
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
    } else {
//        self.title = [NSString stringWithFormat:NSLocalizedString(@"Search: %@", nil), _searchBarcode.barcodeData];
        self.navigationItem.titleView = [UIView navigationTitleViewWithImage:[UIImage imageNamed:@"search_barcode"]
                                                                  titleLabel:_searchBarcode.barcodeData
                                                                    maxWidth:240.0f];
    }
    
    if([basicInfoIDs count] == 0) {
        [self _showNoResult];
        return;
    }
}

- (void)_showNoResult
{
    self.table.hidden = YES;
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 320, 44)];
    label.textAlignment = UITextAlignmentCenter;
    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    label.text = NSLocalizedString(@"No result", nil);
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont systemFontOfSize:24];
    [self.view addSubview:label];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, 280, 120)];
    label.textAlignment = UITextAlignmentLeft;
    label.text = NSLocalizedString(@"Notice: the items in locked folders won't be listed.", nil);
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor darkGrayColor];
    label.font = [UIFont systemFontOfSize:22];
    label.numberOfLines = 3;
    [self.view addSubview:label];
    
    self.navigationItem.rightBarButtonItem = nil;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    indexPathOfEditBasicInfo = indexPath;
    
    NSManagedObjectID *objectID = [basicInfoIDs objectAtIndex:indexPath.row];
    DBItemBasicInfo *basicInfo = (DBItemBasicInfo *)[CoreDataDatabase getObjectByID:objectID];
    LoadedBasicInfoData *preloadData = [loadedBasicInfoMap valueForKey:[[objectID URIRepresentation] path]];
    
    ListSearchResultsViewController *searchItemListVC = [[ListSearchResultsViewController alloc] initWithBasicInfo:basicInfo
                                                                                                       preloadData:preloadData];
    searchItemListVC.delegate = self;
    UITableViewCell *cell = [self.table cellForRowAtIndexPath:indexPath];
    CGRect cellFrame = [cell convertRect:cell.bounds toView:[self.table superview]];
    [searchItemListVC setInitBackgroundImage:tableImage cellPosition:cellFrame.origin];
    
    [self.navigationController pushViewController:searchItemListVC animated:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    if([_searchName length] > 0) {
        if([folderItem.basicInfo.name rangeOfString:_searchName options:NSCaseInsensitiveSearch].length > 0) {
            return YES;
        }
    }
    
    return NO;
}

@end
