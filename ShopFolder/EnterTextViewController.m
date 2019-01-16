//
//  EnterTextViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/12/01.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "EnterTextViewController.h"

@implementation EnterTextViewController
@synthesize navItem;
@synthesize textView;
@synthesize delegate;

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.navItem = nil;
    self.textView = nil;
}


- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.navItem.title = self.title;
    [self.textView becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;//(interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
//    if(toInterfaceOrientation == UIInterfaceOrientationPortrait) {
//        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
//    } else {
//        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
//    }

    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    if(fromInterfaceOrientation == UIInterfaceOrientationPortrait) {
        self.textView.frame = CGRectMake(0, 44, [[UIScreen mainScreen] bounds].size.height, 94);
    } else {
        self.textView.frame = CGRectMake(0, 44, [[UIScreen mainScreen] bounds].size.width,
                                         [[UIScreen mainScreen] bounds].size.height-280.0f);
    }
}

//==============================================================
//  [BEGIN] IBActions
#pragma mark -
#pragma mark IBAction methods
//--------------------------------------------------------------
- (IBAction)cancel
{
    [self.delegate cancelEnteringText];
}

- (IBAction)done
{
    [self.delegate finishEnteringText:self.textView.text];
}
//--------------------------------------------------------------
//  [END] IBActions
//==============================================================

//==============================================================
//  [BEGIN] UITextViewDelegate methods
#pragma mark -
#pragma mark UITextViewDelegate methods
//--------------------------------------------------------------
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if([text rangeOfString:@"\n"].location == NSNotFound) {
        return YES;
    }
    
    //When user presses done or copies a string which contains "\n", treat as finish entering
    [self done];
    return NO;
}
//--------------------------------------------------------------
//  [END] UITextViewDelegate methods
//==============================================================
@end
