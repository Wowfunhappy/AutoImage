#import "AIAppDelegate.h"
#import "AIMainWindowController.h"
#import "AIPreferencesWindowController.h"

@implementation AIAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self setupMenuBar];
    
    self.mainWindowController = [[AIMainWindowController alloc] init];
    [self.mainWindowController showWindow:nil];
    
    // Make the app active and bring window to front
    [NSApp activateIgnoringOtherApps:YES];
    [[self.mainWindowController window] makeKeyAndOrderFront:nil];
}

- (void)setupMenuBar {
    NSMenu *mainMenu = [[NSMenu alloc] init];
    [NSApp setMainMenu:mainMenu];
    
    // AutoImage menu
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [appMenuItem setTitle:@"AutoImage"];
    [mainMenu addItem:appMenuItem];
    
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"AutoImage"];
    [appMenuItem setSubmenu:appMenu];
    
    [appMenu addItemWithTitle:@"About AutoImage" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *preferencesItem = [appMenu addItemWithTitle:@"Preferences…" action:@selector(showPreferences:) keyEquivalent:@","];
    [preferencesItem setTarget:self];
    
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit AutoImage" action:@selector(terminate:) keyEquivalent:@"q"];
    
    // File menu
    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
    [fileMenuItem setTitle:@"File"];
    [mainMenu addItem:fileMenuItem];
    
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenuItem setSubmenu:fileMenu];
    
    NSMenuItem *newItem = [fileMenu addItemWithTitle:@"New" action:@selector(newDocument:) keyEquivalent:@"n"];
    [newItem setTarget:self];
    
    [fileMenu addItemWithTitle:@"Save" action:@selector(saveDocument:) keyEquivalent:@"s"];
    [fileMenu addItemWithTitle:@"Close" action:@selector(performClose:) keyEquivalent:@"w"];
    
    // Edit menu
    NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
    [editMenuItem setTitle:@"Edit"];
    [mainMenu addItem:editMenuItem];
    
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenuItem setSubmenu:editMenu];
    
    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    
    // Window menu
    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] init];
    [windowMenuItem setTitle:@"Window"];
    [mainMenu addItem:windowMenuItem];
    
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [windowMenuItem setSubmenu:windowMenu];
    
    [windowMenu addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:@"Bring All to Front" action:@selector(arrangeInFront:) keyEquivalent:@""];
    
    [NSApp setWindowsMenu:windowMenu];
    
    // Help menu
    NSMenuItem *helpMenuItem = [[NSMenuItem alloc] init];
    [helpMenuItem setTitle:@"Help"];
    [mainMenu addItem:helpMenuItem];
    
    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
    [helpMenuItem setSubmenu:helpMenu];
    
    [helpMenu addItemWithTitle:@"AutoImage Help" action:@selector(showHelp:) keyEquivalent:@"?"];
}

- (IBAction)showPreferences:(id)sender {
    if (!self.preferencesWindowController) {
        self.preferencesWindowController = [[AIPreferencesWindowController alloc] init];
    }
    [self.preferencesWindowController showWindow:nil];
}

- (IBAction)newDocument:(id)sender {
    [self.mainWindowController clearDocument];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end