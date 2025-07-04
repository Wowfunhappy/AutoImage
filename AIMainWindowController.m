#import "AIMainWindowController.h"
#import "AIImageGenerationManager.h"

static NSString *const kAILastPrompt = @"AILastPrompt";
static NSString *const kAILastOutputSize = @"AILastOutputSize";
static NSString *const kAILastQuality = @"AILastQuality";
static NSString *const kAILastAttachedImagePath = @"AILastAttachedImagePath";

@interface AIDragDropView : NSView
@end

@implementation AIDragDropView

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    // Open the drawer when dragging over main window
    AIMainWindowController *controller = (AIMainWindowController *)[self window].windowController;
    if ([controller.optionsDrawer state] != NSDrawerOpenState && [controller.optionsDrawer state] != NSDrawerOpeningState) {
        [controller.optionsDrawer open];
    }
    return NSDragOperationNone; // Main window doesn't accept drops
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    return NO; // Main window doesn't accept drops
}

@end

@interface AIDragDropImageView : NSImageView
@end

@implementation AIDragDropImageView

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    if ([pboard availableTypeFromArray:@[NSFilenamesPboardType]]) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        for (NSString *file in files) {
            NSString *extension = [[file pathExtension] lowercaseString];
            if ([@[@"jpg", @"jpeg", @"png", @"gif", @"bmp"] containsObject:extension]) {
                return NSDragOperationCopy;
            }
        }
    } else if ([pboard availableTypeFromArray:@[NSTIFFPboardType, NSPasteboardTypePNG]]) {
        return NSDragOperationCopy;
    }
    
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    // Get the main window controller from the app delegate
    id appDelegate = [NSApp delegate];
    AIMainWindowController *controller = [appDelegate valueForKey:@"mainWindowController"];
    
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    if ([pboard availableTypeFromArray:@[NSFilenamesPboardType]]) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        for (NSString *file in files) {
            NSString *extension = [[file pathExtension] lowercaseString];
            if ([@[@"jpg", @"jpeg", @"png", @"gif", @"bmp"] containsObject:extension]) {
                NSImage *image = [[NSImage alloc] initWithContentsOfFile:file];
                if (image) {
                    [controller attachImageFromSource:image];
                    return YES;
                }
            }
        }
    } else if ([pboard availableTypeFromArray:@[NSTIFFPboardType]]) {
        NSData *imageData = [pboard dataForType:NSTIFFPboardType];
        NSImage *image = [[NSImage alloc] initWithData:imageData];
        if (image) {
            [controller attachImageFromSource:image];
            return YES;
        }
    } else if ([pboard availableTypeFromArray:@[NSPasteboardTypePNG]]) {
        NSData *imageData = [pboard dataForType:NSPasteboardTypePNG];
        NSImage *image = [[NSImage alloc] initWithData:imageData];
        if (image) {
            [controller attachImageFromSource:image];
            return YES;
        }
    }
    
    return NO;
}

@end

@interface AIFlippedView : NSView
@end

@implementation AIFlippedView
- (BOOL)isFlipped {
    return YES;
}
@end

@interface AIMainWindowController () <NSWindowDelegate, NSTextViewDelegate, NSUserNotificationCenterDelegate>
@property (nonatomic, strong) AIImageGenerationManager *imageGenerator;
@property (nonatomic, strong) NSImage *pendingGeneratedImage;
@property (nonatomic, strong) NSError *pendingGenerationError;
@property (nonatomic) BOOL isGenerating;
@end

@implementation AIMainWindowController

