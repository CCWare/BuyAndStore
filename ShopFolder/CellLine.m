//
//  BasicInfoCellLine.m
//  ShopFolder
//
//  Created by Michael on 2012/11/14.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "CellLine.h"
#import "ColorConstant.h"

#define kPartSpace          4
#define kThumbImageSize     18
#define kHorizontalSpace    3

@interface UnderLineView : UIView

@end

@implementation UnderLineView
- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    //When drag the cell, system will change background color
    //So we do this to keep the underline
    CGFloat alpha = CGColorGetAlpha(backgroundColor.CGColor);
    if(alpha != 0.0f) {
        [super setBackgroundColor:backgroundColor];
    }
}
@end

@implementation CellLine
@synthesize thumbImageView=_thumbImageView;
@synthesize titleLabel=_titleLabel;
@synthesize contentLabel=_contentLabel;
@synthesize showUnderline=_showUnderline;
@synthesize underline=_underline;
@synthesize keepImageSpace=_keepImageSpace;

- (void)_init
{
    self.backgroundColor = [UIColor clearColor];
    
    _thumbImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, kThumbImageSize, kThumbImageSize)];
    _thumbImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_thumbImageView];
    
    _titleLabel = [[UILabel alloc] initWithFrame:self.frame];
    _titleLabel.textColor = kColorDefaultCellNameColor;
    _titleLabel.textAlignment = UITextAlignmentRight;
    _titleLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.font = [UIFont systemFontOfSize:12];
    [self addSubview:_titleLabel];
    
    _contentLabel = [[UILabel alloc] initWithFrame:self.frame];
    _contentLabel.textColor = kColorDefaultCellTextColor;
    _contentLabel.textAlignment = UITextAlignmentLeft;
    _contentLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    _contentLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
    _contentLabel.backgroundColor = [UIColor clearColor];
    _contentLabel.font = [UIFont boldSystemFontOfSize:14];
    [self addSubview:_contentLabel];
}

- (id)init
{
    if((self = [super init])) {
        [self _init];
    }
    
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        [self _init];
    }
    return self;
}

- (void)updateUI
{
    [self.titleLabel sizeToFit];
    [self.contentLabel sizeToFit];
    
    CGRect imageFrame = CGRectMake(0, 0, kThumbImageSize, kThumbImageSize);
    CGRect titleFrame = self.titleLabel.frame;
    CGRect contentFrame = self.contentLabel.frame;
    
    CGFloat maxHeight = MAX(titleFrame.size.height, contentFrame.size.height);
    maxHeight = MAX(maxHeight, kThumbImageSize);
    
    maxHeight += (kHorizontalSpace<<1);
    
    CGRect viewFrame = self.frame;
    viewFrame.size.height = maxHeight;
    
    if(self.thumbImageView.image == nil &&
       !self.keepImageSpace)
    {
        self.thumbImageView.hidden = YES;
        titleFrame.origin.x = 0;
        imageFrame.size.width = 0;
        
        if([self.titleLabel.text length] == 0) {
            self.titleLabel.hidden = YES;
            contentFrame.origin.x = 0;
        } else {
            self.titleLabel.hidden = NO;
            contentFrame.origin.x = titleFrame.origin.x + titleFrame.size.width + kPartSpace;
        }
    } else {
        self.thumbImageView.hidden = NO;

        titleFrame.origin.x = imageFrame.origin.x + imageFrame.size.width + kPartSpace;
        
        if([self.titleLabel.text length] == 0) {
            self.titleLabel.hidden = YES;
            contentFrame.origin.x = imageFrame.origin.x + imageFrame.size.width + kPartSpace;
        } else {
            self.titleLabel.hidden = NO;
            contentFrame.origin.x = titleFrame.origin.x + titleFrame.size.width + kPartSpace;
        }
    }
    
    contentFrame.size.width = self.frame.size.width - contentFrame.origin.x;
    
    if(self.contentLabel.numberOfLines > 1 &&
       [self.contentLabel.text length] > 0)
    {
        CGSize contentSize = [self.contentLabel.text sizeWithFont:self.contentLabel.font];
        
        if(contentSize.width > contentFrame.size.width) {
            int numberOfLine = (int)ceilf(contentSize.width/contentFrame.size.width);
            if(numberOfLine > self.contentLabel.numberOfLines) {
                numberOfLine = self.contentLabel.numberOfLines;
            }
            
            contentFrame.size.height = numberOfLine * self.contentLabel.font.lineHeight + (kHorizontalSpace<<1);
            viewFrame.size.height = contentFrame.size.height;;
        }
    }
    
    imageFrame.size.height = viewFrame.size.height;
    titleFrame.size.height = viewFrame.size.height;
    contentFrame.size.height = viewFrame.size.height;
    
    self.thumbImageView.frame = imageFrame;
    self.titleLabel.frame = titleFrame;
    self.contentLabel.frame = contentFrame;
    self.frame = viewFrame;
    
    if(self.showUnderline) {
        if(_underline == nil) {
            _underline = [UnderLineView new];
            _underline.backgroundColor = kCellUnderlineColor;
            [self addSubview:_underline];
        }
        
        _underline.frame = CGRectMake(imageFrame.size.width+kPartSpace, self.frame.size.height-1,
                                      self.frame.size.width-imageFrame.size.width-kPartSpace, 1);
        
        _underline.hidden = NO;
    } else {
        _underline.hidden = YES;
    }
}

@end
