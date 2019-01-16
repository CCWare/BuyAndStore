//
//  BarcodeScanOverlayView.h
//  ShopFolder
//
//  Created by Michael on 2011/11/08.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#define kToolbarHeight  54

@protocol BarcodeScanOverlayDelegate
- (void)cancelScanningbarcode;
- (void)showBarcodeHelp;
- (void)touchAt:(CGPoint)point;
@end

@interface BarcodeScanOverlayView : UIView
{
    UIToolbar *toolbar;
}

@property (nonatomic, weak) id <BarcodeScanOverlayDelegate> delegate;

@end
