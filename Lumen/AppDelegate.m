// Copyright (c) 2015-2017 Anish Athalye (me@anishathalye.com)
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
@property (strong, nonatomic) NSWindowController *windowController;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.statusItem setMenu:self.statusMenu];
    [self.statusItem setTitle:MENU_SYMBOL];
    [self.statusItem setHighlightMode:YES];
    
    // TODO: Testing purposes. Remove this later!
    [self menuActionWhitelist:self];

    self.brightnessController = [BrightnessController new];
    [self.brightnessController start];
    [self.toggle setTitle:STOP];

    // TODO: Re-enable this telemetry code for production
//    send_stats(TELEMETRY_RETRIES);
//    self.statsTimer = [NSTimer scheduledTimerWithTimeInterval:TELEMETRY_INTERVAL
//                                                  target:self
//                                                selector:@selector(statsTick:)
//                                                userInfo:nil
//                                                 repeats:YES];
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

- (IBAction)menuActionWhitelist:(id)sender {
    IgnoreListWindowController *whitelistWC = [[IgnoreListWindowController alloc] initWithWindowNibName:@"IgnoreListWindowController"];
    [self showWindowController:whitelistWC];
}

#pragma mark - Helper methods

- (void)showWindowController:(nonnull NSWindowController *)windowController {
    // TODO: When the menu is clicked from the taskbar, somehow woindow doesn't show up in front.
    // TODO: Add a check to prevent windows from showing multiple times – Just focus on the already opened window.
    
    self.windowController = windowController;
    [self.windowController showWindow:self];
    [self.windowController.window makeKeyAndOrderFront:self];
}


@end
