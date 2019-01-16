//
//  FolderView.m
//  ShopFolder
//
//  Created by Michael on 2011/11/04.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "FolderView.h"
#import "ColorConstant.h"

#define RADIANS(degrees) ((degrees * M_PI) / 180.0)
#define kAnimationDuration  0.1
#define kDeleteBadgeSize    28.0
#define kOffsetY            11     //For touching delete badge

@implementation FolderView
@synthesize imageView;
@synthesize label;
@synthesize editing;
@synthesize focused;
@synthesize locked;
@dynamic expiredBadgeNumber;
@dynamic nearExpiredBadgeNumber;
@synthesize deleteBadge;


- (void)reset
{
    self.imageView.image = nil;
    self.imageView.isEmpty = YES;
    self.focused = NO;
    self.expiredBadgeNumber = 0;
    self.nearExpiredBadgeNumber = 0;
    self.label.text = nil;
    self.locked = NO;
    self.deleteBadge.hidden = YES;
    
    [self setNeedsDisplay];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if((self = [super initWithCoder:aDecoder])) {
        folderOffsetX = (self.frame.size.width - kFolderViewSize)/2;
        imageView = [[FolderImageView alloc] initWithFrame:CGRectMake(folderOffsetX, kOffsetY, kFolderViewSize, kFolderViewSize)];

        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.contentStretch = CGRectMake(0, 0, 0, 0);
        imageView.userInteractionEnabled = YES;

        UIFont *labelFont = [UIFont systemFontOfSize:17];
        label = [[OutlineLabel alloc] initWithFrame:CGRectMake(0, kFolderViewSize+2+kOffsetY,
                                                               self.frame.size.width, labelFont.lineHeight)];
        label.minimumFontSize = 12;
        label.adjustsFontSizeToFitWidth = YES;
        label.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = UITextAlignmentCenter;
        label.contentMode = UIViewContentModeCenter;
        label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
        label.lineBreakMode = UILineBreakModeMiddleTruncation;
        label.font = labelFont;
        label.userInteractionEnabled = YES;
        
        self.userInteractionEnabled = YES;
        [self addSubview:imageView];
        [self addSubview:label];
        [self sizeToFit];
        
        _setFocusTransform = CGAffineTransformScale(CGAffineTransformIdentity, 1.1, 1.1);
        
        expiredBadge = [[MKNumberBadgeView alloc] init];
        expiredBadge.userInteractionEnabled = NO;
        [self addSubview:expiredBadge];
        
        nearExpiredBadge = [[MKNumberBadgeView alloc] init];
        nearExpiredBadge.fillColor = kNearExpiredBadgeColor;
        nearExpiredBadge.userInteractionEnabled = NO;
        [self addSubview:nearExpiredBadge];
        
        badgeRightEnd = folderOffsetX + kFolderViewSize + nearExpiredBadge.arcRadius - 2;

        deleteBadge = [[DeleteBadgeView alloc] initWithFrame:CGRectMake(folderOffsetX-9, 0, kDeleteBadgeSize, kDeleteBadgeSize)];
        self.deleteBadge.hidden = YES;
        self.deleteBadge.userInteractionEnabled = YES;
        [self addSubview:deleteBadge];
    }
    
    return self;
}

- (void)_animateWithEditing:(BOOL)isEditing
{
    if(isEditing) {
        if(self.focused) {
            [UIView animateWithDuration:0.075
                                  delay:0
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^(void) {
                                 self.transform = _setFocusTransform;
                             }
                             completion:NULL];
        } else {
            CGAffineTransform moveUp = CGAffineTransformTranslate(CGAffineTransformIdentity, 0, 1);
            CGAffineTransform moveDown = CGAffineTransformTranslate(CGAffineTransformIdentity, 0, -1);
            CGAffineTransform moveTransformArray[] = {moveUp, moveDown};
            CGAffineTransform *moveTransforms = moveTransformArray;

            int index = arc4random()%2;
            UIViewAnimationOptions animOpt = UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionRepeat|UIViewAnimationOptionAutoreverse;
            if(index == 0) {
                animOpt |= UIViewAnimationCurveEaseIn;
            } else {
                animOpt |= UIViewAnimationCurveEaseOut;
            }

            self.transform = moveTransforms[index];
            [UIView animateWithDuration:0.25
                                  delay:0
                                options:animOpt
                             animations:^{
                                 self.transform = moveTransforms[1-index];
                             } completion:NULL];

        }
    } else {
        [UIView animateWithDuration:0
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             self.transform = CGAffineTransformIdentity;
                         } completion:NULL];
    }
}

