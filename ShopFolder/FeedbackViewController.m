//
//  FeedbackViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/12/10.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "FeedbackViewController.h"

@interface FeedbackViewController ()
@property (nonatomic, strong) MBProgressHUD *_hud;
@end

@implementation FeedbackViewController
@synthesize webview;
@synthesize _hud;
@synthesize delegate;

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.webview.delegate = nil;
    self.webview = nil;

    [self._hud removeFromSuperview];
    [self._hud hide:NO];
    self._hud.delegate = nil;
    self._hud = nil;
}

- (void)dealloc
{
    [self._hud removeFromSuperview];
    [self._hud hide:NO];
    self._hud.delegate = nil;

    webview.delegate = nil;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
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

    //Detect language and load related form
    NSArray *languages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
    NSString *currentLanguage = [languages objectAtIndex:0];
    
    self._hud = [[MBProgressHUD alloc] initWithView:self.view];
    self._hud.labelText = NSLocalizedString(@"Please wait", nil);
//    self._hud.removeFromSuperViewOnHide = YES;
    self._hud.delegate = self;
    [self.view addSubview:self._hud];
//    [self._hud show:YES];
    
    NSURL *url = nil;
    if([currentLanguage hasPrefix:@"zh"]) {
        url = [NSURL URLWithString:@"https://docs.google.com/a/cctsai.tw/spreadsheet/viewform?formkey=dHo5WG9wcVBSb3hFbXpkS3laQ0EtZ0E6MQ"];
    } else {
        url = [NSURL URLWithString:@"https://docs.google.com/a/cctsai.tw/spreadsheet/viewform?formkey=dDFSUGMtNVF3MDl6Q3Nka283M0s4U3c6MQ"];
    }
    
    [self.webview loadRequest:[NSURLRequest requestWithURL:url]];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

//==============================================================
//  [BEGIN] UIWebViewDelegate
#pragma mark - UIWebViewDelegate
//--------------------------------------------------------------
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return YES;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [self._hud hide:NO];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot load feedback page", nil)
                                                    message:NSLocalizedString(@"Please try again later.", nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Back to Settings", nil)
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self._hud show:YES];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self._hud hide:YES];
}
//--------------------------------------------------------------
//  [END] UIWebViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] MBProgressHUDDelegate
#pragma mark - MBProgressHUDDelegate
//--------------------------------------------------------------
- (void)hudWasHidden
{
//    self._hud = nil;
}
//--------------------------------------------------------------
//  [END] MBProgressHUDDelegate
//==============================================================

//==============================================================
//  [BEGIN] UIAlertViewDelegate
#pragma mark - UIAlertViewDelegate
//--------------------------------------------------------------
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [self.delegate endFeedback];
}
//--------------------------------------------------------------
//  [END] UIAlertViewDelegate
//==============================================================
@end
