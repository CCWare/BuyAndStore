//
//  BarcodeHelpViewController.m
//  ShopFolder
//
//  Created by Michael on 2012/1/4.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "BarcodeHelpViewController.h"
#import "FlurryAnalytics.h"
#import "PreferenceConstant.h"

@implementation BarcodeHelpViewController
@synthesize delegate;
@synthesize helpWebView;
@synthesize doneButton;
@synthesize blackView;
@synthesize barTitle;

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.helpWebView.delegate = nil;
    self.helpWebView = nil;
    self.doneButton = nil;
    self.barTitle = nil;
    self.blackView = nil;
}

- (void)dealloc
{
    helpWebView.delegate = nil;

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
    self.barTitle.title = NSLocalizedString(@"Barcode Scan Tips", nil);
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:kSettingAllowAnalysis]) {
        [FlurryAnalytics logPageView];
    }
   
    NSString *resourcePath = [[NSBundle mainBundle] pathForResource:@"barcode-help" ofType:@"html"];
    if(resourcePath) {
        NSURL *url = [NSURL fileURLWithPath:resourcePath isDirectory:NO];
        if(url) {
            [self.helpWebView loadRequest:[NSURLRequest requestWithURL:url]];
        }
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)done:(id)sender
{
    self.helpWebView.delegate = nil;
    [self.helpWebView stopLoading];

    [self.delegate leaveBarcodeHelp];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self.blackView removeFromSuperview];
    self.blackView = nil;
}
@end
