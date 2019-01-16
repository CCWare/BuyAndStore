//
//  TutorialViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/12/07.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "TutorialViewController.h"
#import "FlurryAnalytics.h"
#import "PreferenceConstant.h"

@implementation TutorialViewController
@synthesize contentView;
@synthesize toolbar;
@synthesize prevButton;
@synthesize indexItem;
@synthesize nextButton;
@synthesize delegate;

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.contentView = nil;
    self.toolbar = nil;
    self.prevButton = nil;
    self.indexItem = nil;
    self.nextButton = nil;
}


- (id)initWithPages:(NSArray *)pageStrings
{
    if((self = [super init])) {
        if([pageStrings count] > 0) {
            pages = [NSMutableArray array];
            NSURL *url;
            NSString *resourcePath;
            for(NSString *path in pageStrings) {
                resourcePath = [[NSBundle mainBundle] pathForResource:path ofType:@"html"];
                if(resourcePath) {
                    url = [NSURL fileURLWithPath:resourcePath isDirectory:NO];
                    if(url) {
                        [pages addObject:url];
                    }
                }
            }
        }
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

- (BOOL) _shouldShowPrevButton
{
    if(currentPageIndex <= 0 ) {
        return NO;
    }
    
    return YES;
}

- (BOOL) _shouldShowNextButton
{
    int pageCount = [pages count];
    if(pageCount > 1 &&
       currentPageIndex < pageCount-1)
    {
        return YES;
    }
    
    return NO;
}

- (void)_updateToolbar
{
    self.indexItem.title = [NSString stringWithFormat:NSLocalizedString(@"Step: %d/%d", nil), currentPageIndex+1, [pages count]];
    self.prevButton.enabled = [self _shouldShowPrevButton];
    self.nextButton.enabled = [self _shouldShowNextButton];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.prevButton.title = NSLocalizedString(@"Prev step", @"Showed in tutorial toolbar left button");
    self.nextButton.title = NSLocalizedString(@"Next step", @"Showed in tutorial toolbar right button");
    
    if([pages count] > 1) {
        [self _updateToolbar];
    } else {
        CGRect frame = self.contentView.frame;
        frame.size.height += self.toolbar.frame.size.height;
        self.contentView.frame = frame;
        self.toolbar.hidden = YES;
    }
    
    if([pages count] > 0) {
        [self.contentView loadRequest:[NSURLRequest requestWithURL:[pages objectAtIndex:currentPageIndex]]];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)done:(id)sender
{
    [self.delegate endTutorial];
}

- (IBAction)prev:(id)sender
{
    currentPageIndex--;
    [self _updateToolbar];
    [self.contentView loadRequest:[NSURLRequest requestWithURL:[pages objectAtIndex:currentPageIndex]]];
}

- (IBAction)next:(id)sender
{
    currentPageIndex++;
    [self _updateToolbar];
    [self.contentView loadRequest:[NSURLRequest requestWithURL:[pages objectAtIndex:currentPageIndex]]];
}
@end
