//
//  BarcodeScannerViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/11/08.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "BarcodeScannerViewController.h"
#import "ZBarReaderView.h"
#import "StringUtil.h"
#import "PreferenceConstant.h"
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import "HardwareUtil.h"
#import "FlurryAnalytics.h"

#define MIN_FOCUS_SIZE   70.0
#define MAX_FOCUS_SIZE  120.0

#define kInputViewHeight    44

#define kDisableColor [UIColor darkGrayColor]

@interface BarcodeScannerViewController ()
- (void)_finishTypingBarcode;
- (void)_cancelTypingBarcode;

- (void)_disableDoneButton;
@end

@implementation BarcodeScannerViewController
@synthesize barcodeScanDelegate;

#pragma mark - View lifecycle
- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.cameraOverlayView = nil;

    overlayView.delegate = nil;
    [overlayView removeFromSuperview];
    overlayView = nil;
    
    [tempView removeFromSuperview];
    tempView = nil;
    
    helpWebView.delegate = nil;
    helpWebView = nil;
    
    focusCircleInside = nil;
    focusCircleOutside = nil;
    
    scanLabel = nil;
    tipLabel = nil;
}

- (void)dealloc
{
    if(soundID) {
        AudioServicesDisposeSystemSoundID(soundID);
    }

    overlayView.delegate = nil;

    tempView = nil;
    
    helpWebView.delegate = nil;
    helpWebView = nil;

    scanLabel = nil;
    tipLabel = nil;
}

- (id)init
{
    if((self = [super init])) {
        self.readerDelegate = self;

        self.showsZBarControls = NO;
        self.takesPicture = NO;
        self.showsHelpOnFail = NO;

#ifdef DEBUG
        self.readerView.showsFPS = YES; //For debugging, only works when showsZBarControls is YES
#endif
        
        [self.scanner setSymbology:ZBAR_ISBN13 config:ZBAR_CFG_ENABLE to:1];
        [self.scanner setSymbology:ZBAR_UPCA config:ZBAR_CFG_ENABLE to:1];
//        [self.scanner setSymbology:ZBAR_ISBN10 config:ZBAR_CFG_ENABLE to:1]; //Cannot detect ISBN13

        //TODO: consider landscape mode

        //Turn off QR code scanning and enhance for 1-D scanning
        [self.scanner setSymbology:ZBAR_QRCODE config:ZBAR_CFG_ENABLE to:0];
        
        NSURL *soundURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"beep" ofType:@"aiff"] isDirectory:NO];
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)soundURL, &soundID);
        
        integerFormatter = [[NSNumberFormatter alloc] init];
        integerFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        integerFormatter.maximumFractionDigits = 0;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    defaultScanArea = self.view.frame;

    //Add manual entered barcode fields
    overlayView = [[BarcodeScanOverlayView alloc] initWithFrame:CGRectMake(0, 2*kInputViewHeight, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height-2*kInputViewHeight)];
    overlayView.delegate = self;
    
    //Add top view for indicating scanning status
