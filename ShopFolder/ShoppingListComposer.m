//
//  ShoppingListComposer.m
//  ShopFolder
//
//  Created by Chung-Chih Tsai on 2012/05/17.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "ShoppingListComposer.h"
#import "DBShoppingItem.h"
#import "UIImage+Resize.h"
#import "StringUtil.h"
#import "ImageParameters.h"
#import "NSData+Encoding.h"
#import "UIImage+Merge.h"
#import <QuartzCore/QuartzCore.h>
#import "NSString+TruncateToSize.h"
#import "UIView+ConverToImage.h"
#import "TimeUtil.h"
#import "DBItemBasicInfo+SetAdnGet.h"

#define kCellWidth  (300.0f * 2.0f)
#define kCellHeight (kImageHeight*2.0f)
#define kImageTextSpace 16.0f
#define kLineWidth  2.0f

@implementation HTMLAttachedData
@synthesize content=_content;
@synthesize mimeType=_mimeType;
@synthesize fileName=_fileName;
@synthesize cid=_cid;
@end

@implementation HTMLEmailHolder
@synthesize attachedDataList=_attachedDataList;
@synthesize mailBody=_mailBody;
@synthesize isHTML=_isHTML;
@end

@implementation ShoppingListComposer
- (id)initWithShoppingList:(NSArray *)shoppingList
{
    if((self = [super init])) {
        _shoppingList = shoppingList;
        
        _currencyFormatter = [[NSNumberFormatter alloc] init];
        _currencyFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
        _currencyFormatter.minimumFractionDigits = 0;
        [_currencyFormatter setLenient:YES];
    }
    
    return self;
}

