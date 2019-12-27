// Copyright (c) 2015-2019 Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#import "IgnoreListWindowController.h"
#import "IgnoreListController.h"
#import "NSArray+Functional.h"

typedef NS_ENUM(NSInteger, IgnoreListSegmentAction) {
    IgnoreListSegmentActionAdd,
    IgnoreListSegmentActionRemove
};

@interface IgnoreListWindowController () <NSTableViewDelegate, NSTableViewDataSource, NSOpenSavePanelDelegate>

@property (weak) IBOutlet NSTableView *tableView;
@property (strong, nonatomic) NSArray<NSString *> *dataSource;
@property (strong, nonatomic) IgnoreListController *ignoreList;
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
    self.ignoreList = [[IgnoreListController alloc] init];
    self.dataSource = [self.ignoreList ignoredURLStrings];

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
    [self.segmentedControl setSelected:NO forSegment:self.segmentedControl.selectedSegment];
}

#pragma mark - Private Methods

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
    NSMutableArray<NSString *> *mappedURLStrings = [NSMutableArray new];
    for (NSURL *appURL in appURLs) {
        NSString *appURLString = appURL.absoluteString.stringByStandardizingPath;
        [mappedURLStrings addObject:appURLString];
    }

    [self.ignoreList ignoreURLStringsInArray:mappedURLStrings];
    [self reloadDataSource];
}

- (void)removeApplicationsAtIndexes:(nonnull NSIndexSet *)indexSet {
    NSParameterAssert(indexSet);

    // validate index validity.
    // index sets are sorted ranges, so the last index of the indexSet has to be lower than the number of elements in dataSource.
    if (indexSet.lastIndex >= self.dataSource.count) {
        return;
    }

    // get objects from indexSet
    NSArray<NSString *> *objectsToRemove = [self.dataSource objectsAtIndexes:indexSet];
    if (objectsToRemove.count > 0) {
        [self.ignoreList removeURLStringsInArray:objectsToRemove];
        [self reloadDataSource];
    }
}

- (void)reloadDataSource {
    self.dataSource = [self.ignoreList ignoredURLStrings].mutableCopy;
    [self reloadTable];
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
