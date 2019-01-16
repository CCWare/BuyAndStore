//
//  FolderTutorialViewController.h
//  ShopFolder
//
//  Created by Michael on 2011/12/09.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FolderTutorialViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) IBOutlet UITableView *table;

@end
