//
//  Folder.h
//  ShopFolder
//
//  Created by Michael on 2011/09/23.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kDefaultColor ([UIColor whiteColor])

@interface Folder : NSObject {
    int ID;
    NSString *name;
    int page;
    int number;
    UIColor *color;
    NSString *imagePath;
    NSString *lockPhrease;

    UIImage *image;
}

@property (nonatomic, assign) int ID;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) int page;
@property (nonatomic, assign) int number;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, strong) NSString *imagePath;
@property (nonatomic, strong) NSString *lockPhrease;

@property (nonatomic, strong) UIImage *image;

- (void) copyFrom:(Folder *)source;
- (void) resetData;
- (BOOL) isUnused;
- (BOOL) isEmpty;
- (BOOL)canSave;
@end