- (void)setEditing:(BOOL)isEditing
{
    if(editing == isEditing) {
        return;
    }
    editing = isEditing;
    
    [self _animateWithEditing:editing];
}

- (void)setFocused:(BOOL)isFocused animated:(BOOL)animated
{
    if(focused == isFocused) {
        return;
    }

    self.imageView.highlighted = isFocused;
    focused = isFocused;

    NSTimeInterval animateDuration = (animated) ? kAnimationDuration : 0;
    if(isFocused) {
        self.transform = CGAffineTransformIdentity;
        [UIView animateWithDuration:animateDuration
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             self.transform = _setFocusTransform;
                         } completion:NULL];
    } else {
        [UIView animateWithDuration:animateDuration
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             self.transform = CGAffineTransformIdentity;
                         } completion:^(BOOL complete) {
                             if(complete) {
                                 [self _animateWithEditing:self.editing];
                             }
                         }];
    }
}

- (void)setFocused:(BOOL)isFocused
{
    [self setFocused:isFocused animated:NO];
}

-(NSInteger)expiredBadgeNumber
{
    return expiredBadge.value;
}

- (void)setExpiredBadgeNumber:(NSInteger)expiredBadgeNumber
{
    expiredBadge.value = expiredBadgeNumber;
    expiredBadge.frame = CGRectMake(badgeRightEnd - expiredBadge.badgeSize.width, -expiredBadge.badgeSize.height/2.0f + 2.0f + kOffsetY,
                                    expiredBadge.badgeSize.width, expiredBadge.badgeSize.height);
    
    if(nearExpiredBadge.value > 0) {
        [self setNearExpiredBadgeNumber:nearExpiredBadge.value];    //For updating frame
    }
}

- (NSInteger)nearExpiredBadgeNumber
{
    return nearExpiredBadge.value;
}

- (void)setNearExpiredBadgeNumber:(NSInteger)nearExpiredBadgeNumber
{
    nearExpiredBadge.value = nearExpiredBadgeNumber;
    
    if(expiredBadge.value == 0) {
        nearExpiredBadge.frame = CGRectMake(badgeRightEnd - nearExpiredBadge.badgeSize.width,
                                            -nearExpiredBadge.badgeSize.height/2 + 3 + kOffsetY,
                                            nearExpiredBadge.badgeSize.width, nearExpiredBadge.badgeSize.height);
    } else {
        nearExpiredBadge.frame = CGRectMake(badgeRightEnd - nearExpiredBadge.badgeSize.width,
                                            expiredBadge.frame.origin.y + expiredBadge.frame.size.height - 4,
                                            nearExpiredBadge.badgeSize.width, nearExpiredBadge.badgeSize.height);
    }
}

- (void)setLocked:(BOOL)isLocked
{
    if(locked == isLocked) {
        return;
    }

    locked = isLocked;
    
    if(locked) {
        lockImageView = [[UIImageView alloc] initWithFrame:CGRectMake(folderOffsetX-9, kFolderViewSize-22+kOffsetY, 24, 24)];
        lockImageView.image = [UIImage imageNamed:@"lock"];

        [self addSubview:lockImageView];
    } else {
        [lockImageView removeFromSuperview];
        lockImageView = nil;
    }
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
