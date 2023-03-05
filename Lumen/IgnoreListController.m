// Copyright (c) Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#import "IgnoreListController.h"
#import "Constants.h"

static NSString * const IGNORE_LIST_BRIGHTNESS_KEY = @"ignored-item.brightness";
static float const DEFAULT_BRIGHTNESS_VALUE = -1;

@interface IgnoreListController ()
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSDictionary *> *ignoreList;
@property (strong, nonatomic) NSUserDefaults *userDefaults; // lazy var
@property (strong, nonatomic) NSNotificationCenter *notificationCenter; // lazy var
@end

@implementation IgnoreListController

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];

    // load the previously saved ignore list (if any).
    [self loadData];

    // subscribe to change events.
    [self.notificationCenter addObserver:self
                                selector:@selector(ignoreListChanged:)
                                    name:NOTIFICATION_IGNORE_LIST_CHANGED
                                  object:nil];

    return self;
}

- (void)dealloc {
    [self.notificationCenter removeObserver:self];
}

#pragma mark - Public Methods

- (NSArray<NSString *> *)ignoredURLStrings {
    return self.ignoreList.allKeys;
}

- (BOOL)containsURLString:(NSString *)URLString {
    if ([self.ignoreList objectForKey:URLString]) {
        return YES;
    }

    return NO;
}

- (void)ignoreURLStringsInArray:(NSArray<NSString *> *)URLStrings {
    BOOL changed = NO;
    for (NSString *URLString in URLStrings) {
        // skip if the URLString already exists.
        if ([self.ignoreList objectForKey:URLString]) {
            continue;
        }

        // add the URL string to ignore list with default brightness value.
        self.ignoreList[URLString] = @{IGNORE_LIST_BRIGHTNESS_KEY: @(DEFAULT_BRIGHTNESS_VALUE)};
        changed = YES;
    }

    if (changed) {
        [self synchronize];
    }
}

- (void)removeURLStringsInArray:(NSArray<NSString *> *)URLStrings {
    NSInteger keyCountBefore = self.ignoreList.count;
    [self.ignoreList removeObjectsForKeys:URLStrings];

    if (self.ignoreList.count < keyCountBefore) {
        [self synchronize];
    }
}

- (NSNumber *)preferredBrightnessForURLString:(NSString *)URLString {
    NSDictionary *preference = [self.ignoreList objectForKey:URLString];
    if (preference) {
        return preference[IGNORE_LIST_BRIGHTNESS_KEY];
    }

    return nil;
}

- (void)setPreferredBrightness:(NSNumber *)preferredBrightness forURLString:(NSString *)URLString {
    NSDictionary *preference = [self.ignoreList objectForKey:URLString];
    if (preference) {
        NSMutableDictionary *newPreference = preference.mutableCopy;
        newPreference[IGNORE_LIST_BRIGHTNESS_KEY] = preferredBrightness;
        self.ignoreList[URLString] = newPreference.copy;
        [self synchronize];
    }
}

#pragma mark - Private Methods

/**
 Loads ignore list data from persistence.
 */
- (void)loadData {
    NSDictionary *savedIgnoreList = [self.userDefaults dictionaryForKey:DEFAULTS_IGNORE_LIST];
    self.ignoreList = savedIgnoreList ? savedIgnoreList.mutableCopy : [NSMutableDictionary new];
}

- (void)validateAppURLExistence {
    NSArray<NSString *> *ignoredAppURLStrings = self.ignoreList.allKeys.copy;
    NSMutableArray<NSString *> *removeList = [NSMutableArray new];
    for (NSString *appURLString in ignoredAppURLStrings) {
        NSURL *appURL = [NSURL URLWithString:appURLString];
        if (![appURL checkResourceIsReachableAndReturnError:nil]) {
            [removeList addObject:appURLString];
        }
    }

    if (removeList.count > 0) {
        [self.ignoreList removeObjectsForKeys:removeList];
        [self synchronize];
    }
}

/**
 Persist any changes made in the ignore list.
 */
- (void)synchronize {
    [self.userDefaults setObject:self.ignoreList.copy forKey:DEFAULTS_IGNORE_LIST];
    [self.notificationCenter postNotificationName:NOTIFICATION_IGNORE_LIST_CHANGED object:self];
}

- (NSUserDefaults *)userDefaults {
    if (!_userDefaults) {
        _userDefaults = [NSUserDefaults standardUserDefaults];
    }

    return _userDefaults;
}

- (NSNotificationCenter *)notificationCenter {
    if (!_notificationCenter) {
        _notificationCenter = [NSNotificationCenter defaultCenter];
    }

    return _notificationCenter;
}

#pragma mark - Notification Responder

- (void)ignoreListChanged:(NSNotification *)notification {
    // no need to do anything if the sender is self.
    if ([notification.object isEqual:self]) {
        return;
    }

    [self loadData];
}

@end
