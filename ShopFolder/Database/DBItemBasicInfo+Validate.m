//
//  DBItemBasicInfo+Validate.m
//  ShopFolder
//
//  Created by Michael on 2012/10/08.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "DBItemBasicInfo+Validate.h"

@implementation DBItemBasicInfo (Validate)
- (BOOL)canSave
{
    if([self.name length] > 0) {
        return YES;
    }
    
    if([self.barcodeData length] > 0) {
        return YES;
    }
    
    if(self.imageRawData != nil) {
        return YES;
    }
    
    return NO;
}
@end
