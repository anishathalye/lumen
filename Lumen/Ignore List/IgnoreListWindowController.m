//
//  IgnoreListWindowController.m
//  Lumen
//
//  Created by David Christiandy on 28/10/17.
//  Copyright © 2017 Anish Athalye. All rights reserved.
//

#import "IgnoreListWindowController.h"
#import "NSArray+Functional.h"
#import "Constants.h"

typedef NS_ENUM(NSInteger, IgnoreListSegmentAction) {
    IgnoreListSegmentActionAdd,
    IgnoreListSegmentActionRemove
};

@interface IgnoreListWindowController () <NSTableViewDelegate, NSTableViewDataSource, NSOpenSavePanelDelegate>

@property (weak) IBOutlet NSTableView *tableView;
@property (strong, nonatomic) NSMutableArray<NSURL *> *dataSource;
@property (weak) IBOutlet NSSegmentedControl *segmentedControl;
@property (strong, nonatomic) NSUserDefaults *userDefaults; // lazy var

@end

@implementation IgnoreListWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.window.title = @"Lumen";
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.allowsMultipleSelection = YES;
    
    // TODO: Read data source from NSUserDefaults instead.
    
    NSError *error;
    NSURL *appsDirURL = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationDirectory inDomains:NSLocalDomainMask].firstObject;
    NSArray *applicationURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:appsDirURL
                                                             includingPropertiesForKeys:@[NSURLLocalizedNameKey]
                                                                                options:(NSDirectoryEnumerationSkipsHiddenFiles|NSDirectoryEnumerationSkipsHiddenFiles)
                                                                                  error:&error];
    
    NSPredicate *appExtensionPredicate = [NSPredicate predicateWithFormat:@"pathExtension = 'app'"];
    
    self.dataSource = [applicationURLs filteredArrayUsingPredicate:appExtensionPredicate].mutableCopy;
    // TODO: Validate whether the app really does exist.
    
    [self.tableView reloadData];
    [self.segmentedControl setEnabled:NO forSegment:(NSInteger)IgnoreListSegmentActionRemove];
}

#pragma mark - Lazy Var

- (NSUserDefaults *)userDefaults {
    if (!_userDefaults) {
        _userDefaults = [NSUserDefaults standardUserDefaults];
    }
    
    return _userDefaults;
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
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.delegate = self;
    panel.prompt = @"Add";
    panel.allowedFileTypes = @[@"app"];
    panel.allowsMultipleSelection = YES;
    panel.directoryURL = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationDirectory inDomains:NSLocalDomainMask].firstObject;
    
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            __block NSArray *selectedURLs = panel.URLs;
            NSLog(@"Apps: %@", selectedURLs); // TODO: Remove NSLog later
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addIgnoredApplications:selectedURLs];
                [self.tableView reloadData];
            });
        }
        
        // TODO: What if the result is not OK?
    }];
}

- (void)removeSelectedApplication {
    // Multiple selection is enabled, so the data needs to be removed
    NSIndexSet *selectedIndexes = self.tableView.selectedRowIndexes;
    if (selectedIndexes.count <= 0) {
        // TODO: Probably show an alert that items must be selected first?
        return;
    }
    
    // reset selections
    [self.tableView deselectAll:nil];
    
    [self removeApplicationsAtIndexes:selectedIndexes];
    [self.tableView reloadData];
}

- (void)addIgnoredApplications:(nonnull NSArray<NSURL *> *)appURLs {
    NSParameterAssert(appURLs);
    
    // sanitize application list
    NSMutableArray *sanitizedAppURLs = appURLs.copy;
    for (NSURL *appURL in appURLs) {
        if ([self.dataSource containsObject:appURL]) {
            [sanitizedAppURLs removeObject:appURL];
        }
    }
    
    if (sanitizedAppURLs.count == 0) {
        return;
    }
    
    [self.dataSource addObjectsFromArray:sanitizedAppURLs];
    [self persistIgnoreListState];
}

- (void)removeApplicationsAtIndexes:(nonnull NSIndexSet *)indexSet {
    NSParameterAssert(indexSet);
    
    // validate index validity.
    // index sets are sorted ranges, so the last index of the indexSet has to be lower than the number of elements in dataSource.
    if (self.dataSource.count > indexSet.lastIndex) {
        return;
    }
    
    [self.dataSource removeObjectsAtIndexes:indexSet];
    [self persistIgnoreListState];
}

- (void)persistIgnoreListState {
    // TODO: Uncomment this part.
    // persist the latest changes to user defaults.
    //    [self.userDefaults setObject:self.dataSource.copy forKey:IGNORE_LIST_USER_DEFAULTS_KEY];
    //    [self.userDefaults synchronize];
}

#pragma mark - NSOpenSavePanelDelegate

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
    // TODO: Uncomment this part.
    // Disable apps that have been added to the ignored list.
    // Note that this might have slight performance issue if the list is long; but on average case this should be good enough.
//    if ([self.dataSource containsObject:url]) {
//        return NO;
//    }
    
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
