//
//  BackupFilePicker.m
//  ShopFolder
//
//  Created by Michael Tsai on 2012/02/23.
//  Copyright (c) 2012年 CCTSAI. All rights reserved.
//

#import "BackupFilePicker.h"
#import "StringUtil.h"

//==============================================================
//  [BEGIN] BackupFileProperty
#pragma mark - BackupFileProperty
//--------------------------------------------------------------
@implementation BackupFileProperty
@synthesize name;
@synthesize sizeInByte;

- (NSComparisonResult)compare:(BackupFileProperty *)file
{
    return [self.name compare:file.name];
}
@end
//--------------------------------------------------------------
//  [END] BackupFileProperty
//==============================================================

@implementation BackupFilePicker
@synthesize table;
@synthesize delegate;

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.table = nil;
    hud = nil;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:@"BackupFilePicker" bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        fileList = [NSMutableArray array];
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
    self.title = NSLocalizedString(@"Select Backup File", nil);
    
    hud = [[MBProgressHUD alloc]
            initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width,
                                     [[UIScreen mainScreen] bounds].size.height-[[UIApplication sharedApplication] statusBarFrame].size.height-44.0)];
    [self.view addSubview:hud];
    
    [self.table reloadData];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;// (interfaceOrientation == UIInterfaceOrientationPortrait);
}


//==============================================================
//  [BEGIN] UITableViewDelegate
#pragma mark - UITableViewDelegate
//--------------------------------------------------------------
- (void)_deselectRow: (id)sender
{
    [self.table deselectRowAtIndexPath:[self.table indexPathForSelectedRow] animated:YES];
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.delegate selectBackupFile:[fileList objectAtIndex:indexPath.row]];
    [self.table deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return tableView.rowHeight;
}
//--------------------------------------------------------------
//  [END] UITableViewDelegate
//==============================================================

//==============================================================
//  [BEGIN] UITableViewDataSource
#pragma mark - UITableViewDataSource
//--------------------------------------------------------------
#define kMinWhilteScale 0.7f
#define kWhiteScaleStep 4.0f
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellTableIdentitifier = @"BackupFileCellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellTableIdentitifier];
    if(cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellTableIdentitifier];
        cell.textLabel.backgroundColor = [UIColor clearColor];
        cell.detailTextLabel.backgroundColor = [UIColor clearColor];
        cell.detailTextLabel.textColor = [UIColor darkTextColor];
    }
    
    BackupFileProperty *file = [fileList objectAtIndex:indexPath.row];
    NSString *fileName = file.name;
    cell.textLabel.text = [fileName substringToIndex:[fileName length]-[kBackupFileNameSuffix length]];
    cell.detailTextLabel.text = [StringUtil sizeToString:[file.sizeInByte unsignedLongLongValue]];

    cell.textLabel.backgroundColor = [UIColor clearColor];
    if(indexPath.row < kWhiteScaleStep) {
        CGFloat whiteScale = (kWhiteScaleStep-indexPath.row)/kWhiteScaleStep * (1.0f - kMinWhilteScale) + kMinWhilteScale;
        cell.contentView.backgroundColor = [UIColor colorWithWhite:whiteScale alpha:1];
    } else {
        cell.contentView.backgroundColor = [UIColor colorWithWhite:kMinWhilteScale alpha:1];
    }
    
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [fileList count];
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}
//--------------------------------------------------------------
//  [END] UITableViewDataSource
//==============================================================

//==============================================================
//  [BEGIN] MBProgressHUDDelegate
#pragma mark - MBProgressHUDDelegate
//--------------------------------------------------------------
- (void)hudWasHidden:(MBProgressHUD *)hud
{
    
}
//--------------------------------------------------------------
//  [END] MBProgressHUDDelegate
//==============================================================
@end
