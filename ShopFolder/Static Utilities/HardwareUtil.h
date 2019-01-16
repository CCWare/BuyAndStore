//
//  HardwareUtil.h
//  ShopFolder
//
//  Created by Michael on 2012/1/4.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface HardwareUtil : NSObject
+ (BOOL)hasRearCam;
+ (BOOL)canAutoFocus;
+ (BOOL)hasTorch;
+ (AVCaptureTorchMode)torchMode;
+ (BOOL)isTorching;
+ (void)toggleTorch:(AVCaptureTorchMode)torchMode;
@end