- (id)init {
    NSRect windowRect = NSMakeRect(0, 0, 430, 400);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowRect
                                                   styleMask:(NSTitledWindowMask |
                                                            NSClosableWindowMask |
                                                            NSMiniaturizableWindowMask |
                                                            NSResizableWindowMask)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    self = [super initWithWindow:window];
    if (self) {
        [window setTitle:@"Auto Image"];
        [window center];
        [window setDelegate:self];
        [window setContentMaxSize:NSMakeSize(800, 800)];
        
        // Set custom content view for drag and drop
        AIDragDropView *contentView = [[AIDragDropView alloc] initWithFrame:[[window contentView] frame]];
        [contentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [window setContentView:contentView];
        
        [self setupUI];
        [self setupDrawer];
        
        self.imageGenerator = [[AIImageGenerationManager alloc] init];
        
        // Register for drag and drop (only to detect drag enter for drawer opening)
        [contentView registerForDraggedTypes:@[NSFilenamesPboardType, NSTIFFPboardType, NSPasteboardTypePNG]];
        
        // Register for app termination notification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(saveCurrentState)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:nil];
        
        // Set up notification center delegate
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
        
        // Drawer notifications will be set up after drawer is created
    }
    return self;
}

- (void)setupUI {
    NSView *contentView = [[self window] contentView];
    
    CGFloat margin = 20;
    CGFloat windowWidth = NSWidth([contentView bounds]);
    
    // Start from the bottom and work up
    CGFloat currentY = margin;
    
    // Generate button (bottom)
    self.generateButton = [[NSButton alloc] initWithFrame:NSMakeRect(margin, currentY, 120, 32)];
    [self.generateButton setTitle:@"Create Image"];
    [self.generateButton setBezelStyle:NSRoundedBezelStyle];
    [self.generateButton setTarget:self];
    [self.generateButton setAction:@selector(generateImage:)];
    [self.generateButton setKeyEquivalent:@"\r"];
    [contentView addSubview:self.generateButton];
    
    // Progress indicator (next to generate button)
    self.progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(margin + 140, currentY + 7, windowWidth - (margin + 140) - margin, 20)];
    [self.progressIndicator setStyle:NSProgressIndicatorBarStyle];
    [self.progressIndicator setIndeterminate:YES];
    [self.progressIndicator setHidden:YES];
    [self.progressIndicator setAutoresizingMask:NSViewWidthSizable];
    [contentView addSubview:self.progressIndicator];
    
    // Drawer toggle button (bottom right corner)
    self.drawerToggleButton = [[NSButton alloc] initWithFrame:NSMakeRect(windowWidth - margin - 38, currentY, 38, 32)];
    [self.drawerToggleButton setTitle:@""];
    [self.drawerToggleButton setBezelStyle:NSRoundedBezelStyle];
    [self.drawerToggleButton setImage:[NSImage imageNamed:NSImageNameActionTemplate]];
    [self.drawerToggleButton setTarget:self];
    [self.drawerToggleButton setAction:@selector(toggleOptionsDrawer:)];
    [self.drawerToggleButton setAutoresizingMask:NSViewMinXMargin];
    [self.drawerToggleButton setToolTip:@"Show Side Drawer"];
    [contentView addSubview:self.drawerToggleButton];
    
    // Prompt text view with scroll view (fill remaining space)
    currentY += 50;
    CGFloat textViewHeight = NSHeight([contentView bounds]) - currentY - margin;
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(margin, 
                                                                             currentY, 
                                                                             windowWidth - 2 * margin, 
                                                                             textViewHeight)];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    self.promptTextView = [[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]];
    [self.promptTextView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.promptTextView setRichText:NO];
    [self.promptTextView setFont:[NSFont systemFontOfSize:13]];
    [self.promptTextView setDelegate:self];
    [self.promptTextView setAllowsUndo:YES];
    [self.promptTextView setToolTip:@"Describe the image you want to be created"];
    
    [scrollView setDocumentView:self.promptTextView];
    [contentView addSubview:scrollView];
    
    // Load saved prompt
    NSString *savedPrompt = [[NSUserDefaults standardUserDefaults] stringForKey:kAILastPrompt];
    if (savedPrompt) {
        [self.promptTextView setString:savedPrompt];
    }
    
    // Validate generate button state based on initial prompt
    [self validateGenerateButton];
}