//    UIView *titleView = [[UIView alloc] initWithFrame:CGRectMake(0, overlayView.frame.origin.y, 320, 50)];
//    titleView.backgroundColor = [UIColor clearColor];
//    
//    //  Add shine for the view
//    CAGradientLayer *gradient = [CAGradientLayer layer];
//    gradient.frame = titleView.bounds;
//    gradient.colors = [NSArray arrayWithObjects:(id)[UIColor colorWithWhite:1.0 alpha:0.9].CGColor,
//                                                (id)[UIColor colorWithWhite:0.8 alpha:0.9].CGColor,
//                                                (id)[UIColor colorWithWhite:0.7 alpha:0.9].CGColor,
//                                                (id)[UIColor colorWithWhite:0.4 alpha:0.9].CGColor,
//                                                (id)[UIColor colorWithWhite:0.5 alpha:0.9].CGColor,
//                                                (id)[UIColor colorWithWhite:0.6 alpha:0.9].CGColor, nil];
//    gradient.locations = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0],
//                                                   [NSNumber numberWithFloat:0.3],
//                                                   [NSNumber numberWithFloat:0.5],
//                                                   [NSNumber numberWithFloat:0.51],
//                                                   [NSNumber numberWithFloat:0.7],
//                                                   [NSNumber numberWithFloat:1], nil];
//    [titleView.layer insertSublayer:gradient atIndex:0];
//    
//    [self.view addSubview:titleView];
//    
//    titleView.alpha = 0.95;
//    [UIView animateWithDuration:1
//                          delay:0
//                        options:UIViewAnimationOptionRepeat |
//                                UIViewAnimationOptionAutoreverse |
//                                UIViewAnimationOptionCurveEaseInOut |
//                                UIViewAnimationOptionAllowUserInteraction
//                     animations:^{
//                         titleView.alpha = 0.6;
//                     } completion:NULL];
    
    //Add manual input view
    inputView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, kInputViewHeight*2)];
    inputView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
    [self.view addSubview:inputView];
    
    scanLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, kInputViewHeight)];
    scanLabel.font = [UIFont boldSystemFontOfSize:26];
    scanLabel.textAlignment = UITextAlignmentCenter;
    scanLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    scanLabel.backgroundColor = [UIColor clearColor];
    scanLabel.textColor = [UIColor whiteColor];
    scanLabel.text = NSLocalizedString(@"Scanning Barcode", nil);
    scanLabel.shadowColor = [UIColor blackColor];
    scanLabel.shadowOffset = CGSizeMake(1, 1);
    [inputView addSubview:scanLabel];

    const CGFloat BUTTON_SPACE = 10.0;
    const CGFloat BUTTON_WIDTH = 50.0;  //max 50
    
    const CGFloat FIELD_WIDTH = 180.0;  //min 180
    const CGFloat FIELD_POS_X = (320.0-FIELD_WIDTH)/2.0;
    const CGFloat FIELD_MARGIN = 7.0;
    const CGFloat FIELD_HEIGHT = kInputViewHeight - 2*FIELD_MARGIN;

    UIView *inputBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(FIELD_POS_X, kInputViewHeight, FIELD_WIDTH, FIELD_HEIGHT)];
    inputBackgroundView.backgroundColor = [UIColor whiteColor];
    inputBackgroundView.layer.cornerRadius = FIELD_HEIGHT/2;
    [inputView addSubview:inputBackgroundView];
    
    inputField = [[UITextField alloc] initWithFrame:CGRectMake(FIELD_POS_X+FIELD_HEIGHT/2, kInputViewHeight,
                                                               FIELD_WIDTH-FIELD_HEIGHT/2, FIELD_HEIGHT)];
    inputField.delegate = self;
    inputField.placeholder = NSLocalizedString(@"Key in barcode", nil);
    inputField.keyboardType = UIKeyboardTypeNumberPad;
    inputField.clearButtonMode = UITextFieldViewModeWhileEditing;
    inputField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    [inputView addSubview:inputField];
    
    cancelInputButton = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelFrameVisible = CGRectMake(FIELD_POS_X-BUTTON_SPACE-BUTTON_WIDTH, kInputViewHeight, BUTTON_WIDTH, FIELD_HEIGHT);
    cancelFrameHidden = cancelFrameVisible;
    cancelFrameHidden.origin.x += (BUTTON_SPACE+FIELD_HEIGHT);
    cancelInputButton.frame = cancelFrameHidden;
    [cancelInputButton setTitle:NSLocalizedString(@"Cancel", nil) forState:UIControlStateNormal];
    cancelInputButton.titleLabel.font = [UIFont systemFontOfSize:12];
    cancelInputButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    cancelInputButton.contentMode = UIViewContentModeCenter;
    cancelInputButton.layer.cornerRadius = FIELD_HEIGHT/2;
    cancelInputButton.layer.borderWidth = 1;
    cancelInputButton.layer.borderColor = [UIColor whiteColor].CGColor;
    [cancelInputButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [cancelInputButton addTarget:self action:@selector(_cancelTypingBarcode) forControlEvents:UIControlEventTouchUpInside];
    cancelInputButton.alpha = 0;
    [inputView addSubview:cancelInputButton];
    
    doneInputButton = [UIButton buttonWithType:UIButtonTypeCustom];
    doneFrameVisible = CGRectMake(FIELD_POS_X+FIELD_WIDTH+BUTTON_SPACE, kInputViewHeight, BUTTON_WIDTH, FIELD_HEIGHT);
    doneFrameHidden = doneFrameVisible;
    doneFrameHidden.origin.x -= (BUTTON_SPACE+FIELD_HEIGHT);
    doneInputButton.frame = doneFrameHidden;
    [doneInputButton setTitle:NSLocalizedString(@"Done", nil) forState:UIControlStateNormal];
    doneInputButton.titleLabel.font = [UIFont systemFontOfSize:12];
    doneInputButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    doneInputButton.contentMode = UIViewContentModeCenter;
    doneInputButton.layer.cornerRadius = FIELD_HEIGHT/2;
    doneInputButton.layer.borderWidth = 1;
    [doneInputButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [doneInputButton setTitleColor:kDisableColor forState:UIControlStateDisabled];
    [doneInputButton addTarget:self action:@selector(_finishTypingBarcode) forControlEvents:UIControlEventTouchUpInside];
    doneInputButton.alpha = 0;
    [self _disableDoneButton];
    [inputView addSubview:doneInputButton];
    
    //Add scan tips
    const CGFloat TIP_HEIGHT = ([HardwareUtil canAutoFocus]) ? 80.0 : 60.0;
    tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, [[UIScreen mainScreen] bounds].size.height-kToolbarHeight-TIP_HEIGHT, [[UIScreen mainScreen] bounds].size.width, TIP_HEIGHT)];
    tipLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
    tipLabel.textColor = [UIColor colorWithWhite:1 alpha:1];
    tipLabel.contentMode = UIViewContentModeCenter;
    tipLabel.textAlignment = UITextAlignmentCenter;
    
    tipLabel.numberOfLines = 2;
    NSString *commonTip = NSLocalizedString(@"If the barcode is hard to be detected,\ntry to scan in landscape orientation.", nil);
    if([HardwareUtil canAutoFocus]) {
        tipLabel.numberOfLines++;
        tipLabel.text = [NSString stringWithFormat:@"%@\n%@", commonTip, NSLocalizedString(@"You can tap to focus on the barcode.", nil)];
    } else {
        tipLabel.text = commonTip;
    }
    [self.view addSubview:tipLabel];
    
    //Prepare tap-to-focus indicators
    const CGFloat STROKE_WIDTH = 2.0;
    UIGraphicsBeginImageContext(CGSizeMake(MAX_FOCUS_SIZE, MAX_FOCUS_SIZE));
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIGraphicsPushContext(context);

    CGContextSetLineWidth(context, STROKE_WIDTH);
    CGContextSetRGBFillColor(context, 0, 0, 0, 0);
    CGContextSetRGBStrokeColor(context, 0, 0, 255, 1);
    CGContextStrokeEllipseInRect(context, CGRectMake(STROKE_WIDTH, STROKE_WIDTH, MAX_FOCUS_SIZE-STROKE_WIDTH*2, MAX_FOCUS_SIZE-STROKE_WIDTH*2));

    UIGraphicsPopContext();
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    focusCircleInside = [[UIImageView alloc] initWithImage:image];
    focusCircleInside.hidden = YES;
    focusCircleOutside = [[UIImageView alloc] initWithImage:image];
    focusCircleOutside.hidden = YES;
    
    [self.view addSubview:focusCircleInside];
    [self.view addSubview:focusCircleOutside];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.showsCameraControls = NO;
    self.cameraOverlayView = overlayView;
