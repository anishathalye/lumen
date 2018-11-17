//
//  IgnoreListWindowController.m
//  Lumen
//
//  Created by David Christiandy on 28/10/17.
//  Copyright © 2017 Anish Athalye. All rights reserved.
//

#import "IgnoreListWindowController.h"

typedef NS_ENUM(NSInteger, IgnoreListSegmentAction) {
    IgnoreListSegmentActionAdd,
    IgnoreListSegmentActionRemove
};

@interface IgnoreListWindowController () <NSTableViewDelegate, NSTableViewDataSource, NSOpenSavePanelDelegate>

@property (weak) IBOutlet NSTableView *tableView;
@property (strong, nonatomic) NSMutableArray<NSURL *> *dataSource;
@property (weak) IBOutlet NSSegmentedControl *segmentedControl;

@end

@implementation IgnoreListWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.window.title = @"Lumen";
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.allowsMultipleSelection = YES;
    
    NSError *error;
    NSURL *appsDirURL = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationDirectory inDomains:NSLocalDomainMask].firstObject;
    NSArray *applicationURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:appsDirURL
                                                             includingPropertiesForKeys:@[NSURLLocalizedNameKey]
                                                                                options:(NSDirectoryEnumerationSkipsHiddenFiles|NSDirectoryEnumerationSkipsHiddenFiles)
                                                                                  error:&error];
    
    NSPredicate *appExtensionPredicate = [NSPredicate predicateWithFormat:@"pathExtension = 'app'"];
    
    // TODO: Read data source from NSUserDefaults instead.
    self.dataSource = [applicationURLs filteredArrayUsingPredicate:appExtensionPredicate].mutableCopy;
    
    [self.tableView reloadData];
    [self.segmentedControl setEnabled:NO forSegment:(NSInteger)IgnoreListSegmentActionRemove];
}

#pragma mark - IBActions

- (IBAction)tableAction:(id)sender {
    [self.segmentedControl setEnabled:YES forSegment:IgnoreListSegmentActionRemove];
}

- (IBAction)didClickSegmentButton:(id)sender {
    switch (self.segmentedControl.selectedSegment) {
        case IgnoreListSegmentActionAdd:
            [self showAddApplicationPanel];
            break;

        case IgnoreListSegmentActionRemove:
        default:
            [self removeSelectedApplication];
            break;
    }
}

#pragma mark - Private Methods

- (void)showAddApplicationPanel {
    // TODO: Can we restrict applications that are already included in the ignore list?
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.delegate = self;
    panel.prompt = @"Add";
    panel.allowedFileTypes = @[@"app"];
    panel.allowsMultipleSelection = YES;
    panel.directoryURL = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationDirectory inDomains:NSLocalDomainMask].firstObject;
    
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSArray *selectedURLs = panel.URLs;
            NSLog(@"Apps: %@", selectedURLs); // TODO: Remove NSLog later
            
            // TODO: Add the list / URLs to tableview.
            // TODO: Persist application URLs to NSUserDefaults.
        }
        
        // TODO: What if the result is not OK?
    }];
}

- (void)removeSelectedApplication {
    // TODO: What if there are multiple selected items?
    
    NSInteger selectedIndex = self.tableView.selectedRow;
    NSURL *applicationURL = self.dataSource[selectedIndex];
    
    [self removeApplicationWithURL:applicationURL];
}

- (void)removeApplicationWithURL:(NSURL *)url {
    // TODO: Remove application from dataSource.
}

#pragma mark - NSOpenSavePanelDelegate

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
    // Disable apps that have been added to the ignored list.
    // Note that this might have slight performance issue if the list is long; but on average case this should be good enough.
    if ([self.dataSource containsObject:url]) {
        return NO;
    }
    
    return YES;
}

#pragma mark - NSTableViewDataSource

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *cell = (NSTableCellView *)[self.tableView makeViewWithIdentifier:@"cell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] init];
        cell.identifier = @"cell";
    }
    
    NSURL *url = self.dataSource[row];
    NSImage *img = [[NSWorkspace sharedWorkspace] iconForFile:url.path];
    cell.imageView.image = img;
    cell.textField.stringValue = url.lastPathComponent;
    return cell;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.dataSource.count;
}

@end
