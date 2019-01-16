//
//  OutlineLabel.m
//  ShopFolder
//
//  Created by Michael on 2011/12/27.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "OutlineLabel.h"

@implementation OutlineLabel
@synthesize outlineColor;
@synthesize outlineWidth;


- (void)_init
{
    self.outlineColor = [UIColor colorWithWhite:0 alpha:0.5];
    self.outlineWidth = 1.0;
}

- (id)initWithFrame:(CGRect)frame
{
    if((self = [super initWithFrame:frame])) {
        [self _init];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if((self = [super initWithCoder:aDecoder])) {
        [self _init];
    }
    
    return self;
}

- (id)init
{
    if((self = [super init])) {
        [self _init];
    }
    
    return self;
}

- (void)drawTextInRect:(CGRect)rect
{
    if(self.outlineWidth <= 0.0f) {
        return [super drawTextInRect:rect];
    }

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);

    //Prepare to draw outline
    CGContextSetLineWidth(context, self.outlineWidth);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    
    //Draw outline first
    UIColor *originTextColor = self.textColor;
    CGContextSetTextDrawingMode(context, kCGTextStroke);
    self.textColor = self.outlineColor;
    [super drawTextInRect:rect];
    self.textColor = originTextColor;
    
    //Then draw original text on the outlined text
    CGContextSetTextDrawingMode(context, kCGTextFill);
    CGSize originShadowOffset = self.shadowOffset;
    self.shadowOffset = CGSizeMake(0, 0);
    [super drawTextInRect:rect];
    self.shadowOffset = originShadowOffset;
    
    //Draw blur shadow
    CGSize shadowOffset = CGSizeMake(0, 2);
    float colorValues[] = {0, 0, 0, 0.8};   //R G B A
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGColorRef color = CGColorCreate(colorSpace, colorValues);
    CGContextSetShadowWithColor(context, shadowOffset, 2, color);
    [super drawTextInRect:rect];

    CGColorRelease(color);
    CGColorSpaceRelease(colorSpace); 
    
    CGContextRestoreGState(context);

}
@end