//    [self.readerView addSubview:overlayView];
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Scan Barcode" timed:YES];
    }
}

- (void) viewWillDisappear:(BOOL)animated
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics endTimedEvent:@"Scan Barcode" withParameters:nil];
    }

    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [inputField resignFirstResponder];
    self.scanCrop = defaultScanArea;
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self.barcodeScanDelegate barcodeScanCancelled];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    self.readerDelegate = nil;

    Barcode *barcode = nil;

    id<NSFastEnumeration> results = [info objectForKey:ZBarReaderControllerResults];
    if(results) {
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingSoundBarcodeDetection]) {
            AudioServicesPlaySystemSound(soundID);
        }
        
        if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingVibrateBarcodeDetection]) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        }
        
        ZBarSymbol *symbol = nil;
        for(symbol in results)
            // just grab the first barcode
            break;

        if([symbol.data length] > 0) {
            barcode = [[Barcode alloc] init];
            barcode.barcodeType = symbol.typeName;
            if(symbol.type == ZBAR_ISBN13) {
                barcode.barcodeType = kISBNPrefix;
            }
            
            barcode.barcodeData = symbol.data;
        }
    }
    
    [self.barcodeScanDelegate barcodeScanned:barcode];
}

- (void)cancelScanningbarcode
{
    self.cameraOverlayView = nil;
    [self.barcodeScanDelegate barcodeScanCancelled];
}

- (void)showBarcodeHelp
{
    BarcodeHelpViewController *helpVC = [[BarcodeHelpViewController alloc] init];
    helpVC.delegate = self;
    helpVC.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    [self presentModalViewController:helpVC animated:YES];
}

- (void)leaveBarcodeHelp
{
    [self dismissModalViewControllerAnimated:YES];
}

- (void)_hideFocus
{
    focusCircleInside.hidden = YES;
    focusCircleOutside.hidden = YES;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [inputField resignFirstResponder];
}