- (HTMLEmailHolder *)transformToHTML
{
    BOOL hasImage = NO;
//    for(ShoppingItem *item in _shoppingList) {
//        if([item.itemImagePath length] > 0) {
//            if(item.itemImage == nil) {
////                item.itemImage = [UIImage imageWithContentsOfFile:[StringUtil fullPathOfItemImage:item.itemImagePath]];
//                @autoreleasepool {
//                    UIImage *originImage = [UIImage imageWithContentsOfFile:[StringUtil fullPathOfItemImage:item.itemImagePath]];
//                    if(originImage.size.width > kThumbImageSize) {
//                        item.itemImage = [originImage thumbnailImage:kThumbImageSize
//                                                   transparentBorder:0
//                                                        cornerRadius:0
//                                                interpolationQuality:kCGInterpolationHigh];
//                    } else {
//                        item.itemImage = originImage;
//                    }
//                }
//            }
//        }
//        
////        if(item.itemImage) {
////            hasImage = YES;
////        }
//    }
    hasImage = YES; //always attach image in email, remove this to send text only for the list with no image
    
    HTMLEmailHolder *contentHolder = [HTMLEmailHolder new];
    if(hasImage) {  //Combine all cell into an UIImage and attach as a file
        const CGFloat LIST_HEIGHT = [_shoppingList count]*kCellHeight;
        //Prepare image shows "No Image"
        UILabel *noImageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, kImageWidth<<1, kImageHeight<<1)];
        noImageLabel.font = [UIFont boldSystemFontOfSize:32.0f];
        noImageLabel.numberOfLines = 2;
        noImageLabel.textAlignment = UITextAlignmentCenter;
        noImageLabel.contentMode = UIViewContentModeCenter;
        noImageLabel.backgroundColor = [UIColor whiteColor];
        noImageLabel.textColor = [UIColor darkGrayColor];
        noImageLabel.text = NSLocalizedString(@"No\nImage", nil);
        
        UIImage *noImageImage = [noImageLabel convertToImage];

        //Prepare context
        UIView *wholeListView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kCellWidth, LIST_HEIGHT)];
        wholeListView.backgroundColor = [UIColor whiteColor];
        UIImage *resultImage = [wholeListView convertToImage];

        const CGFloat TEXT_WIDTH = kCellWidth-(kImageWidth<<1) - kImageTextSpace; //10.0f is space between image and text
        UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(kImageWidth*2+kImageTextSpace, 0, TEXT_WIDTH, kCellHeight)];
        textLabel.font = [UIFont boldSystemFontOfSize:40.0f];
        textLabel.contentMode = UIViewContentModeCenter;
        textLabel.numberOfLines = 2;
        textLabel.lineBreakMode = UILineBreakModeMiddleTruncation;

        UILabel *detailTextLabel = [[UILabel alloc] initWithFrame:textLabel.frame];
        detailTextLabel.numberOfLines = 2;
        detailTextLabel.textColor = [UIColor lightGrayColor];
        detailTextLabel.font = [UIFont systemFontOfSize:24.0f];
        detailTextLabel.contentMode = UIViewContentModeCenter;
        
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kCellWidth, kLineWidth)];
        line.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0f];

        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, kImageWidth<<1, kImageHeight<<1)];
        int nCellIndex = 0;
        DBShoppingItem *item;
        for(int nIndex = [_shoppingList count] - 1; nIndex >= 0; nIndex--) {    //BMP draw from bottom to top
            item = [_shoppingList objectAtIndex:nIndex];

            //Draw image
            imageView.image = (item.basicInfo.imageRawData) ? [item.basicInfo getDisplayImage] : noImageImage;
            @autoreleasepool {
                resultImage = [UIImage drawView:imageView onImage:resultImage atPosition:CGPointMake(0, kCellHeight*nCellIndex) alpha:1.0f];
            }
            
            //Prepare Text
            if([item.basicInfo.name length] > 0) {
                if(item.count > 1) {
                    textLabel.text = [NSString stringWithFormat:@"%@ X %d", item.basicInfo.name, item.count];
                } else {
                    textLabel.text = item.basicInfo.name;
                }
            } else {
                if(item.count > 1) {
                    textLabel.text = [NSString stringWithFormat:@"X %d", item.count];
                } else {
                    textLabel.text = nil;
                }
            }
            
            //To attach price info, remove following block and uncomment the codes
            if([textLabel.text length] > 0) {
                textLabel.numberOfLines = 2;
                textLabel.frame = CGRectMake(kImageWidth*2+kImageTextSpace, 0, TEXT_WIDTH, kCellHeight);
                textLabel.contentMode = UIViewContentModeCenter;
                [textLabel layoutSubviews];
                @autoreleasepool {
                    resultImage = [UIImage drawView:textLabel
                                            onImage:resultImage
                                         atPosition:CGPointMake(textLabel.frame.origin.x, kCellHeight*nCellIndex)
                                              alpha:1.0f];
                }
            }
//            if(item.avgPrice == 0.0f) {
//                if([textLabel.text length] > 0) {
//                    textLabel.numberOfLines = 2;
//                    textLabel.frame = CGRectMake(kImageWidth*2+kImageTextSpace, 0, TEXT_WIDTH, kCellHeight);
//                    textLabel.contentMode = UIViewContentModeCenter;
//                    [textLabel layoutSubviews];
//                    @autoreleasepool {
//                        resultImage = [UIImage drawView:textLabel
//                                                onImage:resultImage
//                                             atPosition:CGPointMake(textLabel.frame.origin.x, kCellHeight*nCellIndex)
//                                                  alpha:1.0f];
//                    }
//                }
//            } else {
//            detailTextLabel.text = [NSString stringWithFormat:@"%@%@\n%@%@ ~ %@",
//                                    NSLocalizedString(@"Average: ", nil), [_currencyFormatter stringFromNumber:[NSNumber numberWithDouble:item.avgPrice]],
//                                    NSLocalizedString(@"Range: ", nil),
//                                    [_currencyFormatter stringFromNumber:[NSNumber numberWithDouble:item.minPrice]],
//                                    [_currencyFormatter stringFromNumber:[NSNumber numberWithDouble:item.maxPrice]]];
//
//                if([textLabel.text length] > 0) {
//                    textLabel.frame = CGRectMake(kImageWidth*2+kImageTextSpace, kImageHeight-textLabel.font.lineHeight,
//                                                 TEXT_WIDTH, textLabel.font.lineHeight);
//                    textLabel.numberOfLines = 1;
//                    textLabel.contentMode = UIViewContentModeBottom;
//                    [textLabel layoutSubviews];
//                    @autoreleasepool {
//                        resultImage = [UIImage drawView:textLabel
//                                                onImage:resultImage
//                                             atPosition:CGPointMake(textLabel.frame.origin.x,
//                                                                    kCellHeight*nCellIndex+kImageHeight-textLabel.font.lineHeight)
//                                                  alpha:1.0f];
//                    }
//                    
//                    detailTextLabel.frame = CGRectMake(kImageWidth*2+kImageTextSpace, 0, TEXT_WIDTH, kImageHeight);
//                    detailTextLabel.contentMode = UIViewContentModeTop;
//                    [detailTextLabel layoutSubviews];
//                    @autoreleasepool {
//                        resultImage = [UIImage drawView:detailTextLabel
//                                                onImage:resultImage
//                                             atPosition:CGPointMake(textLabel.frame.origin.x, kCellHeight*nCellIndex+kImageHeight)
//                                                  alpha:1.0f];
//                    }
//                } else {
//                    //Draw detailText only
//                    detailTextLabel.frame = CGRectMake(kImageWidth*2+kImageTextSpace, 0, TEXT_WIDTH, kCellHeight);
//                    detailTextLabel.contentMode = UIViewContentModeCenter;
//                    [detailTextLabel layoutSubviews];
//                    @autoreleasepool {
//                        resultImage = [UIImage drawView:detailTextLabel
//                                                onImage:resultImage
//                                             atPosition:CGPointMake(textLabel.frame.origin.x, kCellHeight*nCellIndex)
//                                                  alpha:1.0f];
//                    }
//                }
//            }
            
            @autoreleasepool {
                resultImage = [UIImage drawView:line onImage:resultImage atPosition:CGPointMake(0, kCellHeight*nCellIndex) alpha:1.0f];
            }

            nCellIndex++;
        }
        
        UIView *frameLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kCellWidth, kLineWidth)];
        @autoreleasepool {
            //Draw top line
            frameLine.backgroundColor = [UIColor colorWithWhite:0.85f alpha:1.0f];
            resultImage = [UIImage drawView:frameLine onImage:resultImage atPosition:CGPointZero alpha:1.0f];
        }
        
        @autoreleasepool {
            //Draw bottom line
            resultImage = [UIImage drawView:frameLine
                                    onImage:resultImage
                                 atPosition:CGPointMake(0, kCellHeight*[_shoppingList count]-kLineWidth)
                                      alpha:1.0f];
        }

        @autoreleasepool {
            //Draw left line
            frameLine.frame = CGRectMake(0, 0, kLineWidth, kCellHeight*[_shoppingList count]);
            resultImage = [UIImage drawView:frameLine onImage:resultImage atPosition:CGPointZero alpha:1.0f];
        }
        
        @autoreleasepool {
            //Draw right line
            resultImage = [UIImage drawView:frameLine onImage:resultImage atPosition:CGPointMake(kCellWidth-kLineWidth, 0.0f) alpha:1.0f];
        }
        
        @autoreleasepool {
            //Draw image-text separator line
            resultImage = [UIImage drawView:frameLine onImage:resultImage atPosition:CGPointMake(kImageWidth*2, 0.0f) alpha:1.0f];
        }
        
        HTMLAttachedData *data = [HTMLAttachedData new];
        data.content = UIImageJPEGRepresentation(resultImage, 0.5f);// UIImagePNGRepresentation(resultImage);   //png may be too big
        data.mimeType = @"image/jpeg";
        data.cid = [NSString stringWithFormat:@"ShoppingList_%@.jpg", [TimeUtil dateToString:[NSDate date] inFormat:@"yyyyMMdd_HHmmss"]];        data.fileName = data.cid;
        contentHolder.attachedDataList = [NSArray arrayWithObject:data];
    
        contentHolder.isHTML = YES;
        contentHolder.mailBody = nil;
    } else {
        contentHolder.isHTML = NO;
        contentHolder.mailBody = [self transformToSMS];
    }

    return contentHolder;
}

- (NSString *)transformToSMS
{
    NSMutableString *smsBody = [NSMutableString string];
    [smsBody appendString:NSLocalizedString(@"Shopping List:\n", nil)];
    BOOL hasSMSBody = NO;
    for(DBShoppingItem *item in _shoppingList) {
        if([item.basicInfo.name length] > 0) {
            hasSMSBody = YES;
            if(item.count > 1) {
                [smsBody appendFormat:@"%@ X %d\n", item.basicInfo.name, item.count];
            } else {
                [smsBody appendFormat:@"%@\n", item.basicInfo.name];
            }
            
        }
    }
    
    if(hasSMSBody) {
        [smsBody appendString:NSLocalizedString(@"--\nFrom BuyRecord", @"SMS tail")];
    } else {
        smsBody = nil;
    }

    return smsBody;
}
@end
