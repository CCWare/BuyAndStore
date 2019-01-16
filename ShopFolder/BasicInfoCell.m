//
//  BasicInfoCell.m
//  ShopFolder
//
//  Created by Michael on 2012/11/09.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "BasicInfoCell.h"
#import "MKNumberBadgeView.h"
#import "CoreDataDatabase.h"
#import "UIImage+Resize.h"
#import "UIImage+RoundedCorner.h"
#import "ImageParameters.h"
#import "TimeUtil.h"
#import "NSString+TruncateToSize.h"
#import "ColorConstant.h"
#import <QuartzCore/QuartzCore.h>
#import "StringUtil.h"

#define kBadgeTopSpace      0
#define kBadgeOffsetX       3   //Offset to the right end of thumbImageView
#define kButtonSize         30

@interface BasicInfoCell ()
- (void)_cartButtonPressed:(id)sender;
- (void)_favoriteButtonPressed:(id)sender;
- (void)_editButtonPressed:(id)sender;
@end

@implementation BasicInfoCell

@synthesize name=_name;
@synthesize priceStatistics=__priceStatistics;
@synthesize nextExpiryDate=_nextExpiryDate;
@synthesize stock=_stock;
@dynamic thumbImage;
@dynamic expiredCount;
@dynamic nearExpiredCount;

@synthesize showNextExpiredTime=_showNextExpiredTime;
@synthesize showExpiryInformation=_showExpiryInformation;
@synthesize showContent=_showContent;
@synthesize hideEditButton=_hideEditButton;

@synthesize imageViewFrame=_imageViewFrame;

@synthesize delegate;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        _viewHolder = [[UIView alloc] init];
        _viewHolder.userInteractionEnabled = NO;
        
        //Init imageView
        _imageViewFrame = CGRectMake(kSpaceToImage, kSpaceToImage+6, kImageWidth, kImageHeight);
        _thumbImageView = [[EditImageView alloc] initWithFrame:_imageViewFrame];
        [self addSubview:_thumbImageView];
        
        //Init lines
        _nameLine = [CellLine new];
        _nameLine.thumbImageView.image = [UIImage imageNamed:@"text"];
        _nameLine.titleLabel.text = NSLocalizedString(@"Name", nil);
        _nameLine.contentLabel.numberOfLines = 2;
        _nameLine.showUnderline = YES;
        [_viewHolder addSubview:_nameLine];
        
        _stockLine = [CellLine new];
        _stockLine.thumbImageView.image = [UIImage imageNamed:@"box"];
        _stockLine.titleLabel.text = NSLocalizedString(@"In Stock", nil);
        _stockLine.showUnderline = YES;
        [_viewHolder addSubview:_stockLine];
        
        _priceStatisticsLine = [CellLine new];
        _priceStatisticsLine.thumbImageView.image = [UIImage imageNamed:@"price_statistics"];
        _priceStatisticsLine.titleLabel.text = NSLocalizedString(@"Price", nil);
        _priceStatisticsLine.contentLabel.numberOfLines = 2;
        _priceStatisticsLine.showUnderline = YES;
        [_viewHolder addSubview:_priceStatisticsLine];
        
        _nextExpiryDateLine = [CellLine new];
        _nextExpiryDateLine.thumbImageView.image = [UIImage imageNamed:@"time"];
        _nextExpiryDateLine.titleLabel.text = NSLocalizedString(@"Next Expire", nil);
        _nextExpiryDateLine.contentLabel.numberOfLines = 1;
        [_viewHolder addSubview:_nextExpiryDateLine];
        
        [self addSubview:_viewHolder];
        
        //Init Cart and Favorite button
        CGFloat buttonSpace = (_imageViewFrame.size.width - (kButtonSize<<1))/3.0f;
        _cartButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _cartButton.frame = CGRectMake(kSpaceToImage + buttonSpace,
                                       _imageViewFrame.origin.y + _imageViewFrame.size.height + kSpaceToImage,
                                       kButtonSize, kButtonSize);
        [_cartButton setImage:[UIImage imageNamed:@"cart_empty"] forState:UIControlStateNormal];
        [_cartButton addTarget:self action:@selector(_cartButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_cartButton];
        
        _favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_favoriteButton addTarget:self action:@selector(_favoriteButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        _favoriteButton.frame = CGRectMake(_imageViewFrame.origin.x+_imageViewFrame.size.width-kButtonSize-buttonSpace,
                                           _cartButton.frame.origin.y, kButtonSize, kButtonSize);
        [_favoriteButton setImage:[UIImage imageNamed:@"favorite_empty"] forState:UIControlStateNormal];
        [self addSubview:_favoriteButton];
        
        _editButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_editButton addTarget:self action:@selector(_editButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        _editButton.frame = CGRectMake([UIScreen mainScreen].bounds.size.width-kButtonSize - (34.0f - kButtonSize), kSpaceToImage+3.0f,
                                       kButtonSize, kButtonSize);
        [_editButton setImage:[UIImage imageNamed:@"edit"] forState:UIControlStateNormal];
        [self addSubview:_editButton];
        
        //Init Expiry badges and next expiry text
        _expiredBadge = [[MKNumberBadgeView alloc] init];
        _expiredBadge.userInteractionEnabled = NO;
        [self addSubview:_expiredBadge];
        
        _nearExpiredBadge = [[MKNumberBadgeView alloc] init];
        _nearExpiredBadge.fillColor = kNearExpiredBadgeColor;
        _nearExpiredBadge.userInteractionEnabled = NO;
        [self addSubview:_nearExpiredBadge];

        //Use gadient layer will cause abnormal select color, so we use a 1 pixel wide image as background
        //*
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.frame = CGRectMake(0, 0, self.frame.size.width, kBasicInfoCellHeight);
        gradient.colors = [NSArray arrayWithObjects:(id)[UIColor colorWithWhite:1.0f alpha:1.0].CGColor,
                                                    (id)[UIColor colorWithWhite:0.9f alpha:1.0].CGColor, nil];
        gradient.locations = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0.0f],
                                                       [NSNumber numberWithFloat:1.0f], nil];
        [self.layer insertSublayer:gradient atIndex:0];
        //*/
//        self.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"basicInfoCellBackground"]];
    }
    return self;
}

