//
//  ShopFolderAppDelegate.h
//  ShopFolder
//
//  Created by Michael on 2011/09/07.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ShopFolderViewController.h"

@interface ShopFolderAppDelegate : NSObject <UIApplicationDelegate> {
    ShopFolderViewController *_mainScreenVC;
    UINavigationController *_navCtrl;
}

@property (nonatomic, strong) IBOutlet UIWindow *window;
@end