- (void)touchAt:(CGPoint)point
{
    if([inputField isFirstResponder]) {
        [inputField resignFirstResponder];
        return;
    }

#if !TARGET_IPHONE_SIMULATOR
    if(![HardwareUtil canAutoFocus]) {
        return;
    }

    point.y += overlayView.frame.origin.y;

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_hideFocus) object:nil];
    const static CGFloat SCALE = MIN_FOCUS_SIZE/MAX_FOCUS_SIZE;
    focusCircleInside.transform = CGAffineTransformIdentity;
    focusCircleInside.center = point;
    focusCircleInside.hidden = NO;
    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         focusCircleInside.transform = CGAffineTransformScale(CGAffineTransformIdentity, SCALE, SCALE);
                     }
                     completion:^(BOOL finished) {
                         if(finished) {
                             focusCircleOutside.transform = CGAffineTransformScale(CGAffineTransformIdentity, SCALE, SCALE);
                             focusCircleOutside.center = point;
                             focusCircleOutside.hidden = NO;
                             focusCircleOutside.alpha = 1;
                             [UIView animateWithDuration:0.25
                                                   delay:0
                                                 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseIn
                                              animations:^{
                                                  focusCircleOutside.alpha = 0;
                                                  focusCircleOutside.transform = CGAffineTransformIdentity;
                                              }
                                              completion:^(BOOL finished) {
                                                  focusCircleOutside.hidden = YES;
                                                  [self performSelector:@selector(_hideFocus) withObject:nil afterDelay:0.75];
                                              }];
                         }
                     }];
    
    CGPoint focusPoint = CGPointMake(point.x/overlayView.frame.size.width, point.y/overlayView.frame.size.height);

    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([device isFocusPointOfInterestSupported] &&
        [device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
    {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.focusPointOfInterest = focusPoint;
            device.focusMode = AVCaptureFocusModeAutoFocus;
            [device unlockForConfiguration];
            
            if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
                [FlurryAnalytics logEvent:@"Touch to focus barcode"];
            }
        } else {
            NSLog(@"Fail to set focus");
        }        
    }
#endif
}


//==============================================================
//  [BEGIN] Input Button Actions
#pragma mark - Input Button Actions
//--------------------------------------------------------------
- (void)_finishTypingBarcode
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logEvent:@"Manual key in barcode"];
    }

    Barcode *barcode = [[Barcode alloc] initWithType:nil andData:inputField.text];
    [self.barcodeScanDelegate barcodeScanned:barcode];
}

- (void)_cancelTypingBarcode
{
    inputField.text = nil;
    [inputField resignFirstResponder];
}
//--------------------------------------------------------------
//  [END] Input Button Actions
//==============================================================

//==============================================================
//  [BEGIN] UITextFieldDelegate
#pragma mark - UITextFieldDelegate Methods
//--------------------------------------------------------------
- (void)_disableDoneButton
{
    doneInputButton.enabled = NO;
    doneInputButton.layer.borderColor = kDisableColor.CGColor;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    self.scanCrop = CGRectZero;
    scanLabel.text = NSLocalizedString(@"Pause Scan", nil);
    
    //Show cancel(enable) and done button(disable)
    [self _disableDoneButton];

    [UIView animateWithDuration:0.3
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationCurveEaseIn
                     animations:^{
                         cancelInputButton.alpha = 1;
                         cancelInputButton.frame = cancelFrameVisible;
                         doneInputButton.frame = doneFrameVisible;
                         doneInputButton.alpha = 1;
                     } completion:^(BOOL finished) {
                     }];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    inputField.text = nil;
    
    [UIView animateWithDuration:0.3
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationCurveEaseOut | 
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         cancelInputButton.frame = cancelFrameHidden;
                         doneInputButton.frame = doneFrameHidden;
                         cancelInputButton.alpha = 0;
                         doneInputButton.alpha = 0;
                     } completion:^(BOOL finished) {
                         [self _disableDoneButton];
                     }];

    self.scanCrop = defaultScanArea;
    scanLabel.text = NSLocalizedString(@"Scanning Barcode", nil);
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *candidateString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if([candidateString length] == 0) {
        [self _disableDoneButton];
        return YES;
    }
    
    if(![integerFormatter numberFromString:candidateString]) {
        return NO;
    }
    
    range = [candidateString rangeOfString:@"."];
    if(range.length > 0) {
        return NO;
    }
    
    doneInputButton.enabled = YES;
    doneInputButton.layer.borderColor = [UIColor whiteColor].CGColor;
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    [self _disableDoneButton];
    return YES;
}
//--------------------------------------------------------------
//  [END] UITextFieldDelegate
//==============================================================
@end