- (void)setupDrawer {
    // Create drawer
    self.optionsDrawer = [[NSDrawer alloc] initWithContentSize:NSMakeSize(250, 400) preferredEdge:NSMaxXEdge];
    [self.optionsDrawer setParentWindow:[self window]];
    [self.optionsDrawer setMinContentSize:NSMakeSize(250, 110)];
    [self.optionsDrawer setMaxContentSize:NSMakeSize(250, 800)];
    
    // Create drawer content view with flipped coordinates
    AIFlippedView *drawerContent = [[AIFlippedView alloc] initWithFrame:NSMakeRect(0, 0, 250, 400)];
    [self.optionsDrawer setContentView:drawerContent];
    
    CGFloat margin = 20;
    CGFloat currentY = 20; // Start from top with flipped coordinates
    CGFloat labelWidth = 210;
    
    // Image attachment section
    NSTextField *imageLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, currentY, labelWidth, 20)];
    [imageLabel setStringValue:@"Reference Image"];
    [imageLabel setBordered:NO];
    [imageLabel setEditable:NO];
    [imageLabel setBackgroundColor:[NSColor clearColor]];
    [imageLabel setFont:[NSFont boldSystemFontOfSize:13]];
    [drawerContent addSubview:imageLabel];
    
    currentY += 30;
    
    self.attachedImageView = [[AIDragDropImageView alloc] initWithFrame:NSMakeRect(margin, currentY, 210, 120)];
    [self.attachedImageView setImageFrameStyle:NSImageFrameGrayBezel];
    [self.attachedImageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [self.attachedImageView registerForDraggedTypes:@[NSFilenamesPboardType, NSTIFFPboardType, NSPasteboardTypePNG]];
    [drawerContent addSubview:self.attachedImageView];
    
    currentY += 130;
    
    self.attachImageButton = [[NSButton alloc] initWithFrame:NSMakeRect(margin, currentY, 120, 25)];
    [self.attachImageButton setTitle:@"Choose..."];
    [self.attachImageButton setBezelStyle:NSRoundedBezelStyle];
    [self.attachImageButton setTarget:self];
    [self.attachImageButton setAction:@selector(toggleImageAttachment:)];
    [drawerContent addSubview:self.attachImageButton];
    
    currentY += 60;
    
    // Output settings section
    NSTextField *outputLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, currentY, labelWidth, 20)];
    [outputLabel setStringValue:@"Output Settings"];
    [outputLabel setBordered:NO];
    [outputLabel setEditable:NO];
    [outputLabel setBackgroundColor:[NSColor clearColor]];
    [outputLabel setFont:[NSFont boldSystemFontOfSize:13]];
    [drawerContent addSubview:outputLabel];
    
    currentY += 32;
    
    // Orientation selection
    NSTextField *sizeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, currentY, 75, 20)];
    [sizeLabel setStringValue:@"Orientation:"];
    [sizeLabel setBordered:NO];
    [sizeLabel setEditable:NO];
    [sizeLabel setBackgroundColor:[NSColor clearColor]];
    [drawerContent addSubview:sizeLabel];
    
    self.sizePopUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(margin + 85, currentY - 3, 115, 26)];
    [self.sizePopUpButton addItemsWithTitles:@[@"Square", @"Portrait", @"Landscape"]];
    
    // Set tags to map to actual sizes
    [[self.sizePopUpButton itemAtIndex:0] setTag:1024]; // Square = 1024x1024
    [[self.sizePopUpButton itemAtIndex:1] setTag:1536]; // Portrait = 1024x1536
    [[self.sizePopUpButton itemAtIndex:2] setTag:1024]; // Landscape = 1536x1024
    
    // Set initial tooltip
    [self.sizePopUpButton setToolTip:@"1024x1024"];
    
    // Update tooltip when selection changes
    [self.sizePopUpButton setTarget:self];
    [self.sizePopUpButton setAction:@selector(sizePopUpChanged:)];
    
    // Load saved size or default to Portrait
    NSString *savedSize = [[NSUserDefaults standardUserDefaults] stringForKey:kAILastOutputSize];
    if (savedSize && [[self.sizePopUpButton itemTitles] containsObject:savedSize]) {
        [self.sizePopUpButton selectItemWithTitle:savedSize];
    } else {
        [self.sizePopUpButton selectItemWithTitle:@"Portrait"];
    }
    
    // Update tooltip to match current selection
    [self sizePopUpChanged:nil];
    
    [drawerContent addSubview:self.sizePopUpButton];
    
    currentY += 35;
    
    // Quality selection
    NSTextField *qualityLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, currentY, 50, 20)];
    [qualityLabel setStringValue:@"Quality:"];
    [qualityLabel setBordered:NO];
    [qualityLabel setEditable:NO];
    [qualityLabel setBackgroundColor:[NSColor clearColor]];
    [drawerContent addSubview:qualityLabel];
    
    self.qualityPopUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(margin + 85, currentY - 3, 115, 26)];
    [self.qualityPopUpButton addItemsWithTitles:@[@"Low", @"Medium", @"High"]];
    [self.qualityPopUpButton setToolTip:@"High quality looks best, but costs more API credits"];
    
    // Load saved quality or default to High
    NSString *savedQuality = [[NSUserDefaults standardUserDefaults] stringForKey:kAILastQuality];
    if (savedQuality && [[self.qualityPopUpButton itemTitles] containsObject:savedQuality]) {
        [self.qualityPopUpButton selectItemWithTitle:savedQuality];
    } else {
        [self.qualityPopUpButton selectItemWithTitle:@"High"];
    }
    
    [drawerContent addSubview:self.qualityPopUpButton];
    
    // Load saved attached image
    NSString *savedImagePath = [[NSUserDefaults standardUserDefaults] stringForKey:kAILastAttachedImagePath];
    if (savedImagePath && [[NSFileManager defaultManager] fileExistsAtPath:savedImagePath]) {
        NSImage *savedImage = [[NSImage alloc] initWithContentsOfFile:savedImagePath];
        if (savedImage) {
            self.attachedImage = savedImage;
            [self.attachedImageView setImage:self.attachedImage];
            [self.attachImageButton setTitle:@"Remove"];
        }
    }
    
    // Add observer for drawer state changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(drawerDidOpen:)
                                                 name:NSDrawerDidOpenNotification
                                               object:self.optionsDrawer];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(drawerDidClose:)
                                                 name:NSDrawerDidCloseNotification
                                               object:self.optionsDrawer];
    
}

