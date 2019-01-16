//
//  BarcodeScanOverlayView.m
//  ShopFolder
//
//  Created by Michael on 2011/11/08.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "BarcodeScanOverlayView.h"

@implementation BarcodeScanOverlayView
@synthesize delegate;

- (void)_dismiss
{
    [self.delegate cancelScanningbarcode];
}

- (void)_showHelp
{
    [self.delegate showBarcodeHelp];
}

- (void)_init
{
    toolbar = [[UIToolbar alloc] initWithFrame: CGRectMake(0, self.frame.size.height-kToolbarHeight, self.frame.size.width, kToolbarHeight)];
    toolbar.barStyle = UIBarStyleBlackOpaque;
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin;
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel
                                                                                  target: self
                                                                                  action: @selector(_dismiss)];
    
    UIBarButtonItem *toolbarSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemFlexibleSpace
                                                                                  target: nil
                                                                                  action: nil];
    
    UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [infoButton addTarget:self action:@selector(_showHelp) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *infoBarButton = [[UIBarButtonItem alloc] initWithCustomView:infoButton];
    
    toolbar.items = [NSArray arrayWithObjects: cancelButton, toolbarSpace, infoBarButton, nil];
    [self addSubview: toolbar];
}

- (id)initWithFrame:(CGRect)frame
{
    if((self = [super initWithFrame:frame])) {
        [self _init];
    }
    
    return self;
}

- (id)init
{
    if((self = [super initWithFrame:[[UIScreen mainScreen] bounds]])) {
        [self _init];
    }
    
    return self;
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(CGRectContainsPoint(toolbar.frame, [[touches anyObject] locationInView:self])) {
        return;
    }
    [self.delegate touchAt:[[touches anyObject] locationInView:self]];
}
@end
