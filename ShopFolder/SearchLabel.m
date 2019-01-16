//
//  SearchLabel.m
//  ShopFolder
//
//  Created by Michael on 2011/11/16.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "SearchLabel.h"
#import <QuartzCore/QuartzCore.h>

#define kBorderWidth 2

@implementation SearchLabel
@synthesize searchText;


- (id)initWithCoder:(NSCoder *)aDecoder
{
    if((self = [super initWithCoder:aDecoder])) {
        self.text = NSLocalizedString(@"Drag to here & stay to search", nil);
    }
    
    return self;
}

- (void)setHighlighted:(BOOL)highlighted
{
    if(self.highlighted == highlighted) {
        return;
    }

    [super setHighlighted:highlighted];
    
    if(highlighted) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    } else {
        self.backgroundColor = [UIColor clearColor];
    }
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    if(kBorderWidth <= 0) {
        return;
    }

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, kBorderWidth);
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:0.8 alpha:1].CGColor);

    if(!self.highlighted) {
        CGFloat dashArray[] = {10, 5};
        CGContextSetLineDash(context, 5, dashArray, 2);
    }

    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 0, kBorderWidth-1);
    CGContextAddLineToPoint(context, self.frame.size.width-kBorderWidth+1, kBorderWidth-1);
    CGContextAddLineToPoint(context, self.frame.size.width-kBorderWidth+1, self.frame.size.height-kBorderWidth+1);
    CGContextAddLineToPoint(context, kBorderWidth-1, self.frame.size.height-kBorderWidth+1);
    CGContextAddLineToPoint(context, kBorderWidth-1, kBorderWidth-1);

    CGContextStrokePath(context);
}
@end
