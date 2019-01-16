//
//  FolderImageView.h
//  ShopFolder
//
//  Created by Michael on 2011/09/23.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PreferenceConstant.h"

#define kFolderViewSize     84

@interface FolderImageView : UIImageView
{
    BOOL isEmpty;
    UIImage *folder_wo_image;
@private
    UIImageView *_highlightView;
    UIImageView *_contentView;
    NSDate *_lastHighlightTime;

    UIImageView *_shadowImageView;
    BOOL _showShadow;
    
    UIImageView *_exchangeImageView;
}

@property (nonatomic, assign) BOOL isEmpty;
@property (nonatomic, assign) BOOL showShadow;

- (void)showShadowAnimated:(BOOL)animate;
- (void)hideShadowAnimated:(BOOL)animate;

- (void)exchangeImage:(UIImage *)image animated:(BOOL)animate;

@end
