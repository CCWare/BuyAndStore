//
//  ListSearchResultsViewController.m
//  ShopFolder
//
//  Created by Michael on 2012/11/19.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "ListSearchResultsViewController.h"
#import "CoreDataDatabase.h"
#import "UIImage+Resize.h"
#import "UIImage+RoundedCorner.h"
#import "DBItemBasicInfo+SetAdnGet.h"
#import "PreferenceConstant.h"
#import "SearchResultCell.h"
#import "UIView+navigationTitleViewWithImage.h"

@interface ListSearchResultsViewController ()
@end

@implementation ListSearchResultsViewController

- (void)_initFromBasicInfo:(DBItemBasicInfo *)basicInfo
{
    [self refreshItemList];
}

- (id)initToSearchBarcode:(Barcode *)barcode WithBasicInfo:(DBItemBasicInfo *)basicInfo preloadData:(LoadedBasicInfoData *)preloadData;
{
    if((self = [super initWithBasicInfo:basicInfo preloadData:preloadData])) {
        _searchBarcode = barcode;
        [self refreshItemList];
    }
    
    return self;
}

- (id)initToSearchName:(NSString *)name WithBasicInfo:(DBItemBasicInfo *)basicInfo preloadData:(LoadedBasicInfoData *)preloadData;
{
    if((self = [super initWithBasicInfo:basicInfo preloadData:preloadData])) {
        _searchToken = name;
        [self refreshItemList];
    }
    
    return self;
}

- (id)initWithBasicInfo:(DBItemBasicInfo *)basicInfo preloadData:(LoadedBasicInfoData *)preloadData
{
    if((self = [super initWithBasicInfo:basicInfo preloadData:preloadData])) {
        [self _initFromBasicInfo:basicInfo];
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
    if(_searchBarcode) {
        self.navigationItem.titleView = [UIView navigationTitleViewWithImage:[UIImage imageNamed:@"search_barcode"]
                                                                  titleLabel:_searchBarcode.barcodeData
                                                                    maxWidth:240.0f];
    }
//    else {
//        self.navigationItem.titleView = [UIView navigationTitleViewWithImage:[UIImage imageNamed:@"search_text"]
//                                                                  titleLabel:_searchToken
//                                                                    maxWidth:240.0f];
//    }
    
    
    [self doSortAndLoadTable];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateBasicInfoStatistics
{
    [super updateBasicInfoStatistics];
    _basicInfoData.stock = [CoreDataDatabase stockOfBasicInfo:_basicInfo];
    _basicInfoData.nextExpiryDate = [CoreDataDatabase getNextExpiryDateOfBasicInfo:_basicInfo];
    _basicInfoData.expiredCount = [CoreDataDatabase totalExpiredItemsOfBasicInfo:_basicInfo];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellTableIdentitifier = @"SearchItemCellIdentifier";
    SearchResultCell *cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
    if(cell == nil) {
        cell = [[SearchResultCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellTableIdentitifier];
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
        cell.delegate = self;
    }
    
    cell.folderItem = [_showList objectAtIndex:indexPath.row];
    cell.isChecked = ([_selectedItemMap objectForKey:cell.folderItem.objectID] != nil);
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kSearchItemCellHeight;
}

//==============================================================
//  [BEGIN] Notification receivers
#pragma mark -
#pragma mark Notification receivers
//--------------------------------------------------------------

@end
