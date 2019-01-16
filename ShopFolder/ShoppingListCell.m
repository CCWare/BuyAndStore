//
//  ShoppingListCell.m
//  ShopFolder
//
//  Created by Chung-Chih Tsai on 2012/05/15.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "ShoppingListCell.h"
#import "ImageParameters.h"
#import "StringUtil.h"

#define kEditOffset             40.0f   //width of minus view

@interface ShoppingListCell ()
@end

@implementation ShoppingListCell
@synthesize name=_name;
@synthesize barcode=_barcode;
@synthesize stock=_stock;
@synthesize count=_count;
@synthesize priceStatistics=_priceStatistics;
@synthesize price=_price;
@synthesize hasBought=_hasBought;
@dynamic imageViewFrame;
@dynamic thumbImage;

@synthesize delegate;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        //Add thumbImage and init content lines
        self.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
        
        _viewHolder = [[UIView alloc] init];
        _viewHolder.userInteractionEnabled = NO;
        
        //Init imageView
        _thumbImageView = [[EditImageView alloc] initWithFrame:CGRectMake(kSpaceToImage, (kShoppingItemCellHeight-kImageHeight)/2.0f,
                                                                          kImageWidth, kImageHeight)];
        [self addSubview:_thumbImageView];
        
        //Init lines
        _nameLine = [CellLine new];
        _nameLine.thumbImageView.image = [UIImage imageNamed:@"text"];
        _nameLine.titleLabel.text = NSLocalizedString(@"Name", nil);
        _nameLine.contentLabel.numberOfLines = 2;
        _nameLine.showUnderline = YES;
        [_viewHolder addSubview:_nameLine];
        
        _priceLine = [CellLine new];
        _priceLine.thumbImageView.image = [UIImage imageNamed:@"price"];
        _priceLine.titleLabel.text = NSLocalizedString(@"Price to Buy", nil);
        _priceLine.contentLabel.numberOfLines = 1;
        _priceLine.showUnderline = YES;
//        _priceLine.contentLabel.font = [UIFont boldSystemFontOfSize:12.0f];
        [_viewHolder addSubview:_priceLine];
        
        _priceStatisticsLine = [CellLine new];
        _priceStatisticsLine.thumbImageView.image = [UIImage imageNamed:@"price_statistics"];
        _priceStatisticsLine.titleLabel.text = NSLocalizedString(@"Price", nil);
        _priceStatisticsLine.contentLabel.numberOfLines = 2;
//        _priceStatisticsLine.contentLabel.font = [UIFont boldSystemFontOfSize:12.0f];
        _priceStatisticsLine.showUnderline = YES;
        [_viewHolder addSubview:_priceStatisticsLine];
        
        _countLine = [CellLine new];
        _countLine.thumbImageView.image = [UIImage imageNamed:@"cart_empty"];
        _countLine.titleLabel.text = NSLocalizedString(@"Count to Buy", nil);
        _countLine.showUnderline = YES;
        [_viewHolder addSubview:_countLine];
        
        _stockLine = [CellLine new];
        _stockLine.thumbImageView.image = [UIImage imageNamed:@"box"];
        _stockLine.titleLabel.text = NSLocalizedString(@"In Stock", nil);
//        _stockLine.showUnderline = YES;
        [_viewHolder addSubview:_stockLine];
        
        [self addSubview:_viewHolder];
        
        _backgroundGradient = [CAGradientLayer layer];
        _backgroundGradient.frame = CGRectMake(0, 0, self.frame.size.width, kShoppingItemCellHeight);
        _backgroundGradient.colors = [NSArray arrayWithObjects:
                                      (id)[UIColor colorWithWhite:1.0f alpha:1.0].CGColor,
                                      (id)[UIColor colorWithWhite:0.9 alpha:1.0].CGColor,
                                      nil];
        _backgroundGradient.locations = @[@0.0f, @1.0f];
        [self.layer insertSublayer:_backgroundGradient atIndex:0];
    }
    return self;
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

- (UIImage *)thumbImage
{
    return _thumbImageView.image;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    // Configure the view for the selected state
}

- (void)_updateNameLine
{
    if([_name length] > 0 ||
       [_barcode.barcodeData length] == 0)
    {
        _nameLine.thumbImageView.image = [UIImage imageNamed:@"text"];
        _nameLine.titleLabel.text = NSLocalizedString(@"Name", nil);
        
        if([_name length] > 0) {
            _nameLine.contentLabel.text = _name;
        } else {
            _nameLine.contentLabel.text = @"--";
        }
    } else {
        _nameLine.thumbImageView.image = [UIImage imageNamed:@"barcode_small"];
        _nameLine.titleLabel.text = NSLocalizedString(@"Barcode", nil);
        _nameLine.contentLabel.text = [StringUtil formatBarcode:_barcode];
    }
}

- (void)setName:(NSString *)name
{
    _name = name;
    [self _updateNameLine];
}

