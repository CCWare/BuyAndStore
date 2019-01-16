//
//  BarcodeScannerViewController.h
//  ShopFolder
//
//  Created by Michael on 2011/11/08.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZBarReaderViewController.h"
#import "Barcode.h"
#import "BarcodeScanOverlayView.h"
#import <AudioToolbox/AudioToolbox.h>   //For AudioServicesPlaySystemSound
#import "BarcodeHelpViewController.h"

@protocol BarcodeScanDelegate;

@interface BarcodeScannerViewController : ZBarReaderViewController <ZBarReaderDelegate, BarcodeScanOverlayDelegate, BarcodeHelpViewController,
                                                                    UITextFieldDelegate>
{
    BarcodeScanOverlayView *overlayView;
    SystemSoundID soundID;
    
    UIView *tempView;
    UIWebView *helpWebView;

    UIImageView *focusCircleInside;
    UIImageView *focusCircleOutside;
    
    UILabel *scanLabel;
    UILabel *tipLabel;
    
    NSNumberFormatter *integerFormatter;
    UIView *inputView;
    UITextField *inputField;
    UIButton *cancelInputButton;
    CGRect cancelFrameVisible;
    CGRect cancelFrameHidden;

    UIButton *doneInputButton;
    CGRect doneFrameVisible;
    CGRect doneFrameHidden;
    
    CGRect defaultScanArea;
}

@property (nonatomic, weak) id<BarcodeScanDelegate> barcodeScanDelegate;
@end

@protocol BarcodeScanDelegate
- (void)barcodeScanCancelled;
- (void)barcodeScanned:(Barcode *)barcode;
@end