- (void)toggleImageAttachment:(id)sender {
    if (self.attachedImage) {
        [self removeImage:sender];
    } else {
        [self attachImage:sender];
    }
}

- (void)attachImage:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowedFileTypes:@[@"jpg", @"jpeg", @"png", @"gif", @"bmp"]];
    [openPanel setAllowsMultipleSelection:NO];
    
    [openPanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [[openPanel URLs] objectAtIndex:0];
            self.attachedImage = [[NSImage alloc] initWithContentsOfURL:url];
            [self.attachedImageView setImage:self.attachedImage];
            [self.attachImageButton setTitle:@"Remove"];
            
            // Save image to application support directory
            [self saveAttachedImage];
        }
    }];
}

- (void)removeImage:(id)sender {
    self.attachedImage = nil;
    [self.attachedImageView setImage:nil];
    [self.attachImageButton setTitle:@"Choose..."];
    
    // Clear saved image
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAILastAttachedImagePath];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)generateImage:(id)sender {
    NSString *prompt = [[self.promptTextView string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // Check for API key first
    if (![self.imageGenerator hasAPIKey]) {
        [self.imageGenerator promptForAPIKeyWithCompletionHandler:^(NSString *apiKey) {
            if (apiKey && [apiKey length] > 0) {
                // Save the API key first
                [self.imageGenerator saveAPIKeyToKeychain:apiKey];
                // API key was entered, continue with generation
                [self generateImage:sender];
            }
            // If cancelled, do nothing
        }];
        return;
    }
    
    // Save size and quality for next run (prompt is saved automatically)
    [[NSUserDefaults standardUserDefaults] setObject:[[self.sizePopUpButton selectedItem] title] forKey:kAILastOutputSize];
    [[NSUserDefaults standardUserDefaults] setObject:[[self.qualityPopUpButton selectedItem] title] forKey:kAILastQuality];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Clear any pending results
    self.pendingGeneratedImage = nil;
    self.pendingGenerationError = nil;
    self.isGenerating = YES;
    
    // Get actual size based on selection
    NSString *sizeTitle = [[self.sizePopUpButton selectedItem] title];
    NSString *size;
    if ([sizeTitle isEqualToString:@"Square"]) {
        size = @"1024x1024";
    } else if ([sizeTitle isEqualToString:@"Portrait"]) {
        size = @"1024x1536";
    } else { // Landscape
        size = @"1536x1024";
    }
    
    // Get quality
    NSString *qualityTitle = [[self.qualityPopUpButton selectedItem] title];
    NSString *quality;
    if ([qualityTitle isEqualToString:@"Low"]) {
        quality = @"low";
    } else if ([qualityTitle isEqualToString:@"Medium"]) {
        quality = @"medium";
    } else { // High
        quality = @"high";
    }
    
    // Start generation in background
    [self.imageGenerator generateImageWithPrompt:prompt
                                           size:size
                                        quality:quality
                                  attachedImage:self.attachedImage
                              completionHandler:^(NSImage *image, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isGenerating = NO;
            [self.progressIndicator stopAnimation:nil];
            [self.progressIndicator setHidden:YES];
            [self.drawerToggleButton setHidden:NO];
            [self.generateButton setEnabled:YES];
            
            // Re-enable window close button
            [[self window] setStyleMask:[[self window] styleMask] | NSClosableWindowMask];
            
            // Store the results
            self.pendingGeneratedImage = image;
            self.pendingGenerationError = error;
        });
    }];
    
    // Show save panel while generation happens in background
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAllowedFileTypes:@[@"png"]];
    
    // Generate unique filename if default already exists
    NSString *baseFilename = @"Generated image";
    NSString *extension = @"png";
    NSString *filename = [NSString stringWithFormat:@"%@.%@", baseFilename, extension];
    
    // Get the default directory (Desktop or Documents)
    NSURL *defaultDirectory = [savePanel directoryURL];
    if (!defaultDirectory) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
        defaultDirectory = [NSURL fileURLWithPath:[paths firstObject]];
    }
    
    // Check if file exists and find unique name
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *testURL = [defaultDirectory URLByAppendingPathComponent:filename];
    
    if ([fileManager fileExistsAtPath:[testURL path]]) {
        NSInteger counter = 2;
        
        // Check if filename already ends with a number
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^(.+) (\\d+)$" 
                                                                               options:0 
                                                                                 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:baseFilename 
                                                        options:0 
                                                          range:NSMakeRange(0, [baseFilename length])];
        
        if (match) {
            // Extract base name and current number
            NSString *basePart = [baseFilename substringWithRange:[match rangeAtIndex:1]];
            NSString *numberPart = [baseFilename substringWithRange:[match rangeAtIndex:2]];
            baseFilename = basePart;
            counter = [numberPart integerValue] + 1;
        }
        
        // Find next available filename
        do {
            filename = [NSString stringWithFormat:@"%@ %ld.%@", baseFilename, (long)counter, extension];
            testURL = [defaultDirectory URLByAppendingPathComponent:filename];
            counter++;
        } while ([fileManager fileExistsAtPath:[testURL path]]);
    }
    
    [savePanel setNameFieldStringValue:filename];
    
    // Start generation immediately in background
    [self.generateButton setEnabled:NO];
    [self.progressIndicator startAnimation:nil];
    [self.progressIndicator setHidden:NO];
    [self.drawerToggleButton setHidden:YES];
    
    // Disable window close button during generation
    [[self window] setStyleMask:[[self window] styleMask] & ~NSClosableWindowMask];
    
    [savePanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *saveURL = [savePanel URL];
            
            // Check if generation is complete
            if (!self.isGenerating) {
                // Generation complete, save immediately
                [self saveGeneratedImageToURL:saveURL];
            } else {
                // Still generating, wait for completion
                [self waitForGenerationAndSaveToURL:saveURL];
            }
        } else {
            // User cancelled save dialog - cancel the generation
            [self.imageGenerator cancelGeneration];
            self.pendingGeneratedImage = nil;
            self.pendingGenerationError = nil;
            self.isGenerating = NO;
            [self.progressIndicator stopAnimation:nil];
            [self.progressIndicator setHidden:YES];
            [self.drawerToggleButton setHidden:NO];
            [self.generateButton setEnabled:YES];
            
            // Re-enable window close button
            [[self window] setStyleMask:[[self window] styleMask] | NSClosableWindowMask];
        }
    }];
}

