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
    
    NSMenuItem *clearItem = [fileMenu addItemWithTitle:@"Clear" action:@selector(newDocument:) keyEquivalent:@""];
    [clearItem setTarget:self];
    
    NSMenuItem *attachImageItem = [fileMenu addItemWithTitle:@"Attach Image…" action:@selector(attachImage:) keyEquivalent:@""];
    [attachImageItem setTarget:self];
    [attachImageItem setTag:100]; // Tag to identify this menu item
    
    NSMenuItem *generateItem = [fileMenu addItemWithTitle:@"Generate" action:@selector(generateImage:) keyEquivalent:@"g"];
    [generateItem setTarget:self];
    
    [fileMenu addItem:[NSMenuItem separatorItem]];
    
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

- (IBAction)attachImage:(id)sender {
    if (self.mainWindowController.attachedImage) {
        [self.mainWindowController removeImage:nil];
    } else {
        [self.mainWindowController attachImage:nil];
    }
}

- (IBAction)generateImage:(id)sender {
    [self.mainWindowController generateImage:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem tag] == 100) { // Attach Image menu item
        if (self.mainWindowController.attachedImage) {
            [menuItem setTitle:@"Remove Image"];
        } else {
            [menuItem setTitle:@"Attach Image…"];
        }
    }
    return YES;
}

@end