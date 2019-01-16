//
//  MKNumberBadgeView.m
//  MKNumberBadgeView
//
// Copyright 2009 Michael F. Kamprath
// michael@claireware.com
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "MKNumberBadgeView.h"

#define kShadowBlurOffset   CGSizeMake(0, 1)
#define kShadowBlurRadius   3

@interface MKNumberBadgeView ()

//
// private methods
//

- (void)initState;
- (CGPathRef)newBadgePathForTextSize:(CGSize)inSize;
- (void)_updateBadgeSize;
@end


@implementation MKNumberBadgeView
@synthesize value=_value;
@synthesize text=_text;
@synthesize shadow=_shadow;
@synthesize shine=_shine;
@synthesize font=_font;
@synthesize fillColor=_fillColor;
@synthesize strokeColor=_strokeColor;
@synthesize textColor=_textColor;
@synthesize alignment=_alignment;
@synthesize badgeSize=_badgeSize;
@synthesize pad=_pad;
@synthesize arcRadius;

- (id)initWithFrame:(CGRect)frame 
{
    if (self = [super initWithFrame:frame]) 
    {
        // Initialization code
        
        [self initState];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if (self = [super initWithCoder:decoder]) 
    {
        // Initialization code
        [self initState];
    }
    return self;
}


#pragma mark -- private methods --

- (void)initState;
{
    self.opaque = NO;
    _pad = 2;
    self.font = [UIFont boldSystemFontOfSize:16];   //arcRadius will be updated here
    self.shadow = YES;
    self.shine = YES;
    self.alignment = UITextAlignmentCenter;
    self.fillColor = [UIColor colorWithRed:0.85 green:0 blue:0 alpha:1];    //darker red
    self.strokeColor = [UIColor whiteColor];
    self.textColor = [UIColor whiteColor];
    
    self.backgroundColor = [UIColor clearColor];

    if(_value == 0 && [_text length] == 0) {
        self.hidden = YES;
    } else {
        self.hidden = NO;
        [self _updateBadgeSize];
    }
}



- (void)drawRect:(CGRect)rect 
{
    self.hidden = (_value == 0 && [_text length] == 0) ? YES : NO;

    CGRect viewBounds = self.bounds;
    NSString *badgeText = ([_text length] == 0) ? [NSString stringWithFormat:@"%d",self.value] : _text;
    CGSize badgeTextSize = [badgeText sizeWithFont:self.font];
    CGPathRef badgePath = [self newBadgePathForTextSize:badgeTextSize];
    CGRect badgeRect = CGPathGetBoundingBox(badgePath);
    badgeRect.origin.x = 0;
    badgeRect.origin.y = 0;
    badgeRect.size.width = ceil( badgeRect.size.width );
    badgeRect.size.height = ceil( badgeRect.size.height );

    CGContextRef curContext = UIGraphicsGetCurrentContext();
    CGContextSaveGState( curContext );
    CGContextSetLineWidth( curContext, 2.0 );
    CGContextSetStrokeColorWithColor(  curContext, self.strokeColor.CGColor  );
    CGContextSetFillColorWithColor( curContext, self.fillColor.CGColor );
        
    CGPoint ctm;
    
    switch (self.alignment) 
    {
        default:
        case UITextAlignmentCenter:
            ctm = CGPointMake( round((viewBounds.size.width - badgeRect.size.width)/2), round((viewBounds.size.height - badgeRect.size.height)/2) );
            break;
        case UITextAlignmentLeft:
            ctm = CGPointMake( 0, round((viewBounds.size.height - badgeRect.size.height)/2) );
            break;
        case UITextAlignmentRight:
            ctm = CGPointMake( (viewBounds.size.width - badgeRect.size.width), round((viewBounds.size.height - badgeRect.size.height)/2) );
            break;
    }
    
    CGContextTranslateCTM( curContext, ctm.x, ctm.y);

    if (self.shadow) {
        CGContextSaveGState( curContext );

        UIColor* blurColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        
        CGContextSetShadowWithColor( curContext, kShadowBlurOffset, kShadowBlurRadius, blurColor.CGColor );

        CGContextBeginPath( curContext );
        CGContextAddPath( curContext, badgePath );
        CGContextClosePath( curContext );
        
        CGContextDrawPath( curContext, kCGPathFillStroke );
        CGContextRestoreGState(curContext); 
    }
    
    CGContextBeginPath( curContext );
    CGContextAddPath( curContext, badgePath );
    CGContextClosePath( curContext );
    CGContextDrawPath( curContext, kCGPathFillStroke );

    //
    // add shine to badge
    //
    
    if (self.shine) {
        CGContextBeginPath( curContext );
        CGContextAddPath( curContext, badgePath );
        CGContextClosePath( curContext );
        CGContextClip(curContext);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
        CGFloat shinyColorGradient[8] = {1, 1, 1, 0.8, 1, 1, 1, 0}; 
        CGFloat shinyLocationGradient[2] = {0, 1}; 
        CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, 
                                                                    shinyColorGradient, 
                                                                    shinyLocationGradient, 2);
        
        CGContextSaveGState(curContext); 
        CGContextBeginPath(curContext); 
        CGContextMoveToPoint(curContext, 0, 0); 
        
        CGFloat shineStartY = badgeRect.size.height*0.25;
        CGFloat shineStopY = shineStartY + badgeRect.size.height*0.4;
        
        CGContextAddLineToPoint(curContext, 0, shineStartY); 
        CGContextAddCurveToPoint(curContext, 0, shineStopY, 
                                        badgeRect.size.width, shineStopY, 
                                        badgeRect.size.width, shineStartY); 
        CGContextAddLineToPoint(curContext, badgeRect.size.width, 0); 
        CGContextClosePath(curContext); 
        CGContextClip(curContext); 
        CGContextDrawLinearGradient(curContext, gradient, 
                                    CGPointMake(badgeRect.size.width / 2.0, 0), 
                                    CGPointMake(badgeRect.size.width / 2.0, shineStopY), 
                                    kCGGradientDrawsBeforeStartLocation); 
        CGContextRestoreGState(curContext); 
        
        CGColorSpaceRelease(colorSpace); 
        CGGradientRelease(gradient); 
    }
    CGContextRestoreGState( curContext );
    
    CGContextSaveGState( curContext );
    CGContextSetFillColorWithColor( curContext, self.textColor.CGColor );

    //Draw text in badge
    CGPoint textPt = CGPointMake( ctm.x + (badgeRect.size.width - badgeTextSize.width)/2 ,
                                  ctm.y + (badgeRect.size.height - badgeTextSize.height)/2 );
    [badgeText drawAtPoint:textPt withFont:self.font];

    CGContextRestoreGState( curContext );

    CGPathRelease(badgePath);
}


