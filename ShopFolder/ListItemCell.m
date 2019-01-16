//
//  ListItemCell.m
//  ShopFolder
//
//  Created by Michael on 2011/11/14.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "ListItemCell.h"
#import "NSString+TruncateToSize.h"

@interface ListItemCell ()
@property (nonatomic, strong) NSString *textBeforeEditing;
@property (nonatomic, strong) NSString *textAfterModified;
@end

@implementation ListItemCell
@synthesize textBeforeEditing;
@synthesize textAfterModified;

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


- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    if(editing) {
        isModified = NO;
        self.textBeforeEditing = self.textLabel.text;
    } else if(textBeforeEditing) {
        isModified = NO;
        self.textLabel.text = textBeforeEditing;
        self.textBeforeEditing = nil;
    }

    [super setEditing:editing animated:animated];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.textLabel.lineBreakMode = UILineBreakModeTailTruncation;
    self.textLabel.numberOfLines = 2;
    self.detailTextLabel.lineBreakMode = UILineBreakModeTailTruncation;
    
    if(!isModified ||
       ![self.textLabel.text isEqualToString:textAfterModified])
    {
        isModified = YES;

        NSString *text = self.textLabel.text;
        if([text length] == 0) {
            return;
        }
        
        NSInteger newLinePos = [text rangeOfString:@"\n" options:NSLiteralSearch].location;
        if(newLinePos != NSNotFound) {
            NSUInteger maxSize = self.contentView.frame.size.width - self.textLabel.frame.origin.x - 10;    //10 is the space to accessoryView
            NSString *firstLine = [[text substringToIndex:newLinePos] truncateToSize:maxSize withFont:self.textLabel.font lineBreakMode:UILineBreakModeTailTruncation];
            NSString *secondLine = [text substringFromIndex:newLinePos+1];
            if([secondLine length] > 0) {
                secondLine = [secondLine truncateToSize:maxSize withFont:self.textLabel.font lineBreakMode:UILineBreakModeTailTruncation];
                self.textLabel.text = [NSString stringWithFormat:@"%@\n%@", firstLine, secondLine];
            } else {
                self.textLabel.text = firstLine;
            }
        }
        
        self.textAfterModified = self.textLabel.text;
    }
}
@end
