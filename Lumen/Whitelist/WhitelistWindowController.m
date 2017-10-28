//
//  WhitelistWindowController.m
//  Lumen
//
//  Created by David Christiandy on 28/10/17.
//  Copyright © 2017 Anish Athalye. All rights reserved.
//

#import "WhitelistWindowController.h"

typedef NS_ENUM(NSInteger, WhitelistSegmentAction) {
    WhitelistSegmentActionAdd,
    WhitelistSegmentActionRemove
};

@interface WhitelistWindowController () <NSTableViewDelegate, NSTableViewDataSource>

@property (weak) IBOutlet NSTableView *tableView;
@property (strong, nonatomic) NSMutableArray<NSURL *> *dataSource;
@property (weak) IBOutlet NSSegmentedControl *segmentedControl;

@end

@implementation WhitelistWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.window.title = @"Lumen";
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    NSError *error;
    NSURL *appsDirURL = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationDirectory inDomains:NSLocalDomainMask].firstObject;
    NSArray *applicationURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:appsDirURL
                                                             includingPropertiesForKeys:@[NSURLLocalizedNameKey]
                                                                                options:(NSDirectoryEnumerationSkipsHiddenFiles|NSDirectoryEnumerationSkipsHiddenFiles)
                                                                                  error:&error];
    
    NSPredicate *appExtensionPredicate = [NSPredicate predicateWithFormat:@"pathExtension = 'app'"];
    self.dataSource = [applicationURLs filteredArrayUsingPredicate:appExtensionPredicate].mutableCopy;
    
    [self.tableView reloadData];
    [self.segmentedControl setEnabled:NO forSegment:(NSInteger)WhitelistSegmentActionRemove];
}

#pragma mark - IBActions

- (IBAction)tableAction:(id)sender {
    [self.segmentedControl setEnabled:YES forSegment:WhitelistSegmentActionRemove];
}

- (IBAction)didClickSegmentButton:(id)sender {
    switch (self.segmentedControl.selectedSegment) {
        case WhitelistSegmentActionAdd:
            [self showAddApplicationPanel];
            break;

        case WhitelistSegmentActionRemove:
        default:
            [self removeApplication];
            break;
    }
}

#pragma mark - Private Methods

- (void)showAddApplicationPanel {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.prompt = @"Add";
    panel.allowedFileTypes = @[@"app"];
    panel.allowsMultipleSelection = YES;
    panel.directoryURL = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationDirectory inDomains:NSLocalDomainMask].firstObject;
    
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSArray *selectedURLs = panel.URLs;
            NSLog(@"Apps: %@", selectedURLs); // TODO: Remove NSLogs later
            
            // TODO: Add the list to tableview.
        }
    }];
}

- (void)removeApplication {
    NSInteger selectedIndex = self.tableView.selectedRow;
    NSURL *applicationURL = self.dataSource[selectedIndex];
    
    [self removeApplicationWithURL:applicationURL];
}

- (void)removeApplicationWithURL:(NSURL *)url {
    // TODO: Remove application from dataSource.
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