- (CGPathRef)newBadgePathForTextSize:(CGSize)inSize
{
    CGFloat badgeWidth = 2.0*arcRadius;
    CGFloat badgeWidthAdjustment = inSize.width - inSize.height/2.0;
    if(badgeWidthAdjustment > 0) {  //If width is not long enough, badge will look thinner
        badgeWidth += badgeWidthAdjustment;
    }
    
    CGMutablePathRef badgePath = CGPathCreateMutable();
    
    CGPathMoveToPoint( badgePath, NULL, arcRadius, 0 );
    CGPathAddArc( badgePath, NULL, arcRadius, arcRadius, arcRadius, 3.0*M_PI/2.0, M_PI/2.0, YES);
    CGPathAddLineToPoint( badgePath, NULL, badgeWidth-arcRadius, 2.0*arcRadius);
    CGPathAddArc( badgePath, NULL, badgeWidth-arcRadius, arcRadius, arcRadius, M_PI/2.0, 3.0*M_PI/2.0, YES);
    CGPathAddLineToPoint( badgePath, NULL, arcRadius, 0 );
    
    return badgePath;
    
}

#pragma mark -- property methods --

- (void)setValue:(NSUInteger)inValue
{
    //Don't call self.text = nil, there will be extra overhead for updating badge size
    _text = nil;

    if(inValue == 0) {
        self.hidden = YES;
    }

    if(inValue != _value) {
        _value = inValue;
        [self _updateBadgeSize];

        if([NSThread currentThread] == [NSThread mainThread]) {
            [self setNeedsDisplay];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setNeedsDisplay];
            });
        }
    }
}

- (void)setText:(NSString *)text
{
    _value = 0;
    
    if([text length] == 0) {
        self.hidden = YES;
    }
    
    if(![text isEqualToString:_text]) {
        _text = [text copy];
        
        [self _updateBadgeSize];
        if([NSThread currentThread] == [NSThread mainThread]) {
            [self setNeedsDisplay];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setNeedsDisplay];
            });
        }
    }
}

- (void)_updateBadgeSize
{
    NSString *badgeText = ([_text length] == 0) ? [NSString stringWithFormat:@"%d",self.value] : _text;
    CGSize badgeTextSize = [badgeText sizeWithFont:self.font];
    
    CGPathRef badgePath = [self newBadgePathForTextSize:badgeTextSize];
    
    CGRect badgeRect = CGPathGetBoundingBox(badgePath);
    
    badgeRect.origin.x = 0;
    badgeRect.origin.y = 0;
    badgeRect.size.width = ceil( badgeRect.size.width ) + 2*self.pad;
    badgeRect.size.height = ceil( badgeRect.size.height ) + 2*self.pad;
    
    if(shadow) {
        badgeRect.size.width += kShadowBlurOffset.width + kShadowBlurRadius;
        badgeRect.size.height += kShadowBlurOffset.height + kShadowBlurRadius;
    }
    
    CGPathRelease(badgePath);
    _badgeSize = badgeRect.size;
}

- (void)setFont:(UIFont *)font
{
    _font = font;
    
    arcRadius = ceil((_font.lineHeight+self.pad)/2.0);
}

- (void)setPad:(NSUInteger)pad
{
    _pad = pad;
    
    arcRadius = ceil((_font.lineHeight+_pad)/2.0);
}

@end
