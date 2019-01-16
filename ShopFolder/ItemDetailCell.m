//
//  ItemDetailCell.m
//  ShopFolder
//
//  Created by Michael on 2012/11/17.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "ItemDetailCell.h"
#import <QuartzCore/QuartzCore.h>
#import "ColorConstant.h"
#import "TimeUtil.h"
#import "DBLocation.h"
#import "DBNotifyDate.h"

#define kCountLabelHeightPortrait   17.0f
#define kSliderHeightPortrait       23.0f
#define kSliderPosXPortrait         (kCheckBoxViewWidth+10.0f)
#define kSliderWidthPortrait        ([UIScreen mainScreen].bounds.size.width-kCheckBoxViewWidth-20.0f)

@interface ItemDetailCell ()
- (void)_sliderValueChanged:(UISlider *)sender;
- (void)_updateCountLabel;
@end

@implementation ItemDetailCell
@synthesize folderItem=_folderItem;
@synthesize showContent=_showContent;
@synthesize isChecked=_isChecked;

@synthesize showSelectIndicator=_showSelectIndicator;
@synthesize maxCount=_maxCount;
@synthesize selectCount=_selectCount;

@synthesize delegate;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
        
        _viewHolder = [[UIView alloc] init];
        _viewHolder.userInteractionEnabled = NO;
        
        // Initialization code
        _countLine = [[CellLine alloc] init];
        _countLine.thumbImageView.image = [UIImage imageNamed:@"count"];
        _countLine.titleLabel.text = NSLocalizedString(@"Count", nil);
        _countLine.contentLabel.numberOfLines = 1;
        _countLine.showUnderline = YES;
//        _countLine.titleLabel.textColor = [UIColor whiteColor];
//        _countLine.contentLabel.textColor = [UIColor whiteColor];
        [_viewHolder addSubview:_countLine];
        
        _priceLine = [[CellLine alloc] init];
        _priceLine.thumbImageView.image = [UIImage imageNamed:@"price"];
        _priceLine.titleLabel.text = NSLocalizedString(@"Price", nil);
        _priceLine.contentLabel.numberOfLines = 1;
        _priceLine.showUnderline = YES;
//        _priceLine.titleLabel.textColor = [UIColor whiteColor];
//        _priceLine.contentLabel.textColor = [UIColor whiteColor];
        [_viewHolder addSubview:_priceLine];
        
        _locationLine = [[CellLine alloc] init];
        _locationLine.thumbImageView.image = [UIImage imageNamed:@"map"];
        _locationLine.titleLabel.text = NSLocalizedString(@"Buy from", nil);
        _locationLine.contentLabel.numberOfLines = 1;
        _locationLine.showUnderline = YES;
//        _locationLine.titleLabel.textColor = [UIColor whiteColor];
//        _locationLine.contentLabel.textColor = [UIColor whiteColor];
        [_viewHolder addSubview:_locationLine];
        
        _dateLine = [[CellLine alloc] init];
        _dateLine.thumbImageView.image = [UIImage imageNamed:@"calendar"];
        _dateLine.titleLabel.text = NSLocalizedString(@"Date", nil);
        _dateLine.contentLabel.numberOfLines = 2;
        _dateLine.contentLabel.font = [UIFont boldSystemFontOfSize:12.0f];
//        _dateLine.titleLabel.textColor = [UIColor whiteColor];
//        _dateLine.contentLabel.textColor = [UIColor whiteColor];
        _dateLine.showUnderline = NO;
        [_viewHolder addSubview:_dateLine];
        
        [self addSubview:_viewHolder];
        
        UIImage *uncheckImage = [UIImage imageNamed:@"Checkbox Empty"];
        CGSize imageViewSize = CGSizeMake(uncheckImage.size.width/2.0f, uncheckImage.size.height/2.0f);
        _checkImageView = [[UIImageView alloc] initWithFrame:CGRectMake((kCheckBoxViewWidth-imageViewSize.width)/2.0f,
                                                                        (kItemDetailCellHeight - imageViewSize.height)/2.0f,
                                                                        imageViewSize.width, imageViewSize.height)];
        _checkImageView.image = uncheckImage;
        [self addSubview:_checkImageView];
        
