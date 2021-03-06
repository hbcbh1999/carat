//
//  ReportViewController.m
//  Carat
//
//  Created by Adam Oliner on 12/14/11.
//  Copyright (c) 2011 UC Berkeley. All rights reserved.
//

#import "ReportViewController.h"
#import "ReportItemCell.h"
#import "CorePlot-CocoaTouch.h"
#import "Utilities.h"
#import "DetailViewController.h"
#import "FlurryAnalytics.h"
#import "UIImageDoNotCache.h"

@implementation ReportViewController

@synthesize detailViewName;
@synthesize tableTitle;
@synthesize thisText;
@synthesize thatText;

@synthesize report;

@synthesize dataTable = _dataTable;

// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
        // custom code (overridden by subclass)
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    DLog(@"Memory warning.");
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

// overridden by subclasses
- (DetailViewController *)getDetailView
{
    return nil;
}

// overridden by subclasses
- (void)loadDataWithHUD:(id)obj { }

#pragma mark - MBProgressHUDDelegate method

- (void)hudWasHidden:(MBProgressHUD *)hud
{
    // Remove HUD from screen when the HUD was hidded
    [HUD removeFromSuperview];
    [HUD release];
	HUD = nil;
}

#pragma mark - table methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (report != nil && [report hbListIsSet]) {
        return [[report hbList] count];
    } else return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return self.tableTitle;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"ReportItemCell";
    
    ReportItemCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"ReportItemCell" owner:nil options:nil];
        for (id currentObject in topLevelObjects) {
            if ([currentObject isKindOfClass:[ReportItemCell class]]) {
                cell = (ReportItemCell *)currentObject;
                break;
            }
        }
    }
    
    // Set up the cell...
    NSString *appName = [[[report hbList] objectAtIndex:indexPath.row] appName];
    cell.appName.text = appName;
    
    /*UIImage *img = [UIImage newImageNotCached:[appName stringByAppendingString:@".png"]];
    if (img == nil) {
        img = [UIImage newImageNotCached:@"icon57.png"];
    }
    cell.appIcon.image = img;
    [img release];*/
    NSString *imageURL = [[@"https://s3.amazonaws.com/carat.icons/" 
                           stringByAppendingString:appName] 
                          stringByAppendingString:@".jpg"];
    
    [cell.appIcon setImageWithURL:[NSURL URLWithString:imageURL]
                 placeholderImage:[UIImage imageNamed:@"icon57.png"]];
    
    cell.appScore.progress = [[[report hbList] objectAtIndex:indexPath.row] wDistance];    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    NSDate *lastUpdated = [[CoreDataManager instance] getLastReportUpdateTimestamp];
    NSDate *now = [NSDate date];
    NSTimeInterval howLong = [now timeIntervalSinceDate:lastUpdated];
    return [Utilities formatNSTimeIntervalAsUpdatedNSString:howLong];
}

// loads the selected detail view
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    ReportItemCell *selectedCell = (ReportItemCell *)[tableView cellForRowAtIndexPath:indexPath];
    [selectedCell setSelected:NO animated:YES];
    
    DetailViewController *dvController = [self getDetailView];
    HogsBugs *hb = [[self.report hbList] objectAtIndex:indexPath.row];
    [dvController setXVals:[hb xVals]];
    [dvController setYVals:[hb yVals]];
    [dvController setXValsWithout:[hb xValsWithout]];
    [dvController setYValsWithout:[hb yValsWithout]];
    [self.navigationController pushViewController:dvController animated:YES];
    
    [[dvController appName] makeObjectsPerformSelector:@selector(setText:) withObject:selectedCell.appName.text];
    
    NSString *imageURL = [[@"https://s3.amazonaws.com/carat.icons/" 
                           stringByAppendingString:selectedCell.appName.text] 
                          stringByAppendingString:@".jpg"];
    DLog(imageURL);
    
    for (UIImageView *appimg in dvController.appIcon) {
        [appimg setImageWithURL:[NSURL URLWithString:imageURL]
               placeholderImage:[UIImage imageNamed:@"icon57.png"]];
    }

    for (UIProgressView *pBar in [dvController appScore]) {
        [pBar setProgress:selectedCell.appScore.progress];
    }
    
    [[dvController thisText] makeObjectsPerformSelector:@selector(setText:) withObject:self.thisText];
    [[dvController thatText] makeObjectsPerformSelector:@selector(setText:) withObject:self.thatText];
    
    [FlurryAnalytics logEvent:[@"selected" stringByAppendingString:self.detailViewName]
               withParameters:[NSDictionary dictionaryWithObjectsAndKeys:selectedCell.appName.text, @"App Name", nil]];
}

#pragma mark - View lifecycle

// overridden by subclasses
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    //Setup the navigation
    self.navigationItem.title = self.tableTitle;
}

// overridden by subclasses
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    
    [[CoreDataManager instance] checkConnectivityAndSendStoredDataToServer];
    [self.dataTable reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loadDataWithHUD:) 
                                                 name:@"CCDMReportUpdateStatusNotification"
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"CCDMReportUpdateStatusNotification" object:nil];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return YES;
}

- (void)viewDidUnload
{
    [dataTable release];
    [self setDataTable:nil];
    [report release];
    [self setReport:nil];
    
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)dealloc {
    [detailViewName release];
    [tableTitle release];
    [thisText release];
    [thatText release];
    [report release];
    [dataTable release];
    [super dealloc];
}

@end