- (void)saveGeneratedImageToURL:(NSURL *)saveURL {
    if (self.pendingGenerationError) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Image Generation Failed"];
        [alert setInformativeText:[self.pendingGenerationError localizedDescription]];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    } else if (self.pendingGeneratedImage) {
        // Save the image
        NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:[self.pendingGeneratedImage TIFFRepresentation]];
        NSData *pngData = [imageRep representationUsingType:NSPNGFileType properties:@{}];
        [pngData writeToURL:saveURL atomically:YES];
        
        // Check if app is in foreground
        BOOL appIsActive = [[NSApplication sharedApplication] isActive];
        
        if (appIsActive) {
            // App is in foreground, just reveal in Finder
            [[NSWorkspace sharedWorkspace] selectFile:[saveURL path] inFileViewerRootedAtPath:nil];
        } else {
            // App is in background - show notification
            NSUserNotification *notification = [[NSUserNotification alloc] init];
            notification.title = @"Image Created";
            notification.informativeText = [[saveURL path] lastPathComponent];
            
            // Set the image as the content image
            notification.contentImage = self.pendingGeneratedImage;
            
            // Store the file path for reveal action
            notification.userInfo = @{@"filePath": [saveURL path]};
            
            [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        }
    }
    
    // Clear pending results
    self.pendingGeneratedImage = nil;
    self.pendingGenerationError = nil;
}