//        CAGradientLayer *gradient = [CAGradientLayer layer];
//        gradient.frame = CGRectMake(0, 0, self.frame.size.width, kItemDetailCellHeight);
//        gradient.colors = @[(id)[UIColor colorWithWhite:0.33f alpha:1.0].CGColor,
//                            (id)[UIColor colorWithWhite:0.1f alpha:1.0].CGColor,
//                            (id)[UIColor colorWithWhite:0.0f alpha:1.0].CGColor,
//                            (id)[UIColor colorWithWhite:0.1f alpha:1.0].CGColor,
//                            (id)[UIColor colorWithWhite:0.33f alpha:1.0].CGColor];
//        gradient.locations = @[@0, @0.1f, @0.8f, @0.9f, @1.0f];
//        [self.layer insertSublayer:gradient atIndex:0];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
    _countLine.underline.backgroundColor = kCellUnderlineColor;
    _priceLine.underline.backgroundColor = kCellUnderlineColor;
    _locationLine.underline.backgroundColor = kCellUnderlineColor;
    _dateLine.underline.backgroundColor = kCellUnderlineColor;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    
    _countLine.underline.backgroundColor = kCellUnderlineColor;
    _priceLine.underline.backgroundColor = kCellUnderlineColor;
    _locationLine.underline.backgroundColor = kCellUnderlineColor;
    _dateLine.underline.backgroundColor = kCellUnderlineColor;
}

- (void)setIsChecked:(BOOL)isChecked
{
    _isChecked = isChecked;
    if(isChecked) {
        _checkImageView.image = [UIImage imageNamed:@"Checkbox Full"];
    } else {
        _checkImageView.image = [UIImage imageNamed:@"Checkbox Empty"];
    }
    _checkImageView.transform = CGAffineTransformIdentity;
}

- (void)setShowContent:(BOOL)showContent
{
    _showContent = showContent;
    _viewHolder.hidden = !showContent;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint touchPos = [[touches anyObject] locationInView:self];
    
    if(touchPos.x > kCheckBoxViewWidth) {
        [super touchesBegan:touches withEvent:event];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint touchPos = [[touches anyObject] locationInView:self];
    
    if(touchPos.x > kCheckBoxViewWidth) {
        [super touchesEnded:touches withEvent:event];
    } else {
        _isChecked = !_isChecked;
        if(_isChecked) {
            _checkImageView.image = [UIImage imageNamed:@"Checkbox Full"];
            
            //Animate like jelly
            _checkImageView.transform = CGAffineTransformIdentity;
            [UIView animateWithDuration:0.1f
                                  delay:0.0f
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                                 _checkImageView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.1f, 1.1f);
                             } completion:^(BOOL finished) {
                                 [UIView animateWithDuration:0.1f
                                                       delay:0.0f
                                                     options:UIViewAnimationOptionAllowUserInteraction
                                                  animations:^{
                                                      _checkImageView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.9f, 0.9f);
                                                  } completion:^(BOOL finished) {
                                                      [UIView animateWithDuration:0.1f
                                                                            delay:0.0f
                                                                          options:UIViewAnimationOptionAllowUserInteraction
                                                                       animations:^{
                                                                           _checkImageView.transform = CGAffineTransformIdentity;
                                                                       } completion:^(BOOL finished) {
                                                                           
                                                                       }];
                                                  }];
                             }];
        } else {
            _checkImageView.image = [UIImage imageNamed:@"Checkbox Empty"];
            _checkImageView.transform = CGAffineTransformIdentity;
        }
        
        [self.delegate cellCheckStatusChanged:_isChecked from:self];
    }
}

- (void)setFolderItem:(DBFolderItem *)folderItem
{
    _folderItem = folderItem;
    _selectCount = _folderItem.count;
    
    [self updateUI];
}

- (void)setShowSelectIndicator:(BOOL)show
{
    [self showSelectIndicator:show animated:YES];
}

