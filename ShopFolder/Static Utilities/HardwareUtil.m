//
//  HardwareUtil.m
//  ShopFolder
//
//  Created by Michael on 2012/1/4.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "HardwareUtil.h"

@implementation HardwareUtil

+ (BOOL)hasRearCam
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    return ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] &&
            [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear]);
#endif
}

+ (BOOL)canAutoFocus
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo].isFocusPointOfInterestSupported;
#endif
}

+ (BOOL)hasTorch
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo].hasTorch;
#endif
}

+ (AVCaptureTorchMode)torchMode
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo].torchMode;
#endif
}

+ (BOOL)isTorching
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    return ([HardwareUtil hasTorch] && [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo].torchLevel > 0.0);
#endif
}

+ (void)toggleTorch:(AVCaptureTorchMode)torchMode
{
#if !TARGET_IPHONE_SIMULATOR
    if([HardwareUtil hasTorch] &&
       [[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] isTorchModeSupported:torchMode])
    {
        [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo].torchMode = torchMode;
    }
#endif
}
@end