- (void)waitForGenerationAndSaveToURL:(NSURL *)saveURL {
    // Just wait in background and save when ready - no UI blocking
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (self.isGenerating) {
            [NSThread sleepForTimeInterval:0.1];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self saveGeneratedImageToURL:saveURL];
        });
    });
}

- (void)clearDocument {
    // Use replaceCharactersInRange to properly register with undo manager
    NSRange fullRange = NSMakeRange(0, [[self.promptTextView string] length]);
    if ([self.promptTextView shouldChangeTextInRange:fullRange replacementString:@""]) {
        [[self.promptTextView textStorage] replaceCharactersInRange:fullRange withString:@""];
        [self.promptTextView didChangeText];
    }
    
    [self removeImage:nil];
    
    // Clear saved prompt as well
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAILastPrompt];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Update generate button state
    [self validateGenerateButton];
}

- (void)saveAttachedImage {
    if (!self.attachedImage) return;
    
    // Get application support directory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupportPath = [paths objectAtIndex:0];
    NSString *autoImagePath = [appSupportPath stringByAppendingPathComponent:@"AutoImage"];
    
    // Create directory if it doesn't exist
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:autoImagePath withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Failed to create directory: %@", error);
        return;
    }
    
    // Save image as PNG
    NSString *imagePath = [autoImagePath stringByAppendingPathComponent:@"attached_image.png"];
    NSData *imageData = [self.attachedImage TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    NSData *pngData = [imageRep representationUsingType:NSPNGFileType properties:@{}];
    
    if ([pngData writeToFile:imagePath atomically:YES]) {
        // Save path to user defaults
        [[NSUserDefaults standardUserDefaults] setObject:imagePath forKey:kAILastAttachedImagePath];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

#pragma mark - State Saving

- (void)saveCurrentState {
    NSString *currentPrompt = [[self.promptTextView string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([currentPrompt length] > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:currentPrompt forKey:kAILastPrompt];
    }
    
    NSString *currentSize = [[self.sizePopUpButton selectedItem] title];
    if (currentSize) {
        [[NSUserDefaults standardUserDefaults] setObject:currentSize forKey:kAILastOutputSize];
    }
    
    NSString *currentQuality = [[self.qualityPopUpButton selectedItem] title];
    if (currentQuality) {
        [[NSUserDefaults standardUserDefaults] setObject:currentQuality forKey:kAILastQuality];
    }
    
    // Save attached image if present
    if (self.attachedImage) {
        [self saveAttachedImage];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification {
    [self saveCurrentState];
}

- (void)windowDidResize:(NSNotification *)notification {
    // Calculate minimum height needed for drawer content
    NSView *drawerContent = [self.optionsDrawer contentView];
    CGFloat requiredHeight = 0;
    
    // Find the bottom-most subview to determine required height
    // Since the drawer uses a flipped view, we need to find the maximum Y + height
    for (NSView *subview in [drawerContent subviews]) {
        CGFloat bottom = NSMaxY([subview frame]);
        if (bottom > requiredHeight) {
            requiredHeight = bottom;
        }
    }
    
    // Add some padding for margins and window chrome
    requiredHeight += 80;
    
    // Check if window is too small for drawer
    NSRect windowFrame = [[self window] frame];
    if (NSHeight(windowFrame) < requiredHeight && [self.optionsDrawer state] == NSDrawerOpenState) {
        [self.optionsDrawer close];
    }
}

- (void)windowWillMiniaturize:(NSNotification *)notification {
    // Remember if drawer was open before minimizing
    self.drawerWasOpenBeforeMinimize = ([self.optionsDrawer state] == NSDrawerOpenState);
    
    // Close the drawer if it's open (required for re-open animation to work)
    if (self.drawerWasOpenBeforeMinimize) {
        [self.optionsDrawer close];
    }
}

- (void)windowDidDeminiaturize:(NSNotification *)notification {
    // Restore drawer if it was open before minimizing
    if (self.drawerWasOpenBeforeMinimize) {
        // Add a small delay to ensure window is fully deminiaturized before opening drawer
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.optionsDrawer open];
        });
        self.drawerWasOpenBeforeMinimize = NO;
    }
}

#pragma mark - NSTextViewDelegate

- (void)textDidChange:(NSNotification *)notification {
    // Validate generate button
    [self validateGenerateButton];
    
    // Optionally save on every text change (with debouncing)
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(saveCurrentState) object:nil];
    [self performSelector:@selector(saveCurrentState) withObject:nil afterDelay:1.0];
}

- (void)validateGenerateButton {
    NSString *prompt = [[self.promptTextView string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self.generateButton setEnabled:([prompt length] > 0)];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - NSUserNotificationCenterDelegate

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    // Reveal the saved image in Finder when notification is clicked
    NSString *filePath = notification.userInfo[@"filePath"];
    if (filePath) {
        [[NSWorkspace sharedWorkspace] selectFile:filePath inFileViewerRootedAtPath:nil];
    }
    
    // Remove the notification after clicking
    [center removeDeliveredNotification:notification];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    // Don't show notifications when app is in foreground (we reveal in Finder instead)
    return NO;
}

#pragma mark - Paste Support

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(paste:)) {
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        return [pboard availableTypeFromArray:@[NSTIFFPboardType, NSPasteboardTypePNG]] != nil;
    }
    return YES;
}

