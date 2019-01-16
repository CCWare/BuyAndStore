//
//  FolderTutorialViewController.m
//  ShopFolder
//
//  Created by Michael on 2011/12/09.
//  Copyright (c) 2011年 CCTSAI. All rights reserved.
//

#import "FolderTutorialViewController.h"
#import "TutorialViewController.h"
#import "FlurryAnalytics.h"

#define kEditRow        0
#define kDeleteRow      1
//#define kMoveFolderRow  2

@implementation FolderTutorialViewController
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
    NSArray *pageStrings = nil;
    
    if(indexPath.row == kEditRow) {
        pageStrings = [NSArray arrayWithObject:@"folder_edit"];
        [FlurryAnalytics logEvent:@"Read Tutorial: Folder Edit"];
    } else if(indexPath.row == kDeleteRow) {
        pageStrings = [NSArray arrayWithObject:@"folder_delete"];
        [FlurryAnalytics logEvent:@"Read Tutorial: Folder Delete"];
    }
    
    if([pageStrings count] > 0) {
        TutorialViewController *controller = [[TutorialViewController alloc] initWithPages:pageStrings];
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
    static NSString *CellTableIdentitifier = @"FolderTutorialCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
    if(cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellTableIdentitifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;    //Only for indication
    }
    
    switch (indexPath.row) {
        case kEditRow:
            cell.textLabel.text = NSLocalizedString(@"Edit a folder", nil);
            cell.detailTextLabel.text = NSLocalizedString(@"Change image, rename and lock/unlock", nil);
            break;
        case kDeleteRow:
            cell.textLabel.text = NSLocalizedString(@"Delete a folder", nil);
            break;
        default:
            break;
    }
    
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 2;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(editingStyle == UITableViewCellEditingStyleDelete) {
    }
}
//--------------------------------------------------------------
//  [END] UITableViewDataSource
//==============================================================
@end