- (void)setAccessoryType:(UITableViewCellAccessoryType)accessoryType
{
    [super setAccessoryType:accessoryType];
    
    _lineWidth = self.frame.size.width - (kSpaceToImage*2.0f) - kImageWidth;
    if(self.accessoryType == UITableViewCellAccessoryNone ||
       self.accessoryType == UITableViewCellAccessoryDisclosureIndicator)
    {
        _lineWidth -= 34;
    } else {
        _lineWidth -= 44;
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    //For keeping subviews
    _nameLine.underline.backgroundColor = kCellUnderlineColor;
    _stockLine.underline.backgroundColor = kCellUnderlineColor;
    _priceStatisticsLine.underline.backgroundColor = kCellUnderlineColor;
    _nextExpiryDateLine.underline.backgroundColor = kCellUnderlineColor;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    
    //For keeping subviews
    _nameLine.underline.backgroundColor = kCellUnderlineColor;
    _stockLine.underline.backgroundColor = kCellUnderlineColor;
    _priceStatisticsLine.underline.backgroundColor = kCellUnderlineColor;
    _nextExpiryDateLine.underline.backgroundColor = kCellUnderlineColor;
}

- (void)updateFromLoadedBasicInfo:(LoadedBasicInfoData *)info animated:(BOOL)animate
{
    self.showContent = (info != nil);
    self.showExpiryInformation = (info != nil);
    _cartButton.hidden = (info == nil);
    _favoriteButton.hidden = _cartButton.hidden;
    
    void(^updateUIBlock)() = ^{
        self.name = info.name;
        if([info.name length] == 0 &&
           [info.barcode.barcodeData length] > 0)
        {
            //time to show barcode
            _nameLine.titleLabel.text = NSLocalizedString(@"Barcode", nil);
            _nameLine.contentLabel.text = [StringUtil formatBarcode:info.barcode];
            _nameLine.thumbImageView.image = [UIImage imageNamed:@"barcode_small"];
        } else {
            _nameLine.titleLabel.text = NSLocalizedString(@"Name", nil);
            _nameLine.thumbImageView.image = [UIImage imageNamed:@"text"];
        }
        
        self.thumbImage = info.image;
        self.stock = info.stock;
        self.priceStatistics = info.priceStatistics;
        self.nextExpiryDate = info.nextExpiryDate;
        self.expiredCount = info.expiredCount;
        self.nearExpiredCount = info.nearExpiredCount;
        
        [self updateUI];
    };
    
    if(info) {
        if(!animate) {
            updateUIBlock();
        } else {
            [UIView animateWithDuration:0.3f
                                  delay:0.0f
                                options:UIViewAnimationOptionAllowUserInteraction|
                                        UIViewAnimationOptionBeginFromCurrentState
                             animations:updateUIBlock
                             completion:^(BOOL finished) {
                             }];
        }
    } else {
        //Hide badge
        _expiredBadge.value = 0;
        _nearExpiredBadge.value = 0;
    }
    
    [self setIsInShoppingList:info.isInShoppingList];
    [self setIsFavorite:info.isFavorite];
}

- (void)setName:(NSString *)name
{
    _name = name;
    _nameLine.contentLabel.text = _name;
}

- (UIImage *)thumbImage
{
    return _thumbImageView.image;
}

- (void)setThumbImage:(UIImage *)thumbImage
{
//    _thumbImageView.image = thumbImage;
    if(thumbImage) {
        [_thumbImageView setImage:thumbImage isPreProcessed:YES];
    } else {
        _thumbImageView.image = thumbImage;
    }
}

- (void)setStock:(int)stock
{
    _stock = stock;
    if(stock >= 0) {
        _stockLine.contentLabel.text = [NSString stringWithFormat:@"%d", _stock];
    } else {
        _stockLine.contentLabel.text = @"--";
    }
}

- (NSUInteger)expiredCount
{
    return _expiredBadge.value;
}

- (void)setExpiredCount:(NSUInteger)expiredCount
{
    _expiredBadge.value = expiredCount;
    _expiredBadge.alpha = 1.0f;
}

- (NSUInteger)nearExpiredCount
{
    return _nearExpiredBadge.value;
}

- (void)setNearExpiredCount:(NSUInteger)nearExpiredCount
{
    _nearExpiredBadge.value = nearExpiredCount;
    _nearExpiredBadge.alpha = 1.0f;
}

- (void)setPriceStatistics:(PriceStatistics *)priceStatistics
{
    _priceStatistics = priceStatistics;
    
    if(_priceStatistics.countOfPrices > 0) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterCurrencyStyle;
        formatter.minimumFractionDigits = 0;
        
        if(_priceStatistics.minPrice == _priceStatistics.maxPrice) {
            _priceStatisticsLine.contentLabel.text = [formatter stringFromNumber:[NSNumber numberWithDouble: _priceStatistics.avgPrice]];
            _priceStatisticsLine.contentLabel.font = [UIFont boldSystemFontOfSize:14.0f];
        } else {
            _priceStatisticsLine.contentLabel.text = [NSString stringWithFormat:@"%@%@\n%@%@ ~ %@",
                                                      NSLocalizedString(@"Average: ", nil), [formatter stringFromNumber:[NSNumber numberWithDouble: _priceStatistics.avgPrice]],
                                                      NSLocalizedString(@"Range: ", nil), [formatter stringFromNumber:[NSNumber numberWithDouble: _priceStatistics.minPrice]], [formatter stringFromNumber:[NSNumber numberWithDouble: _priceStatistics.maxPrice]]];
            _priceStatisticsLine.contentLabel.font = [UIFont boldSystemFontOfSize:12.0f];
        }
    } else {
        _priceStatisticsLine.contentLabel.text = @"--";
        _priceStatisticsLine.contentLabel.font = [UIFont boldSystemFontOfSize:14.0f];
    }
}