- (IBAction)paste:(id)sender {
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    
    if ([pboard availableTypeFromArray:@[NSTIFFPboardType]]) {
        NSData *imageData = [pboard dataForType:NSTIFFPboardType];
        NSImage *image = [[NSImage alloc] initWithData:imageData];
        if (image) {
            [self attachImageFromSource:image];
        }
    } else if ([pboard availableTypeFromArray:@[NSPasteboardTypePNG]]) {
        NSData *imageData = [pboard dataForType:NSPasteboardTypePNG];
        NSImage *image = [[NSImage alloc] initWithData:imageData];
        if (image) {
            [self attachImageFromSource:image];
        }
    }
}

- (void)attachImageFromSource:(NSImage *)image {
    self.attachedImage = image;
    [self.attachedImageView setImage:self.attachedImage];
    [self.attachImageButton setTitle:@"Remove"];
    [self saveAttachedImage];
    
    // Force menu validation to update the File menu item
    [[NSApp mainMenu] update];
}

- (void)toggleOptionsDrawer:(id)sender {
    NSDrawerState state = [self.optionsDrawer state];
    if (state == NSDrawerOpenState || state == NSDrawerOpeningState) {
        [self.optionsDrawer close];
    } else {
        // Calculate minimum height needed for drawer content
        NSView *drawerContent = [self.optionsDrawer contentView];
        CGFloat requiredHeight = 0;
        
        // Find the bottom-most subview to determine required height
        for (NSView *subview in [drawerContent subviews]) {
            CGFloat bottom = NSMaxY([subview frame]);
            if (bottom > requiredHeight) {
                requiredHeight = bottom;
            }
        }
        
        // Add some padding for margins and window chrome
        requiredHeight += 80;
        
        // Check if window is too small and resize if needed
        NSRect windowFrame = [[self window] frame];
        if (NSHeight(windowFrame) < requiredHeight) {
            // Resize window to accommodate drawer
            windowFrame.origin.y -= (requiredHeight - NSHeight(windowFrame));
            windowFrame.size.height = requiredHeight;
            [[self window] setFrame:windowFrame display:YES animate:YES];
        }
        
        [self.optionsDrawer open];
    }
}