- (void)showSelectIndicator:(BOOL)show animated:(BOOL)animate
{
    _showSelectIndicator = show;
    
    if(!show) {
        void(^finishBlock)(BOOL finished) = ^(BOOL finished) {
            _countSlider.alpha = 0.0f;
            _countLabel.alpha = 0.0f;
            _viewHolder.alpha = 1.0f;
            
            _countSlider.hidden = YES;
            _countLabel.hidden = YES;
        };
        
        if(!animate) {
            finishBlock(YES);
        } else {
            [UIView animateWithDuration:0.3f
                                  delay:0.0f
                                options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                                 _countSlider.alpha = 0.0f;
                                 _countLabel.alpha = 0.0f;
                                 _viewHolder.alpha = 1.0f;
                             } completion:finishBlock];
        }
        
        self.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    } else {
        self.accessoryType = UITableViewCellAccessoryNone;
        
        if(_countSlider == nil) {
            //Add select slider
            _countSlider = [[UISlider alloc] initWithFrame:CGRectMake(kCheckBoxViewWidth,
                                                                      (kItemDetailCellHeight-kSliderHeightPortrait)/2.0f,
                                                                      kSliderWidthPortrait, kSliderHeightPortrait)];
            _countSlider.contentVerticalAlignment = UIControlContentVerticalAlignmentTop;
            [_countSlider addTarget:self action:@selector(_sliderDidEndTouch:) forControlEvents:UIControlEventTouchUpInside];
            [_countSlider addTarget:self action:@selector(_sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
            [self addSubview:_countSlider];
            
            UIFont *font = [UIFont systemFontOfSize:20.0f];
            _countLabel = [[OutlineLabel alloc] initWithFrame:CGRectMake(kCheckBoxViewWidth,
                                                                         (kItemDetailCellHeight-kSliderHeightPortrait)/2.0f-font.lineHeight,
                                                                         kSliderWidthPortrait, kSliderHeightPortrait)];
            _countLabel.font = font;
            _countLabel.textAlignment = UITextAlignmentCenter;
            _countLabel.backgroundColor = [UIColor clearColor];
            [self addSubview:_countLabel];
        }
        
        _countSlider.maximumValue = _folderItem.count;
        _countSlider.value = _selectCount;
        [self _updateCountLabel];
        _countSlider.hidden = NO;
        _countLabel.hidden = NO;
        
        if(_folderItem.count <= 1) {
            _countSlider.enabled = NO;
        }
        
        void(^finishBlock)(BOOL finished) = ^(BOOL finished) {
            _countSlider.alpha = 1.0f;
            _countLabel.alpha = 1.0f;
            _viewHolder.alpha = 0.1f;
        };
        
        if(!animate) {
            finishBlock(YES);
        } else {
            _countSlider.alpha = 0.0f;
            _countLabel.alpha = 0.0f;
            [UIView animateWithDuration:0.3f
                                  delay:0.0f
                                options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                                 _countSlider.alpha = 1.0f;
                                 _countLabel.alpha = 1.0f;
                                 _viewHolder.alpha = 0.1f;
                             } completion:^(BOOL finished) {
                                 
                             }];
        }
    }
}

- (void)_updateCountLabel
{
    _countLabel.text = [NSString stringWithFormat:@"%d / %d", _selectCount, _folderItem.count];
}

- (void)_sliderValueChanged:(UISlider *)sender
{
    BOOL isValueUpdated = NO;
    if(sender.value > 1.0f) {
        if(fabsf(_selectCount - sender.value) > 0.5f){
            int roundedValue = (int)roundf(sender.value);
            if(roundedValue >= 1 &&
               roundedValue != _selectCount)
            {
                _selectCount = roundedValue;
                isValueUpdated = YES;
            }
        }
    } else if(_selectCount > 1) {
        _selectCount = 1;
        isValueUpdated = YES;
    }
    
    if(isValueUpdated) {
        sender.value = _selectCount;
        [self _updateCountLabel];
        [self.delegate cellSelectCountChanged:_selectCount from:self];
    }
}

- (void)_sliderDidEndTouch:(UISlider *)sender
{
    sender.value = _selectCount;
}

//- (void)setBackgroundColor:(UIColor *)backgroundColor
//{
//    [super setBackgroundColor:backgroundColor];
//    
//    if([backgroundColor isEqual:kColorExpiredCellBackground]) {
//        _countLine.titleLabel.textColor = kColorExpiredCellNameColor;
//        _countLine.contentLabel.textColor = kColorExpiredCellTextColor;
//        
//        _priceLine.titleLabel.textColor = kColorExpiredCellNameColor;
//        _priceLine.contentLabel.textColor = kColorExpiredCellTextColor;
//        
//        _locationLine.titleLabel.textColor = kColorExpiredCellNameColor;
//        _locationLine.contentLabel.textColor = kColorExpiredCellTextColor;
//        
//        _dateLine.titleLabel.textColor = kColorExpiredCellNameColor;
//        _dateLine.contentLabel.textColor = kColorExpiredCellTextColor;
//    } else {
//        _countLine.titleLabel.textColor = kColorDefaultCellNameColor;
//        _countLine.contentLabel.textColor = kColorDefaultCellTextColor;
//        
//        _priceLine.titleLabel.textColor = kColorDefaultCellNameColor;
//        _priceLine.contentLabel.textColor = kColorDefaultCellTextColor;
//        
//        _locationLine.titleLabel.textColor = kColorDefaultCellNameColor;
//        _locationLine.contentLabel.textColor = kColorDefaultCellTextColor;
//        
//        _dateLine.titleLabel.textColor = kColorDefaultCellNameColor;
//        _dateLine.contentLabel.textColor = kColorDefaultCellTextColor;
//    }
//}