- (void) setNextExpiryDate:(NSDate *)nextExpiryDate
{
    _nextExpiryDate = nextExpiryDate;
    
    if(_nextExpiryDate) {
        _nextExpiryDateLine.contentLabel.text = [TimeUtil timeToRelatedDescriptionFromNow:_nextExpiryDate
                                                                             limitedRange:kDefaultRelativeTimeDescriptionRange];
    } else {
        _nextExpiryDateLine.contentLabel.text = @"--";
    }
}

- (void)setShowContent:(BOOL)showContent
{
    _showContent = showContent;
    _viewHolder.hidden = !showContent;
    
    if(!showContent) {
        _thumbImageView.image = nil;
    }
}

- (void)setIsInShoppingList:(BOOL)isInShoppingList
{
    if(isInShoppingList) {
        [_cartButton setImage:[UIImage imageNamed:@"cart_in"] forState:UIControlStateNormal];
    } else {
        [_cartButton setImage:[UIImage imageNamed:@"cart_empty"] forState:UIControlStateNormal];
    }
}

- (void)setIsFavorite:(BOOL)isFavorite
{
    if(isFavorite) {
        [_favoriteButton setImage:[UIImage imageNamed:@"favorite_full"] forState:UIControlStateNormal];
    } else {
        [_favoriteButton setImage:[UIImage imageNamed:@"favorite_empty"] forState:UIControlStateNormal];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint touchPos = [[touches anyObject] locationInView:self];
    
    if(CGRectContainsPoint(_imageViewFrame, touchPos)) {
        [self.delegate imageTouched:self];
    } else if(touchPos.x > _imageViewFrame.origin.x + _imageViewFrame.size.width) {
        [super touchesBegan:touches withEvent:event];
    }
}

- (void)_cartButtonPressed:(id)sender
{
    [self.delegate cartButtonPressed:self];
}

- (void)_favoriteButtonPressed:(id)sender
{
    [self.delegate favoriteButtonPressed:self];
}

- (void)_editButtonPressed:(id)sender
{
    [self.delegate editButtonPressed:self];
}

- (void)showBadgeAnimatedWithDuration:(NSTimeInterval)time afterDelay:(NSTimeInterval)delay
{
    [UIView animateWithDuration:time
                          delay:delay
                        options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         if(_expiredBadge.value > 0) {
                             _expiredBadge.alpha = 1.0f;
                         }
                         
                         if(_nearExpiredBadge.value > 0) {
                             _nearExpiredBadge.alpha = 1.0f;
                         }
                     } completion:NULL];
}

