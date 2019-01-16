//
//  SearchListViewController.h
//  ShopFolder
//
//  Created by Michael on 2012/11/21.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "BasicInfoListViewController.h"
#import "Barcode.h"

@interface SearchListViewController : BasicInfoListViewController
{
    NSString *_searchName;
    Barcode *_searchBarcode;
}

- (id)initToSearchName:(NSString *)name;
- (id)initToSearchBarcode:(Barcode *)barcode;
@end