- (void)updateUI
{
    CGFloat lineWidth = self.frame.size.width - kCheckBoxViewWidth;
    if(self.accessoryType == UITableViewCellAccessoryNone) {
        lineWidth -= 10.0f;
    } else if(self.accessoryType == UITableViewCellAccessoryDisclosureIndicator) {
        lineWidth -= 34.0f;
    } else {
        lineWidth -= 44.0f;
    }
    CGRect frame = _countLine.frame;
    frame.size.width = lineWidth;
    _countLine.frame = frame;
    
    //Update count line
    [_countLine sizeToFit];
    frame = _countLine.frame;
    frame.size.width = lineWidth;
    _countLine.frame = frame;
    [_countLine updateUI];//]layoutSubviews];
    
    //Update price line
    NSString *currencyCode = ([currencyCode length] > 0) ? currencyCode : @"";
    if(_folderItem.price != 0 ) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterCurrencyStyle;
        formatter.minimumFractionDigits = 0;
        NSString *priceString = [formatter stringFromNumber:[NSNumber numberWithDouble:_folderItem.price]];
        
        if([currencyCode length] > 0) {
            _priceLine.contentLabel.text = [NSString stringWithFormat:@"%@ %@", currencyCode, priceString];
        } else {
            _priceLine.contentLabel.text = priceString;
        }
    } else {
        _priceLine.contentLabel.text = @"--";
    }

    CellLine *lastLine = _countLine;
    [_priceLine sizeToFit];
    frame = _priceLine.frame;
    frame.origin.y = lastLine.frame.origin.y + lastLine.frame.size.height;
    frame.size.width = lineWidth;
    _priceLine.frame = frame;
    [_priceLine updateUI];//]layoutSubviews];
    
    //Update location line
    _countLine.contentLabel.text = [NSString stringWithFormat:@"%d", _folderItem.count];
    
    if([_folderItem.location.name length] > 0) {
        _locationLine.contentLabel.text = _folderItem.location.name;
    } else {
        _locationLine.contentLabel.text = @"--";
    }
    
    lastLine = _priceLine;
    [_locationLine sizeToFit];
    frame = _locationLine.frame;
    frame.origin.y = lastLine.frame.origin.y + lastLine.frame.size.height;
    frame.size.width = lineWidth;
    _locationLine.frame = frame;
    [_locationLine updateUI];//]layoutSubviews];
    
    //Update date line
    if(_folderItem.expiryDate > 0) {
        _dateLine.contentLabel.text = [NSString stringWithFormat:@"%@%@\n%@%@",
                                       NSLocalizedString(@"Created: ", nil),
                                       [TimeUtil timeToRelatedDescriptionFromNow:[NSDate dateWithTimeIntervalSinceReferenceDate:_folderItem.createTime] limitedRange:kDefaultRelativeTimeDescriptionRange],
                                       NSLocalizedString(@"Expire: ", nil),
                                       [TimeUtil timeToRelatedDescriptionFromNow:[NSDate dateWithTimeIntervalSinceReferenceDate:_folderItem.expiryDate.date] limitedRange:kDefaultRelativeTimeDescriptionRange]];
    } else {
        _dateLine.contentLabel.text = [NSString stringWithFormat:@"%@ %@",
                                       NSLocalizedString(@"Created: ", nil),
                                       [TimeUtil timeToRelatedDescriptionFromNow:[NSDate dateWithTimeIntervalSinceReferenceDate:_folderItem.createTime] limitedRange:kDefaultRelativeTimeDescriptionRange]];
    }
    
    lastLine = _locationLine;
    [_dateLine sizeToFit];
    frame = _dateLine.frame;
    frame.origin.y = lastLine.frame.origin.y + lastLine.frame.size.height;
    frame.size.width = lineWidth;
    _dateLine.frame = frame;
    [_dateLine updateUI];//]layoutSubviews];
    
    //Update view holder
    CGFloat bottom = _dateLine.frame.origin.y + _dateLine.frame.size.height;
    frame = _viewHolder.frame;
    frame.origin.x = kCheckBoxViewWidth;
    frame.origin.y = (kItemDetailCellHeight - bottom)/2;
    frame.size.width = lineWidth;
    frame.size.height = bottom;
    _viewHolder.frame = frame;
}
@end
