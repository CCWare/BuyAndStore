//
//  IAPCell.m
//  ShopFolder
//
//  Created by Michael Tsai on 2012/03/22.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "IAPCell.h"

@implementation IAPCell
@synthesize textLabelSize;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect frame = self.textLabel.frame;
    frame.origin = CGPointMake(10, 10);
    frame.size = textLabelSize;
    self.textLabel.frame = frame;
    
    frame = self.detailTextLabel.frame;
    frame.origin.x = self.textLabel.frame.origin.x + textLabelSize.width;
    frame.origin.y = 10;
    frame.size.width = 280-textLabelSize.width;
    frame.size.height = textLabelSize.height;
    self.detailTextLabel.frame = frame;
}
@end