#pragma mark - Drawer Notifications

- (void)drawerDidOpen:(NSNotification *)notification {
    NSMenu *viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
    NSMenuItem *drawerMenuItem = [viewMenu itemWithTag:101];
    if (drawerMenuItem) {
        [drawerMenuItem setTitle:@"Hide Side Drawer"];
    }
    [self.drawerToggleButton setToolTip:@"Hide Side Drawer"];
}

- (void)drawerDidClose:(NSNotification *)notification {
    NSMenu *viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
    NSMenuItem *drawerMenuItem = [viewMenu itemWithTag:101];
    if (drawerMenuItem) {
        [drawerMenuItem setTitle:@"Show Side Drawer"];
    }
    [self.drawerToggleButton setToolTip:@"Show Side Drawer"];
}

#pragma mark - PopUp Button Actions

- (void)sizePopUpChanged:(id)sender {
    NSString *selectedTitle = [self.sizePopUpButton titleOfSelectedItem];
    if ([selectedTitle isEqualToString:@"Square"]) {
        [self.sizePopUpButton setToolTip:@"1024x1024"];
    } else if ([selectedTitle isEqualToString:@"Portrait"]) {
        [self.sizePopUpButton setToolTip:@"1024x1536"];
    } else if ([selectedTitle isEqualToString:@"Landscape"]) {
        [self.sizePopUpButton setToolTip:@"1536x1024"];
    }
}

- (BOOL)isGeneratingImage {
    return self.isGenerating;
}

@end