//
//  FolderImageView.m
//  ShopFolder
//
//  Created by Michael on 2011/09/23.
//  Copyright 2011年 CCTSAI. All rights reserved.
//

#import "FolderImageView.h"
#import <QuartzCore/QuartzCore.h>
#import "UIImage+Resize.h"
#import "UIScreen+RetinaDetection.h"

//#define kAnimationDuration  0.25
#define kBorderWidth        4   //  Must < kCornerRadius
//static const int kContentBorderWidth = (kBorderWidth > 1) ? kBorderWidth - 1 : 0;

@interface FolderImageView (PrivateMethods)
- (void)_initLayout;

- (UIImage *)_preprocessImage:(UIImage *)image;
@end

@implementation FolderImageView
@synthesize isEmpty;
@synthesize showShadow=_showShadow;

- (void)_initLayout
{
    self.isEmpty = NO;
    
    [super setImage:[UIImage imageNamed:@"folder_border"]];

    _contentView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
    folder_wo_image = [UIImage imageNamed:@"folder_wo_image"];
    _contentView.image = folder_wo_image;
    [self addSubview:_contentView];
    
    _exchangeImageView = [[UIImageView alloc] initWithFrame:_contentView.frame];
    _exchangeImageView.hidden = YES;
    [self addSubview:_exchangeImageView];
    
    _highlightView = [[UIImageView alloc] initWithFrame:_contentView.frame];
    _highlightView.image = [UIImage imageNamed:@"folder_highlight"];
    _highlightView.hidden = YES;
    [self addSubview:_highlightView];
    
    UIImage *backgroundImage = [UIImage imageNamed:@"folder_background"];
    UIImageView *background = [[UIImageView alloc] initWithImage:backgroundImage];
    background.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height * backgroundImage.size.height/self.image.size.height);
    [self insertSubview:background atIndex:0];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if((self = [super initWithCoder:aDecoder])) {
        [self _initLayout];
    }
    
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    if((self = [super initWithFrame:frame])) {
        [self _initLayout];
    }
    
    return self;
}

- (UIImage *)_preprocessImage:(UIImage *)image
{
    UIImage *newImage = folder_wo_image;
    if(image) {
        NSInteger borderWidth = (kBorderWidth<<1) + 1;    //"1": adjust for smooth edge of the border image
        NSInteger thumbSize = kFolderViewSize<<1;
        NSInteger cornerRadius = kFolderViewSize;
        
        newImage = [image thumbnailImage:thumbSize
                       transparentBorder:borderWidth
                            cornerRadius:cornerRadius
                    interpolationQuality:kCGInterpolationHigh];
        
    }
    
    return newImage;
}

- (void)setImage:(UIImage *)image
{
    UIImage *newImage = [self _preprocessImage:image];
    void(^setImageBlock)() = ^(){
        _contentView.image = newImage;    
        [self setNeedsDisplay];
    };

    if([NSThread currentThread] == [NSThread mainThread]) {
        setImageBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), setImageBlock);
    }
}

- (void)_deHighlight
{
    @synchronized(self) {
        _highlightView.hidden = YES;
        _lastHighlightTime = nil;
    }
}

#define kMinimumHighlightTime 0.1
- (void)setHighlighted:(BOOL)highlighted
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_deHighlight) object:nil];

    void(^setHighlightBlock)() = ^{
        _highlightView.hidden = NO;
        [self setNeedsDisplay];
        
        _lastHighlightTime = [NSDate date];
    };
    
    if([NSThread currentThread] == [NSThread mainThread]) {
        setHighlightBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), setHighlightBlock);
    }

    if(!highlighted) {
        NSTimeInterval highlightTime = -[_lastHighlightTime timeIntervalSinceNow];
        if(highlightTime < kMinimumHighlightTime) {
            [self performSelector:@selector(_deHighlight) withObject:nil afterDelay:kMinimumHighlightTime-highlightTime];
        } else {
            [self performSelectorOnMainThread:@selector(_deHighlight) withObject:nil waitUntilDone:YES];
        }
    }

    [super setHighlighted:highlighted];
}

- (void)setIsEmpty:(BOOL)empty
{
    isEmpty = empty;
    
    void(^setAlphaBlock)() = ^(){
        if(empty) {
            _contentView.alpha = 0.25;
        } else {
            _contentView.alpha = 1;
        }
        [self setNeedsDisplay];
    };
    
    if([NSThread currentThread] == [NSThread mainThread]) {
        setAlphaBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), setAlphaBlock);
    }
}

- (void)setShowShadow:(BOOL)show
{
    _showShadow = show;
    
    if(show) {
        if(!_shadowImageView) {
            UIImage *shadowImage = [UIImage imageNamed:@"folder_shadow"];
            CGFloat fShadowWidth = (shadowImage.size.width - self.image.size.width)/2;  //2 for half

            _shadowImageView = [[UIImageView alloc] initWithFrame:CGRectMake(-fShadowWidth, -fShadowWidth,
                                                                             self.frame.size.width+2*fShadowWidth,
                                                                             self.frame.size.height+2*fShadowWidth)];
            _shadowImageView.image = shadowImage;
        }
        
        _shadowImageView.alpha = 1.0f;
        [self addSubview:_shadowImageView];
    } else {
        [UIView animateWithDuration:0
                         animations:^{
                             _shadowImageView.alpha = 0.0f;
                         }];
        
        [_shadowImageView removeFromSuperview];
    }
}

- (void)showShadowAnimated:(BOOL)animate
{
    self.showShadow = YES;
    if(animate) {
        _shadowImageView.alpha = 0.25f;
        [UIView animateWithDuration:1.0f
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionRepeat|UIViewAnimationOptionAutoreverse
                         animations:^{
                             _shadowImageView.alpha = 1.0f;
                         } completion:NULL];
    }
}

- (void)hideShadowAnimated:(BOOL)animate
{
    if(animate) {
        [UIView animateWithDuration:0.25f
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             _shadowImageView.alpha = 0.0f;
                         } completion:^(BOOL finished) {
                             self.showShadow = NO;
                         }];
    } else {
        self.showShadow = NO;
    }
}

- (void)setAlpha:(CGFloat)alpha
{
    //I dont't want to affect border alpha
    void(^setAlphaBlock)() = ^(){
        _contentView.alpha = alpha;
        [self setNeedsDisplay];
    };
    
    if([NSThread currentThread] == [NSThread mainThread]) {
        setAlphaBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), setAlphaBlock);
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.highlighted = YES;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.highlighted = NO;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.highlighted = NO;
}

- (void)exchangeImage:(UIImage *)image animated:(BOOL)animate
{
    if(!animate) {
        self.image = image;
        return;
    }
    
    UIImage *newImage = [self _preprocessImage:image];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _exchangeImageView.image = _contentView.image;
        _exchangeImageView.alpha = 1.0f;
        _exchangeImageView.hidden = NO;
        
        _contentView.image = newImage;
        _contentView.alpha = 0.0f;
        
        [UIView animateWithDuration:0.5
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             _contentView.alpha = 1.0f;
                             _exchangeImageView.alpha = 0.0f;
                         } completion:^(BOOL finished) {
                             _exchangeImageView.hidden = YES;
                             _exchangeImageView.alpha = 1.0f;
                         }];
    });
}

@end