- (void)setBarcode:(Barcode *)barcode
{
    _barcode = barcode;
    [self _updateNameLine];
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

- (void)setCount:(int)count
{
    _count = count;
    if(_count >= 0) {
        _countLine.contentLabel.text = [NSString stringWithFormat:@"%d", _count];
    } else {
        _countLine.contentLabel.text = @"--";
    }
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

- (void)setPrice:(float)price
{
    _price = price;
    
    if(_price != 0.0f) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterCurrencyStyle;
        formatter.minimumFractionDigits = 0;
        
        _priceLine.contentLabel.text = [formatter stringFromNumber:[NSNumber numberWithFloat:_price]];
    } else {
        _priceLine.contentLabel.text = @"--";
    }
}

- (CGRect)imageViewFrame
{
    return _thumbImageView.frame;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];

    void(^moveSeparatorBlock)() = ^{
        [self updateUI];
    };
    
    if(animated) {
        [UIView animateWithDuration:0.3
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                         animations:moveSeparatorBlock
                         completion:^(BOOL finished) {
                         }];
    } else {
        moveSeparatorBlock();
    }
}

- (void)setHasBought:(BOOL)hasBought
{
    _hasBought = hasBought;
    
    if(hasBought) {
        _backgroundGradient.colors = [NSArray arrayWithObjects:
                                      (id)[UIColor colorWithHue:0.11 saturation:0.2f brightness:1.0f alpha:1.0f].CGColor,
                                      (id)[UIColor colorWithHue:0.11 saturation:0.6f brightness:1.0f alpha:1.0f].CGColor,
                                      nil];
    } else {
        _backgroundGradient.colors = [NSArray arrayWithObjects:
                                      (id)[UIColor colorWithWhite:1.0f alpha:1.0].CGColor,
                                      (id)[UIColor colorWithWhite:0.9 alpha:1.0].CGColor,
                                      nil];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint touchPos = [[touches anyObject] locationInView:self];
    
    if(CGRectContainsPoint(_thumbImageView.frame, touchPos)) {
        [self.delegate imageTouched:self];
    } else if(touchPos.x > _thumbImageView.frame.origin.x + _thumbImageView.frame.size.width) {
        [super touchesBegan:touches withEvent:event];
    }
}

- (void)updateUI
{
    CGFloat lineWidth = self.frame.size.width - (kSpaceToImage*2.0f) - kImageWidth;
    if(self.accessoryType == UITableViewCellAccessoryNone ||
       self.accessoryType == UITableViewCellAccessoryDisclosureIndicator)
    {
        lineWidth -= 34;
    } else {
        lineWidth -= 44;
    }
    
    CGRect imageFrame = CGRectMake(kSpaceToImage, (kShoppingItemCellHeight-kImageHeight)/2.0f,
                                   kImageWidth, kImageHeight);
    imageFrame.origin.x = kSpaceToImage;
    if(self.isEditing) {
        lineWidth -= kEditOffset;
        imageFrame.origin.x += kEditOffset;
    }
    _thumbImageView.frame = imageFrame;
    
    CGRect frame = _nameLine.frame;
    frame.size.width = lineWidth;
    _nameLine.frame = frame;
    [_nameLine sizeToFit];
    [_nameLine updateUI];
    CellLine *lastLine = _nameLine;
    
    [_priceLine sizeToFit];
    frame = _priceLine.frame;
    frame.origin.x = lastLine.frame.origin.x;
    frame.origin.y = lastLine.frame.origin.y + lastLine.frame.size.height;
    frame.size.width = lineWidth;
    _priceLine.frame = frame;
    [_priceLine updateUI];
    lastLine = _priceLine;
    
    [_priceStatisticsLine sizeToFit];
    frame = _priceStatisticsLine.frame;
    frame.origin.x = lastLine.frame.origin.x;
    frame.origin.y = lastLine.frame.origin.y + lastLine.frame.size.height;
    frame.size.width = lineWidth;
    _priceStatisticsLine.frame = frame;
    [_priceStatisticsLine updateUI];
    lastLine = _priceStatisticsLine;
    
    [_countLine sizeToFit];
    frame = _countLine.frame;
    frame.origin.x = lastLine.frame.origin.x;
    frame.origin.y = lastLine.frame.origin.y + lastLine.frame.size.height;
    frame.size.width = lineWidth;
    _countLine.frame = frame;
    _countLine.showUnderline = (_stock >= 0);
    [_countLine updateUI];
    lastLine = _countLine;
    
    [_stockLine sizeToFit];
    frame = _stockLine.frame;
    frame.origin.x = lastLine.frame.origin.x;
    frame.origin.y = lastLine.frame.origin.y + lastLine.frame.size.height;
    frame.size.width = lineWidth;
    _stockLine.frame = frame;
    [_stockLine updateUI];
    lastLine = _stockLine;
    
    CGFloat totalHeight = lastLine.frame.origin.y + lastLine.frame.size.height;
    frame = _viewHolder.frame;
    frame.origin.x = imageFrame.origin.x + imageFrame.size.width + kSpaceToImage;
    frame.origin.y = (kShoppingItemCellHeight - totalHeight)/2.0f;
    frame.size.width = lineWidth;
    frame.size.height = totalHeight;
    _viewHolder.frame = frame;
}
@end
