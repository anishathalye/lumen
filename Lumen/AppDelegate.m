// Copyright (c) 2015-2019 Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#import "AppDelegate.h"
#import "Constants.h"
#import "BrightnessController.h"
#import "stats.h"
#import "IgnoreListWindowController.h"

@interface AppDelegate ()

@property (strong, nonatomic) IBOutlet NSMenu *statusMenu;
@property (strong, nonatomic) IBOutlet NSMenuItem *toggle;
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) BrightnessController *brightnessController;
@property (nonatomic, strong) NSTimer *statsTimer;
@property (strong, nonatomic) IgnoreListWindowController *ignoreListWC;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.statusItem setMenu:self.statusMenu];
    [self.statusItem setTitle:MENU_SYMBOL];
    [self.statusItem setHighlightMode:YES];

    self.brightnessController = [BrightnessController new];
    [self.brightnessController start];
    [self.toggle setTitle:STOP];

    send_stats(TELEMETRY_RETRIES);
    self.statsTimer = [NSTimer scheduledTimerWithTimeInterval:TELEMETRY_INTERVAL
                                                  target:self
                                                selector:@selector(statsTick:)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)statsTick:(NSTimer *)timer {
    send_stats(TELEMETRY_RETRIES);
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // do not need to do anything
}

- (IBAction)menuActionQuit:(id)sender {
    [NSApp terminate:self];
}

- (IBAction)menuActionToggle:(id)sender {
    if (self.brightnessController.isRunning) {
        [self.brightnessController stop];
        [self.toggle setTitle:START];
    } else {
        [self.brightnessController start];
        [self.toggle setTitle:STOP];
    }
}

- (IBAction)menuActionIgnoreList:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];

    if (self.ignoreListWC) {
        // refocus if the ignore list window is still around.
        [self.ignoreListWC.window orderFrontRegardless];
    } else {
        self.ignoreListWC = [[IgnoreListWindowController alloc] init];
        [self.ignoreListWC showWindow:nil];
        [self.ignoreListWC.window center];
    }
}

@end
