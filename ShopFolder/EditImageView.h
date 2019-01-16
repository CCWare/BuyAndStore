//
//  EditImageView.h
//  ShopFolder
//
//  Created by Michael on 2011/10/26.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ImageParameters.h"

#define kImageBorderWidth           1
#define kImageCornerRadius          5
#define kEditImageViewBorderWidth   1

@interface EditImageView : UIImageView
{
    BOOL editing;
    UIControl *_editView;
@private
    
    UIImageView *_editBorderView;
    UILabel *_editEmptyImageLabel;
    UILabel *_editImageLabel;
    
    UIImage *_whiteImage;
    UIImage *_image;
}

@property (nonatomic, assign) BOOL editing;
@property (nonatomic, strong, readonly) UIControl *editView;

- (BOOL)hasImage;
- (void)setEditing:(BOOL)editing animated:(BOOL)animated duration:(CGFloat)timeInSecond;

- (void)setImage:(UIImage *)image isPreProcessed:(BOOL)preProcessed;
@end
