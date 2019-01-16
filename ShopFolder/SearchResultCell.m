//
//  SearchResultCell.m
//  ShopFolder
//
//  Created by Michael on 2012/11/18.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "SearchResultCell.h"
#import "TimeUtil.h"
#import "DBNotifyDate.h"
#import "DBLocation.h"
#import "DBFolder.h"
#import "ColorConstant.h"

@implementation SearchResultCell
@synthesize folderName=_folderName;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        _folderLine = [[CellLine alloc] init];
        _folderLine.thumbImageView.image = [UIImage imageNamed:@"folder"];
        _folderLine.titleLabel.text = NSLocalizedString(@"Folder", nil);
        _folderLine.contentLabel.numberOfLines = 1;
//        _folderLine.contentLabel.font = [UIFont boldSystemFontOfSize:12.0f];
//        _dateLine.titleLabel.textColor = [UIColor whiteColor];
//        _dateLine.contentLabel.textColor = [UIColor whiteColor];
        _folderLine.showUnderline = YES;
        [_viewHolder addSubview:_folderLine];
    }
    
    return self;
}

- (void)setFolderItem:(DBFolderItem *)folderItem
{
    _folderItem = folderItem;
    [self updateUI];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    
    if([backgroundColor isEqual:kColorExpiredCellBackground]) {
        _folderLine.titleLabel.textColor = kColorExpiredCellNameColor;
        _folderLine.contentLabel.textColor = kColorExpiredCellTextColor;
    } else {
        _folderLine.titleLabel.textColor = kColorDefaultCellNameColor;
        _folderLine.contentLabel.textColor = kColorDefaultCellTextColor;
    }
}

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
    
    //Update Folder line
    CGRect frame = _folderLine.frame;
    frame.size.width = lineWidth;
    _folderLine.frame = frame;
    _folderLine.contentLabel.text = _folderItem.folder.name;
    [_folderLine sizeToFit];
    frame = _folderLine.frame;
    frame.size.width = lineWidth;
    _folderLine.frame = frame;
    [_folderLine updateUI];
    
    //Update count line
    CellLine *lastLine = _folderLine;
    [_countLine sizeToFit];
    frame = _countLine.frame;
    frame.origin.y = lastLine.frame.origin.y + lastLine.frame.size.height;
    frame.size.width = lineWidth;
    _countLine.frame = frame;
    [_countLine updateUI];
    
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
    
    lastLine = _countLine;
    [_priceLine sizeToFit];
    frame = _priceLine.frame;
    frame.origin.y = lastLine.frame.origin.y + lastLine.frame.size.height;
    frame.size.width = lineWidth;
    _priceLine.frame = frame;
    [_priceLine updateUI];
    
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
    [_locationLine updateUI];
    
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
    [_dateLine updateUI];
    
    //Update view holder
    CGFloat bottom = _dateLine.frame.origin.y + _dateLine.frame.size.height;
    frame = _viewHolder.frame;
    frame.origin.x = kCheckBoxViewWidth;
    frame.origin.y = (kSearchItemCellHeight - bottom)/2;
    frame.size.width = lineWidth;
    frame.size.height = bottom;
    _viewHolder.frame = frame;
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