- (void)hideBadgeAnimatedWithDuration:(NSTimeInterval)time afterDelay:(NSTimeInterval)delay
{
    [UIView animateWithDuration:time
                          delay:delay
                        options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         _expiredBadge.alpha = 0.0f;
                         _nearExpiredBadge.alpha = 0.0f;
                     } completion:NULL];
}

- (void)updateUI
{
    _editButton.hidden = _hideEditButton;
    
    CGRect frame = _nameLine.frame;
    frame.size.width = _lineWidth;
    _nameLine.frame = frame;
    
    [_nameLine sizeToFit];
    [_nameLine updateUI];
    
    [_stockLine sizeToFit];
    frame = _stockLine.frame;
    frame.origin.x = _nameLine.frame.origin.x;
    frame.origin.y = _nameLine.frame.origin.y + _nameLine.frame.size.height;
    frame.size.width = _nameLine.frame.size.width;
    _stockLine.frame = frame;
    [_stockLine updateUI];
    
    [_priceStatisticsLine sizeToFit];
    frame = _priceStatisticsLine.frame;
    frame.origin.x = _nameLine.frame.origin.x;
    frame.origin.y = _stockLine.frame.origin.y + _stockLine.frame.size.height;
    frame.size.width = _nameLine.frame.size.width;
    _priceStatisticsLine.frame = frame;
    [_priceStatisticsLine updateUI];
    
    _nextExpiryDateLine.hidden = !self.showNextExpiredTime;
    [_nextExpiryDateLine sizeToFit];
    frame = _nextExpiryDateLine.frame;
    frame.origin.x = _nameLine.frame.origin.x;
    frame.origin.y = _priceStatisticsLine.frame.origin.y + _priceStatisticsLine.frame.size.height;
    frame.size.width = _nameLine.frame.size.width;
    _nextExpiryDateLine.frame = frame;
    [_nextExpiryDateLine updateUI];
    
    if(!self.showExpiryInformation) {
        //Hide badges
        _expiredBadge.value = 0;
        _nearExpiredBadge.value = 0;
    } else {
        CGFloat rightEndOfBadge = _thumbImageView.frame.origin.x + _thumbImageView.frame.size.width;
        if(_expiredBadge.value > 0) {
            frame.origin.x = rightEndOfBadge - _expiredBadge.badgeSize.width + kBadgeOffsetX;
            frame.origin.y = kBadgeTopSpace;
            frame.size = _expiredBadge.badgeSize;
            
            _expiredBadge.frame = frame;
            _expiredBadge.hidden = NO;
            
            if(_nearExpiredBadge.value > 0) {
                frame.origin.x = rightEndOfBadge - _nearExpiredBadge.badgeSize.width + kBadgeOffsetX;
                frame.origin.y = _expiredBadge.frame.origin.y + _expiredBadge.frame.size.height - 4.0f;
                frame.size = _nearExpiredBadge.badgeSize;
                _nearExpiredBadge.frame = frame;
                _nearExpiredBadge.hidden = NO;
            }
        } else if(_nearExpiredBadge.value > 0) {
            frame.origin.x = rightEndOfBadge - _nearExpiredBadge.badgeSize.width + kBadgeOffsetX;
            frame.origin.y = kBadgeTopSpace;
            frame.size = _nearExpiredBadge.badgeSize;
            _nearExpiredBadge.frame = frame;
            
            _nearExpiredBadge.hidden = NO;
        }
    }
    
    CGFloat totalHeight = _nextExpiryDateLine.frame.origin.y + _nextExpiryDateLine.frame.size.height;
    frame = _viewHolder.frame;
    frame.origin.x = _imageViewFrame.origin.x + _imageViewFrame.size.width + kSpaceToImage;
    frame.origin.y = (kBasicInfoCellHeight - totalHeight)/2.0f;
    frame.size.width = _lineWidth;
    frame.size.height = totalHeight;
    _viewHolder.frame = frame;
}

@end
