//
//  ShoppingListComposer.h
//  ShopFolder
//
//  Created by Chung-Chih Tsai on 2012/05/17.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HTMLAttachedData : NSObject
{
    NSData *_content;
    NSString *_mimeType;
    NSString *_fileName;
    NSString *_cid;
}

@property (nonatomic, strong) NSData *content;
@property (nonatomic, strong) NSString *mimeType;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *cid;
@end

@interface HTMLEmailHolder : NSObject
{
    NSArray *_attachedDataList;    //Array of HTMLAttachedData
    NSString *_mailBody;
    BOOL _isHTML;
}

@property (nonatomic, strong) NSArray *attachedDataList;
@property (nonatomic, strong) NSString *mailBody;
@property (nonatomic, assign) BOOL isHTML;
@end

@interface ShoppingListComposer : NSObject
{
    NSArray *_shoppingList;
    NSNumberFormatter *_currencyFormatter;
}

- (id)initWithShoppingList:(NSArray *)shoppingList;

- (HTMLEmailHolder *)transformToHTML;
- (NSString *)transformToSMS;
@end
