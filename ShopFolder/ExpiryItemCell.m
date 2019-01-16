//
//  ExpiryItemCell.m
//  ShopFolder
//
//  Created by Michael on 2012/11/30.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "ExpiryItemCell.h"
#import "MKNumberBadgeView.h"
#import "CoreDataDatabase.h"
#import "UIImage+Resize.h"
#import "UIImage+RoundedCorner.h"
#import "ImageParameters.h"
#import "TimeUtil.h"
#import "NSString+TruncateToSize.h"
#import "ColorConstant.h"
#import "StringUtil.h"

#define kBadgeTopSpace      0
#define kBadgeOffsetX       3   //Offset to the right end of thumbImageView
#define kButtonSize         30

@interface ExpiryItemCell ()
- (void)_cartButtonPressed:(id)sender;
- (void)_favoriteButtonPressed:(id)sender;
- (void)_archiveButtonPressed:(id)sender;
@end

@implementation ExpiryItemCell

@synthesize name=_name;
@synthesize barcode=_barcode;
@synthesize count=_count;
@synthesize expiryDate=_expiryDate;
@dynamic thumbImage;

@synthesize imageViewFrame=_imageViewFrame;

@synthesize delegate;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryNone;
        
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
        
        _countLine = [CellLine new];
        _countLine.thumbImageView.image = [UIImage imageNamed:@"box"];
        _countLine.titleLabel.text = NSLocalizedString(@"Count", nil);
        _countLine.showUnderline = YES;
        [_viewHolder addSubview:_countLine];
        
        _priceLine = [CellLine new];
        _priceLine.thumbImageView.image = [UIImage imageNamed:@"price"];
        _priceLine.titleLabel.text = NSLocalizedString(@"Price", nil);
        _priceLine.contentLabel.numberOfLines = 2;
        _priceLine.showUnderline = YES;
        [_viewHolder addSubview:_priceLine];
        
        _expiryDateLine = [CellLine new];
        _expiryDateLine.thumbImageView.image = [UIImage imageNamed:@"calendar"];
        _expiryDateLine.titleLabel.text = NSLocalizedString(@"Expiry Date", nil);
        _expiryDateLine.contentLabel.numberOfLines = 1;
        [_viewHolder addSubview:_expiryDateLine];
        
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
        
        UIImage *archiveImage = [UIImage imageNamed:@"archive"];
        _archiveButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _archiveButtonSize = archiveImage.size.width/2.0f + 20.0f;
        _archiveButton.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - _archiveButtonSize + 10.0f,
                                          (kExpiryItemCellHeight-archiveImage.size.height/2.0f)/2.0f,
                                          archiveImage.size.width/2.0f, archiveImage.size.height/2.0f);
        [_archiveButton setImage:archiveImage forState:UIControlStateNormal];
        [_archiveButton addTarget:self action:@selector(_archiveButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_archiveButton];
        
        //Use gadient layer will cause abnormal select color, so we use a 1 pixel wide image as background
        //*
//        CAGradientLayer *gradient = [CAGradientLayer layer];
//        gradient.frame = CGRectMake(0, 0, self.frame.size.width, kExpiryItemCellHeight);
//        gradient.colors = [NSArray arrayWithObjects:
//                           (id)[UIColor colorWithWhite:1.0f alpha:1.0].CGColor,
//                           (id)[UIColor colorWithWhite:0.9f alpha:1.0].CGColor, nil];
//        gradient.locations = @[@0.0f, @1.0f];
//        [self.layer insertSublayer:gradient atIndex:0];
        //*/
        self.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"basicInfoCellBackground"]];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    //For keeping subviews
    _nameLine.underline.backgroundColor = kCellUnderlineColor;
    _countLine.underline.backgroundColor = kCellUnderlineColor;
    _priceLine.underline.backgroundColor = kCellUnderlineColor;
    _expiryDateLine.underline.backgroundColor = kCellUnderlineColor;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    
    //For keeping subviews
    _nameLine.underline.backgroundColor = kCellUnderlineColor;
    _countLine.underline.backgroundColor = kCellUnderlineColor;
    _priceLine.underline.backgroundColor = kCellUnderlineColor;
    _expiryDateLine.underline.backgroundColor = kCellUnderlineColor;
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

- (void)setCount:(int)count
{
    _count = count;
    if(count >= 0) {
        _countLine.contentLabel.text = [NSString stringWithFormat:@"%d", count];
    } else {
        _countLine.contentLabel.text = @"--";
    }
}

