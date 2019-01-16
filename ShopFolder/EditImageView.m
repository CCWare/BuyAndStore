//
//  EditImageView.m
//  ShopFolder
//
//  Created by Michael on 2011/10/26.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>   //For using CALayer
#import "EditImageView.h"
#import "UIImage+RoundedCorner.h"
#import "UIImage+Resize.h"

#define kBorderAlpha 125

@interface EditImageView ()

@end

@implementation EditImageView
@synthesize editing;
@synthesize editView=_editView;

-(id)initWithFrame:(CGRect)frame
{
    if((self = [super initWithFrame:frame])) { //initWithFrame will call setFrame:
        self.userInteractionEnabled = YES;
        _whiteImage = [UIImage imageNamed:@"empty_image"];//[[UIImage imageNamed:@"empty_image"] roundedCornerImage:20 borderSize:2];
        self.image = nil;
        self.contentMode = UIViewContentModeScaleAspectFill;
        
        CGRect borderFrame = self.frame;
        borderFrame.origin.x = 0;
        borderFrame.origin.y = 0;
        
        UIImageView *borderView = [[UIImageView alloc] initWithFrame:borderFrame];
        borderView.image = [UIImage imageNamed:@"image_border"];
        [self addSubview:borderView];

        //Init edit label at buttom
        _editView = [[UIControl alloc] initWithFrame:borderFrame];
        _editBorderView = [[UIImageView alloc] initWithFrame:borderFrame];
        _editBorderView.alpha = 0.5f;
        [_editView addSubview:_editBorderView];
        
        UIFont *imageLabelFont = [UIFont boldSystemFontOfSize:14];
        CGFloat fLabelHeight = imageLabelFont.lineHeight;
        _editImageLabel = [[UILabel alloc] initWithFrame:CGRectMake(kEditImageViewBorderWidth,
                                                                    frame.size.height-fLabelHeight,
                                                                    frame.size.width-(kEditImageViewBorderWidth)*2,
                                                                    fLabelHeight)];
        _editImageLabel.font = imageLabelFont;
        _editImageLabel.backgroundColor = [UIColor clearColor];
        _editImageLabel.text = NSLocalizedString(@"Edit", nil);
        _editImageLabel.textAlignment = UITextAlignmentCenter;
        _editImageLabel.contentMode = UIViewContentModeCenter;
        _editImageLabel.textColor = [UIColor whiteColor];
        _editImageLabel.userInteractionEnabled = NO;
        
        _editEmptyImageLabel = [[UILabel alloc] initWithFrame:borderFrame];
        _editEmptyImageLabel.font = imageLabelFont;
        _editEmptyImageLabel.numberOfLines = 2;
        _editEmptyImageLabel.backgroundColor = [UIColor clearColor];
        _editEmptyImageLabel.text = NSLocalizedString(@"Add\nImage", nil);
        _editEmptyImageLabel.textAlignment = UITextAlignmentCenter;
        _editEmptyImageLabel.contentMode = UIViewContentModeCenter;
        _editEmptyImageLabel.textColor = [UIColor darkGrayColor];
        _editEmptyImageLabel.userInteractionEnabled = NO;
    }
    
    return self;
}

- (void)setImage:(UIImage *)image isPreProcessed:(BOOL)preProcessed
{
    if(preProcessed) {
        _image = image;
        
        if(image == nil) {
            [super setImage:_whiteImage];
        } else {
            [super setImage:image];
        }
        
        if(editing) {
            [_editImageLabel removeFromSuperview];
            [_editEmptyImageLabel removeFromSuperview];
            
            if(self.image == nil) {
                _editBorderView.image = [UIImage imageNamed:@"image_border_editing_empty"];
                [self.editView addSubview:_editEmptyImageLabel];
            } else {
                _editBorderView.image = [UIImage imageNamed:@"image_border_editing"];
                [self.editView addSubview:_editImageLabel];
            }
        }
    } else {
        self.image = image;
    }
}

- (void)setImage:(UIImage *)inImage
{
    _image = inImage;
    
    if(inImage == nil) {
        [super setImage:_whiteImage];
    } else {
        UIImage *resizedImage = [inImage resizedImage:CGSizeMake(kImageWidth<<1, kImageHeight<<1)
                                 interpolationQuality:kCGInterpolationHigh];
        [super setImage:[resizedImage roundedCornerImage:18 borderSize:1]];
    }
    
    if(editing) {
        [_editImageLabel removeFromSuperview];
        [_editEmptyImageLabel removeFromSuperview];
        
        if(self.image == nil) {
            _editBorderView.image = [UIImage imageNamed:@"image_border_editing_empty"];
            [self.editView addSubview:_editEmptyImageLabel];
        } else {
            _editBorderView.image = [UIImage imageNamed:@"image_border_editing"];
            [self.editView addSubview:_editImageLabel];
        }
    }
}

- (UIImage *)image
{
    return _image;
}

- (void)setEditing:(BOOL)toEdit
{
    [self setEditing:toEdit animated:NO duration:0];
}

- (void)setEditing:(BOOL)toEdit animated:(BOOL)animated duration:(CGFloat)timeInSecond
{
    editing = toEdit;
    if(editing) {
        [_editImageLabel removeFromSuperview];
        [_editEmptyImageLabel removeFromSuperview];
        
        if(self.image == nil) {
            _editBorderView.image = [UIImage imageNamed:@"image_border_editing_empty"];
            [self.editView addSubview:_editEmptyImageLabel];
        } else {
            _editBorderView.image = [UIImage imageNamed:@"image_border_editing"];
            [self.editView addSubview:_editImageLabel];
        }
        
        if(animated) {
            self.editView.alpha = 0;
            [self addSubview:self.editView];
            [UIView animateWithDuration:timeInSecond animations:^{
                self.editView.alpha = 1.0;
            }];
        } else {
            [self addSubview:self.editView];
        }
    } else {
        if(animated) {
            self.editView.alpha = 1.0;
            [UIView animateWithDuration:timeInSecond animations:^{
                self.editView.alpha = 0;
            } completion:^(BOOL finished) {
                if(finished) {
                    [self.editView removeFromSuperview];
                }
            }];
        } else {
            [self.editView removeFromSuperview];
        }
    }
}

- (BOOL)hasImage
{
    return (self.image != nil);
}

@end
