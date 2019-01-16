//
//  FlexibleHeightTableViewCell.m
//  ShopFolder
//
//  Created by Michael on 2012/1/8.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "FlexibleHeightTableViewCell.h"

@implementation FlexibleHeightTableViewCell
@synthesize customizedView;

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

- (void)setCustomizedView:(UIView *)view
{
    [customizedView removeFromSuperview];
    if(view) {
        [self.contentView addSubview:view];
    }

    customizedView = view;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if(self.customizedView) {
        CGFloat contentHeight = self.customizedView.frame.size.height;
        CGRect viewFrame = self.textLabel.frame;
        viewFrame.size.height = contentHeight;
        self.textLabel.frame = viewFrame;
        
        viewFrame = self.detailTextLabel.frame;
        viewFrame.size.height = contentHeight;
        self.detailTextLabel.frame = viewFrame;
    }
}

@end