- (void)setExpiryDate:(NSDate *)expiryDate
{
    _expiryDate = expiryDate;
    
    if(expiryDate) {
        _expiryDateLine.contentLabel.text = [TimeUtil timeToRelatedDescriptionFromNow:expiryDate
                                                                             limitedRange:kDefaultRelativeTimeDescriptionRange];
        
//        NSComparisonResult compareToday = [_expiryDate compare:[TimeUtil today]];
//        
//        CAGradientLayer *gradient = [CAGradientLayer layer];
//        gradient.frame = CGRectMake(0, 0, self.frame.size.width, kExpiryItemCellHeight);
//        
//        if(compareToday == NSOrderedAscending) {
//            gradient.colors = [NSArray arrayWithObjects:
//                               (id)[UIColor colorWithWhite:1.0f alpha:1.0].CGColor,
//                               (id)kColorExpiredCellBackground.CGColor, nil];
//            gradient.locations = @[@0.0f, @1.0f];
//            
//            _expiryDateLine.titleLabel.textColor = kColorExpiredCellNameColor;
//            _expiryDateLine.contentLabel.textColor = kColorExpiredCellTextColor;
//        } else if(compareToday == NSOrderedSame) {
//            gradient.colors = [NSArray arrayWithObjects:
//                               (id)[UIColor colorWithWhite:1.0f alpha:1.0].CGColor,
//                               (id)kColorNearExpiredCellBackground.CGColor,
//                               (id)[UIColor colorWithRed:1.0f green:0.3f blue:0.3f alpha:1.0f].CGColor, nil];
//            gradient.locations = @[@0.0f, @0.5f, @1.0f];
//            
//            _expiryDateLine.titleLabel.textColor = kColorExpiredCellNameColor;
//            _expiryDateLine.contentLabel.textColor = kColorExpiredCellTextColor;
//        } else {
//            gradient.colors = [NSArray arrayWithObjects:
//                               (id)[UIColor colorWithWhite:1.0f alpha:1.0].CGColor,
//                               (id)kColorNearExpiredCellBackground.CGColor, nil];
//            gradient.locations = @[@0.0f, @1.0f];
//        }
//        
//        if(_gradientLayer) {
//            [_gradientLayer removeFromSuperlayer];
//        }
//        _gradientLayer = gradient;
//        [self.layer insertSublayer:_gradientLayer atIndex:0];
    } else {
        _expiryDateLine.contentLabel.text = @"--";
    }
}

- (void)setPrice:(float)price withCurrencyCode:(NSString *)currencyCode
{
    _price = price;
    
    if(price > 0) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterCurrencyStyle;
        formatter.minimumFractionDigits = 0;
        NSString *priceString = [formatter stringFromNumber:[NSNumber numberWithDouble:price]];
        
        if([currencyCode length] > 0) {
            _priceLine.contentLabel.text = [NSString stringWithFormat:@"%@ %@", currencyCode, priceString];
        } else {
            _priceLine.contentLabel.text = priceString;
        }
    } else {
        _priceLine.contentLabel.text = @"--";
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

- (void)_archiveButtonPressed:(id)sender
{
    [self.delegate archiveButtonPressed:self];
}

- (void)updateUI
{
    CGFloat lineWidth = self.frame.size.width - (kSpaceToImage*2.0f) - kImageWidth;
//    if(self.accessoryType == UITableViewCellAccessoryNone ||
//       self.accessoryType == UITableViewCellAccessoryDisclosureIndicator)
//    {
//        lineWidth -= 34;
//    } else {
//        lineWidth -= 44;
//    }
    lineWidth -= _archiveButtonSize;
    
    CGRect frame = _nameLine.frame;
    frame.size.width = lineWidth;
    _nameLine.frame = frame;
    
    [_nameLine sizeToFit];
    [_nameLine updateUI];
    
    [_countLine sizeToFit];
    frame = _countLine.frame;
    frame.origin.x = _nameLine.frame.origin.x;
    frame.origin.y = _nameLine.frame.origin.y + _nameLine.frame.size.height;
    frame.size.width = _nameLine.frame.size.width;
    _countLine.frame = frame;
    [_countLine updateUI];
    
    [_priceLine sizeToFit];
    frame = _priceLine.frame;
    frame.origin.x = _nameLine.frame.origin.x;
    frame.origin.y = _countLine.frame.origin.y + _countLine.frame.size.height;
    frame.size.width = _nameLine.frame.size.width;
    _priceLine.frame = frame;
    [_priceLine updateUI];
    
    [_expiryDateLine sizeToFit];
    frame = _expiryDateLine.frame;
    frame.origin.x = _nameLine.frame.origin.x;
    frame.origin.y = _priceLine.frame.origin.y + _priceLine.frame.size.height;
    frame.size.width = _nameLine.frame.size.width;
    _expiryDateLine.frame = frame;
    [_expiryDateLine updateUI];
    
    CGFloat bottom = _expiryDateLine.frame.origin.y + _expiryDateLine.frame.size.height;
    frame = _viewHolder.frame;
    frame.origin.x = _imageViewFrame.origin.x + _imageViewFrame.size.width + kSpaceToImage;
    frame.origin.y = (kExpiryItemCellHeight - bottom)/2;
    frame.size.width = lineWidth;
    frame.size.height = lineWidth;
    _viewHolder.frame = frame;
}

@end
