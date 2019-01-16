//
//  DeleteBadgeView.m
//  ShopFolder
//
//  Created by Michael on 2011/12/02.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "DeleteBadgeView.h"
#import "UIImage+Tint.h"

@interface DeleteBadgeView ()
@property (nonatomic, strong) NSDate *_lastHighlightTime;
@end

@implementation DeleteBadgeView
@synthesize _lastHighlightTime;


- (void)_init
{
    deleteImage = [UIImage imageNamed:@"delete"];
    self.image = deleteImage;
}

- (id)initWithFrame:(CGRect)frame
{
    if((self = [super initWithFrame:frame])) {
        [self _init];
    }
    
    return self;
}

- (void)setHidden:(BOOL)hidden animated:(BOOL)animate
{
    if(!hidden) {
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1;
        [super setHidden:hidden];
    } else {
        void(^hideViewBlock)() = ^{
            self.transform = CGAffineTransformIdentity;
            [super setHidden:hidden];
        };
        
        if(animate) {
            [UIView animateWithDuration:0.25
                                  delay:0
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^(void) {
                                 self.alpha = 0;
//                                 self.transform = CGAffineTransformMakeScale(0.001, 0.001);
                             }
                             completion:^(BOOL finished) {
                                 hideViewBlock();
                             }];
        } else {
            hideViewBlock();
        }
    }
}

- (void)setHidden:(BOOL)hidden
{
    [self setHidden:hidden animated:NO];
}

- (void)_deHighlight
{
    self.image = deleteImage;
    self._lastHighlightTime = nil;
}

#define kMinimumHighlightTime 0.1
- (void)setHighlighted:(BOOL)highlighted
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_dehighlightDeleteBadge) object:nil];
    if(highlighted) {
        if(!highlightedDeleteImage) {
            highlightedDeleteImage = [deleteImage tintedImageUsingColor:[UIColor colorWithWhite:0 alpha:0.5]];
        }
        self.image = highlightedDeleteImage;
        
        self._lastHighlightTime = [NSDate date];
    } else {
        NSTimeInterval highlightTime = -[self._lastHighlightTime timeIntervalSinceNow];
        if(highlightTime < kMinimumHighlightTime) {
            [self performSelector:@selector(_deHighlight) withObject:nil afterDelay:kMinimumHighlightTime-highlightTime];
        } else {
            [self performSelectorOnMainThread:@selector(_deHighlight) withObject:nil waitUntilDone:YES];
        }
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
@end
