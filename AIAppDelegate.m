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
    
    // Auto Image menu
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [appMenuItem setTitle:@"Auto Image"];
    [mainMenu addItem:appMenuItem];
    
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Auto Image"];
    [appMenuItem setSubmenu:appMenu];
    
    [appMenu addItemWithTitle:@"About Auto Image" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *preferencesItem = [appMenu addItemWithTitle:@"Preferences…" action:@selector(showPreferences:) keyEquivalent:@","];
    [preferencesItem setTarget:self];
    
    [appMenu addItem:[NSMenuItem separatorItem]];
    
    // Services submenu
    NSMenuItem *servicesMenuItem = [[NSMenuItem alloc] init];
    [servicesMenuItem setTitle:@"Services"];
    [appMenu addItem:servicesMenuItem];
    
    NSMenu *servicesMenu = [[NSMenu alloc] initWithTitle:@"Services"];
    [servicesMenuItem setSubmenu:servicesMenu];
    [NSApp setServicesMenu:servicesMenu];
    
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Hide Auto Image" action:@selector(hide:) keyEquivalent:@"h"];
    [appMenu addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"H"];
    [appMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit Auto Image" action:@selector(terminate:) keyEquivalent:@"q"];
    
    // File menu
    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
    [fileMenuItem setTitle:@"File"];
    [mainMenu addItem:fileMenuItem];
    
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenuItem setSubmenu:fileMenu];
    
    NSMenuItem *attachImageItem = [fileMenu addItemWithTitle:@"Add Reference Image…" action:@selector(attachImage:) keyEquivalent:@""];
    [attachImageItem setTarget:self];
    [attachImageItem setTag:100]; // Tag to identify this menu item
    
    NSMenuItem *clearItem = [fileMenu addItemWithTitle:@"Clear All" action:@selector(newDocument:) keyEquivalent:@""];
    [clearItem setTarget:self];
    
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
    [editMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:@""];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    
    [editMenu addItem:[NSMenuItem separatorItem]];
    
    // Find submenu
    NSMenuItem *findMenuItem = [[NSMenuItem alloc] init];
    [findMenuItem setTitle:@"Find"];
    [editMenu addItem:findMenuItem];
    
    NSMenu *findMenu = [[NSMenu alloc] initWithTitle:@"Find"];
    [findMenuItem setSubmenu:findMenu];
    
    [findMenu addItemWithTitle:@"Find…" action:@selector(performFindPanelAction:) keyEquivalent:@"f"];
    [findMenu addItemWithTitle:@"Find Next" action:@selector(performFindPanelAction:) keyEquivalent:@"g"];
    [findMenu addItemWithTitle:@"Find Previous" action:@selector(performFindPanelAction:) keyEquivalent:@"G"];
    [findMenu addItemWithTitle:@"Use Selection for Find" action:@selector(performFindPanelAction:) keyEquivalent:@"e"];
    
    // Spelling and Grammar submenu
    NSMenuItem *spellingMenuItem = [[NSMenuItem alloc] init];
    [spellingMenuItem setTitle:@"Spelling and Grammar"];
    [editMenu addItem:spellingMenuItem];
    
    NSMenu *spellingMenu = [[NSMenu alloc] initWithTitle:@"Spelling and Grammar"];
    [spellingMenuItem setSubmenu:spellingMenu];
    
    [spellingMenu addItemWithTitle:@"Show Spelling and Grammar" action:@selector(showGuessPanel:) keyEquivalent:@":"];
    [spellingMenu addItemWithTitle:@"Check Document Now" action:@selector(checkSpelling:) keyEquivalent:@";"];
    
    // Substitutions submenu
    NSMenuItem *substitutionsMenuItem = [[NSMenuItem alloc] init];
    [substitutionsMenuItem setTitle:@"Substitutions"];
    [editMenu addItem:substitutionsMenuItem];
    
    NSMenu *substitutionsMenu = [[NSMenu alloc] initWithTitle:@"Substitutions"];
    [substitutionsMenuItem setSubmenu:substitutionsMenu];
    
    [substitutionsMenu addItemWithTitle:@"Show Substitutions" action:@selector(orderFrontSubstitutionsPanel:) keyEquivalent:@""];
    
    [editMenu addItem:[NSMenuItem separatorItem]];
    
    [editMenu addItemWithTitle:@"Start Dictation…" action:@selector(startDictation:) keyEquivalent:@""];
    [editMenu addItemWithTitle:@"Emoji & Symbols" action:@selector(orderFrontCharacterPalette:) keyEquivalent:@" "];
    
    // View menu
    NSMenuItem *viewMenuItem = [[NSMenuItem alloc] init];
    [viewMenuItem setTitle:@"View"];
    [mainMenu addItem:viewMenuItem];
    
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    [viewMenuItem setSubmenu:viewMenu];
    
    NSMenuItem *toggleDrawerItem = [viewMenu addItemWithTitle:@"Show Side Drawer" action:@selector(toggleOptionsDrawer:) keyEquivalent:@"d"];
    [toggleDrawerItem setTag:101]; // Tag for drawer toggle
    
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
    
    [helpMenu addItemWithTitle:@"Auto Image Help" action:@selector(showHelp:) keyEquivalent:@"?"];
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

- (IBAction)toggleOptionsDrawer:(id)sender {
    [self.mainWindowController toggleOptionsDrawer:sender];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem tag] == 100) { // Attach Image menu item
        if (self.mainWindowController.attachedImage) {
            [menuItem setTitle:@"Remove Reference Image"];
        } else {
            [menuItem setTitle:@"Add Reference Image…"];
        }
    } else if ([menuItem tag] == 101) { // Toggle drawer menu item
        // Menu title is now updated directly by drawer notifications
    } else if ([menuItem action] == @selector(performClose:)) {
        // Disable Close menu item during image generation
        return ![self.mainWindowController isGeneratingImage];
    }
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    if ([self.mainWindowController isGeneratingImage]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Image Generation in Progress"];
        [alert setInformativeText:@"An image is currently being created. Do you want to cancel image creation and quit Auto Image?"];
        [alert addButtonWithTitle:@"Cancel and Quit"];
        [alert addButtonWithTitle:@"Continue Generating"];
        
        NSModalResponse response = [alert runModal];
        if (response == NSAlertFirstButtonReturn) {
            // User chose to quit - cancel generation first
            return NSTerminateNow;
        } else {
            // User chose to continue
            return NSTerminateCancel;
        }
    }
    return NSTerminateNow;
}

@end