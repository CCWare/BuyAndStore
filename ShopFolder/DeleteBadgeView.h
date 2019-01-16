//
//  DeleteBadgeView.h
//  ShopFolder
//
//  Created by Michael on 2011/12/02.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DeleteBadgeView : UIImageView
{
    UIImage *deleteImage;
    UIImage *highlightedDeleteImage;
    NSDate *_lastHighlightTime;
}

- (void)setHidden:(BOOL)hidden animated:(BOOL)animate;

@end
