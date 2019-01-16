//
//  TutorialListViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/12/08.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "TutorialListViewController.h"
#import "FolderTutorialViewController.h"
#import "TutorialViewController.h"
#import "FlurryAnalytics.h"
#import <MediaPlayer/MediaPlayer.h>

#define kFolderRow      0

@interface TutorialListViewController ()
- (void)_finishPlayback:(NSNotification *)notif;
- (void)_playerLoadStateDidChange:(NSNotification *)notif;
@end

@implementation TutorialListViewController
@synthesize table;

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.table = nil;
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
}

- (void)viewWillAppear:(BOOL)animated
{
    NSIndexPath *selectedIndex = [self.table indexPathForSelectedRow];
    if(selectedIndex) {
        [self.table deselectRowAtIndexPath:selectedIndex animated:NO];
    }
    
    [super viewWillAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

//==============================================================
//  [BEGIN] UITableViewDelegate
#pragma mark - UITableViewDelegate
//--------------------------------------------------------------
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIViewController *controller = nil;

    if(indexPath.row == kFolderRow) {
        controller = [[FolderTutorialViewController alloc] init];
    }
    
    if(controller) {
        controller.title = [tableView cellForRowAtIndexPath:indexPath].textLabel.text;
        [self.navigationController pushViewController:controller animated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return tableView.rowHeight;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
}
//--------------------------------------------------------------
//  [END] UITableViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] UITableViewDataSource
#pragma mark - UITableViewDataSource
//--------------------------------------------------------------
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellTableIdentitifier = @"TutorialCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
    if(cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellTableIdentitifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;    //Only for indication
    }
    
    switch (indexPath.row) {
        case kFolderRow:
            cell.textLabel.text = NSLocalizedString(@"Folder How-to", @"Tutorial folder how-to");
            cell.detailTextLabel.text = NSLocalizedString(@"Add, delete and edit folders", nil);
            break;
        default:
            break;
    }
    
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}
//--------------------------------------------------------------
//  [END] UITableViewDataSource
//==============================================================

//==============================================================
//  [BEGIN] MediaPlayer notifications
#pragma mark - MediaPlayer notifications
//--------------------------------------------------------------
- (void)_finishPlayback:(NSNotification *)notif
{
    MPMoviePlayerViewController *playerVC = [notif object];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:MPMoviePlayerPlaybackDidFinishNotification
                                                  object:playerVC];
}

- (void)_playerLoadStateDidChange:(NSNotification *)notif
{
    MPMoviePlayerViewController *playerVC = [notif object];
    if(playerVC.moviePlayer.loadState == MPMovieLoadStatePlaythroughOK) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:MPMoviePlayerLoadStateDidChangeNotification
                                                      object:playerVC];
        playerVC.moviePlayer.controlStyle = MPMovieControlStyleFullscreen;
        [playerVC.moviePlayer play];
    }
}
//--------------------------------------------------------------
//  [END] MediaPlayer notifications
//==============================================================
@end
