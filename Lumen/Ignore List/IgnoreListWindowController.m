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
@property (strong, nonatomic) NSMutableArray<NSString *> *dataSource;
@property (weak) IBOutlet NSSegmentedControl *segmentedControl;
@property (weak) IBOutlet NSView *emptyStateView;
@property (strong, nonatomic) NSUserDefaults *userDefaults; // lazy var

@end

@implementation IgnoreListWindowController

- (instancetype)init {
    return [self initWithWindowNibName:self.className];
}

- (void)windowDidLoad {
    [super windowDidLoad];

    self.window.title = @"Lumen";
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.allowsMultipleSelection = YES;
    
    // fetch persisted app URLs from the user defaults, and validate them to remove renamed/uninstalled apps.
    NSArray<NSString *> *persistedAppURLStrings = [self.userDefaults arrayForKey:DEFAULTS_IGNORE_LIST] ?: @[];
    self.dataSource = [self getValidatedAppURLStrings:persistedAppURLStrings].mutableCopy;
    
    [self reloadTable];
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

// remove apps that have been renamed and/or uninstalled based on the given app URL list.
- (NSArray<NSString *> *)getValidatedAppURLStrings:(NSArray<NSString *> *)appURLStrings {
    NSMutableArray<NSString *> *validatedURLStrings = appURLStrings.mutableCopy;

    for (NSString *appURLString in appURLStrings) {
        NSURL *appURL = [NSURL URLWithString:appURLString];
        if (![appURL checkResourceIsReachableAndReturnError:nil]) {
            [validatedURLStrings removeObject:appURLString];
        }
    }
    
    return validatedURLStrings;
}

- (void)showAddApplicationPanel {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.delegate = self;
    panel.prompt = @"Add to Ignore List";
    panel.allowedFileTypes = @[@"app"];
    panel.allowsMultipleSelection = YES;
    panel.directoryURL = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationDirectory inDomains:NSLocalDomainMask].firstObject;
    
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            __block NSArray *selectedURLs = panel.URLs;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addIgnoredApplications:selectedURLs];
                [self reloadTable];
            });
        }
    }];
}

- (void)removeSelectedApplication {
    // Multiple selection is enabled, so the data needs to be removed
    NSIndexSet *selectedIndexes = self.tableView.selectedRowIndexes;
    if (selectedIndexes.count <= 0) {
        return;
    }
    
    // reset selections
    [self.tableView deselectAll:nil];
    
    [self removeApplicationsAtIndexes:selectedIndexes];
    [self reloadTable];
}

- (void)addIgnoredApplications:(nonnull NSArray<NSURL *> *)appURLs {
    NSParameterAssert(appURLs);
    
    // sanitize application list
    NSMutableArray<NSString *> *sanitizedAppURLStrings = [NSMutableArray new];
    for (NSURL *appURL in appURLs) {
        NSString *appURLString = appURL.absoluteString.stringByStandardizingPath;
        if (![self.dataSource containsObject:appURLString]) {
            [sanitizedAppURLStrings addObject:appURLString];
        }
    }
    
    if (sanitizedAppURLStrings.count == 0) {
        return;
    }
    
    [self.dataSource addObjectsFromArray:sanitizedAppURLStrings];
    [self persistIgnoreListState];
}

- (void)removeApplicationsAtIndexes:(nonnull NSIndexSet *)indexSet {
    NSParameterAssert(indexSet);
    
    // validate index validity.
    // index sets are sorted ranges, so the last index of the indexSet has to be lower than the number of elements in dataSource.
    if (indexSet.lastIndex >= self.dataSource.count) {
        return;
    }
    
    [self.dataSource removeObjectsAtIndexes:indexSet];
    [self persistIgnoreListState];
}

- (void)persistIgnoreListState {
    // persist the latest changes to user defaults.
    NSArray<NSString *> *dataSourceCopy = self.dataSource.copy;
    [self.userDefaults setObject:dataSourceCopy forKey:DEFAULTS_IGNORE_LIST];
    [self.userDefaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_IGNORE_LIST_CHANGED
                                                        object:self
                                                      userInfo:@{ @"updatedList": dataSourceCopy }];
}

- (void)reloadTable {
    self.emptyStateView.hidden = (self.dataSource.count > 0);
    [self.window layoutIfNeeded];
    
    [self.tableView reloadData];
}

#pragma mark - NSOpenSavePanelDelegate

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
    // Disable apps that have been added to the ignored list.
    // Note that this might have slight performance issue if the list is long; but on average case this should be good enough.
    if ([self.dataSource containsObject:url.absoluteString.stringByStandardizingPath]) {
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
    
    NSURL *url = [NSURL URLWithString:self.dataSource[row]];
    NSImage *img = [[NSWorkspace sharedWorkspace] iconForFile:url.path];
    cell.imageView.image = img;
    cell.textField.stringValue = url.lastPathComponent;
    return cell;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.dataSource.count;
}

@end
