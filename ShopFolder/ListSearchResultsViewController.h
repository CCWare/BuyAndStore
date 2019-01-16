//
//  ListSearchResultsViewController.h
//  ShopFolder
//
//  Created by Michael on 2012/11/19.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "FolderItemListViewController.h"
#import "Barcode.h"

@interface ListSearchResultsViewController : FolderItemListViewController
{
    Barcode *_searchBarcode;
    NSString *_searchToken;
}

- (id)initToSearchBarcode:(Barcode *)barcode WithBasicInfo:(DBItemBasicInfo *)basicInfo preloadData:(LoadedBasicInfoData *)preloadData;
- (id)initToSearchName:(NSString *)name WithBasicInfo:(DBItemBasicInfo *)basicInfo preloadData:(LoadedBasicInfoData *)preloadData;

@end
