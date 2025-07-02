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
    return [[self window].windowController draggingEntered:sender];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    return [[self window].windowController performDragOperation:sender];
}

@end

@interface AIDragDropImageView : NSImageView
@end

@implementation AIDragDropImageView

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    return [[self window].windowController draggingEntered:sender];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    return [[self window].windowController performDragOperation:sender];
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
    NSRect windowRect = NSMakeRect(0, 0, 480, 522);
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
        [window setMinSize:NSMakeSize(480, 340)];
        [window center];
        [window setDelegate:self];
        
        // Set custom content view for drag and drop
        AIDragDropView *contentView = [[AIDragDropView alloc] initWithFrame:[[window contentView] frame]];
        [contentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [window setContentView:contentView];
        
        [self setupUI];
        [self setupDrawer];
        
        self.imageGenerator = [[AIImageGenerationManager alloc] init];
        
        // Register for drag and drop
        [contentView registerForDraggedTypes:@[NSFilenamesPboardType, NSTIFFPboardType, NSPasteboardTypePNG]];
        
        // Register for app termination notification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(saveCurrentState)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:nil];
        
        // Set up notification center delegate on OS X 10.8+
        if (NSClassFromString(@"NSUserNotificationCenter") != nil) {
            [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
        }
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
    [self.generateButton setTitle:@"Generate"];
    [self.generateButton setBezelStyle:NSRoundedBezelStyle];
    [self.generateButton setTarget:self];
    [self.generateButton setAction:@selector(generateImage:)];
    [self.generateButton setKeyEquivalent:@"\r"];
    [contentView addSubview:self.generateButton];
    
    // Progress indicator (next to generate button)
    self.progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(margin + 140, currentY + 7, 300, 20)];
    [self.progressIndicator setStyle:NSProgressIndicatorBarStyle];
    [self.progressIndicator setIndeterminate:YES];
    [self.progressIndicator setHidden:YES];
    [contentView addSubview:self.progressIndicator];
    
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
    
    [scrollView setDocumentView:self.promptTextView];
    [contentView addSubview:scrollView];
    
    // Load saved prompt
    NSString *savedPrompt = [[NSUserDefaults standardUserDefaults] stringForKey:kAILastPrompt];
    if (savedPrompt) {
        [self.promptTextView setString:savedPrompt];
    }
}

- (void)setupDrawer {
    // Create drawer
    self.optionsDrawer = [[NSDrawer alloc] initWithContentSize:NSMakeSize(250, 400) preferredEdge:NSMaxXEdge];
    [self.optionsDrawer setParentWindow:[self window]];
    [self.optionsDrawer setMinContentSize:NSMakeSize(250, 300)];
    [self.optionsDrawer setMaxContentSize:NSMakeSize(300, 800)];
    
    // Create drawer content view with flipped coordinates
    AIFlippedView *drawerContent = [[AIFlippedView alloc] initWithFrame:NSMakeRect(0, 0, 250, 400)];
    [self.optionsDrawer setContentView:drawerContent];
    
    CGFloat margin = 20;
    CGFloat currentY = 20; // Start from top with flipped coordinates
    CGFloat labelWidth = 210;
    
    // Title
    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, currentY, labelWidth, 24)];
    [titleLabel setStringValue:@"Options"];
    [titleLabel setBordered:NO];
    [titleLabel setEditable:NO];
    [titleLabel setBackgroundColor:[NSColor clearColor]];
    [titleLabel setFont:[NSFont boldSystemFontOfSize:16]];
    [drawerContent addSubview:titleLabel];
    
    currentY += 40;
    
    // Image attachment section
    NSTextField *imageLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, currentY, labelWidth, 20)];
    [imageLabel setStringValue:@"Image Attachment"];
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
    [self.attachImageButton setTitle:@"Attach Image"];
    [self.attachImageButton setBezelStyle:NSRoundedBezelStyle];
    [self.attachImageButton setTarget:self];
    [self.attachImageButton setAction:@selector(toggleImageAttachment:)];
    [drawerContent addSubview:self.attachImageButton];
    
    currentY += 40;
    
    // Output settings section
    NSTextField *outputLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, currentY, labelWidth, 20)];
    [outputLabel setStringValue:@"Output Settings"];
    [outputLabel setBordered:NO];
    [outputLabel setEditable:NO];
    [outputLabel setBackgroundColor:[NSColor clearColor]];
    [outputLabel setFont:[NSFont boldSystemFontOfSize:13]];
    [drawerContent addSubview:outputLabel];
    
    currentY += 30;
    
    // Size selection
    NSTextField *sizeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, currentY, 50, 20)];
    [sizeLabel setStringValue:@"Size:"];
    [sizeLabel setBordered:NO];
    [sizeLabel setEditable:NO];
    [sizeLabel setBackgroundColor:[NSColor clearColor]];
    [drawerContent addSubview:sizeLabel];
    
    self.sizePopUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(margin + 60, currentY - 3, 140, 26)];
    [self.sizePopUpButton addItemsWithTitles:@[@"Square", @"Portrait", @"Landscape"]];
    
    // Set tags to map to actual sizes
    [[self.sizePopUpButton itemAtIndex:0] setTag:1024]; // Square = 1024x1024
    [[self.sizePopUpButton itemAtIndex:1] setTag:1536]; // Portrait = 1024x1536
    [[self.sizePopUpButton itemAtIndex:2] setTag:1024]; // Landscape = 1536x1024
    
    // Load saved size or default to Portrait
    NSString *savedSize = [[NSUserDefaults standardUserDefaults] stringForKey:kAILastOutputSize];
    if (savedSize && [[self.sizePopUpButton itemTitles] containsObject:savedSize]) {
        [self.sizePopUpButton selectItemWithTitle:savedSize];
    } else {
        [self.sizePopUpButton selectItemWithTitle:@"Portrait"];
    }
    
    [drawerContent addSubview:self.sizePopUpButton];
    
    currentY += 35;
    
    // Quality selection
    NSTextField *qualityLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, currentY, 50, 20)];
    [qualityLabel setStringValue:@"Quality:"];
    [qualityLabel setBordered:NO];
    [qualityLabel setEditable:NO];
    [qualityLabel setBackgroundColor:[NSColor clearColor]];
    [drawerContent addSubview:qualityLabel];
    
    self.qualityPopUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(margin + 60, currentY - 3, 140, 26)];
    [self.qualityPopUpButton addItemsWithTitles:@[@"Low", @"Medium", @"High"]];
    
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
            [self.attachImageButton setTitle:@"Remove Image"];
        }
    }
    
    // Open drawer by default
    [self.optionsDrawer open];
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
            [self.attachImageButton setTitle:@"Remove Image"];
            
            // Save image to application support directory
            [self saveAttachedImage];
        }
    }];
}

- (void)removeImage:(id)sender {
    self.attachedImage = nil;
    [self.attachedImageView setImage:nil];
    [self.attachImageButton setTitle:@"Attach Image"];
    
    // Clear saved image
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAILastAttachedImagePath];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)generateImage:(id)sender {
    NSString *prompt = [[self.promptTextView string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([prompt length] == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Please enter a prompt"];
        [alert setInformativeText:@"You must provide a text description for the image you want to generate."];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
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
            [self.generateButton setEnabled:YES];
            
            // Store the results
            self.pendingGeneratedImage = image;
            self.pendingGenerationError = error;
        });
    }];
    
    // Show save panel while generation happens in background
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAllowedFileTypes:@[@"png"]];
    [savePanel setNameFieldStringValue:@"generated_image.png"];
    
    // Start generation immediately in background
    [self.generateButton setEnabled:NO];
    [self.progressIndicator startAnimation:nil];
    [self.progressIndicator setHidden:NO];
    
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
            // User cancelled save dialog
            self.pendingGeneratedImage = nil;
            self.pendingGenerationError = nil;
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
        } else if (NSClassFromString(@"NSUserNotification") != nil) {
            // App is in background and OS supports notifications
            NSUserNotification *notification = [[NSUserNotification alloc] init];
            notification.title = @"Image Generated Successfully";
            notification.informativeText = @"Click to reveal in Finder";
            
            // Set the image as the content image if supported
            if ([notification respondsToSelector:@selector(setContentImage:)]) {
                // Scale down the image for notification display
                NSSize thumbnailSize = NSMakeSize(64, 64);
                NSImage *thumbnail = [[NSImage alloc] initWithSize:thumbnailSize];
                [thumbnail lockFocus];
                [self.pendingGeneratedImage drawInRect:NSMakeRect(0, 0, thumbnailSize.width, thumbnailSize.height)
                                               fromRect:NSZeroRect
                                              operation:NSCompositeSourceOver
                                               fraction:1.0];
                [thumbnail unlockFocus];
                [notification setValue:thumbnail forKey:@"contentImage"];
            }
            
            // Store the file path for reveal action
            notification.userInfo = @{@"filePath": [saveURL path]};
            
            [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        } else {
            // Older OS without notification support - reveal in Finder
            [[NSWorkspace sharedWorkspace] selectFile:[saveURL path] inFileViewerRootedAtPath:nil];
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
    [self.promptTextView setString:@""];
    [self removeImage:nil];
    
    // Clear saved prompt as well
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAILastPrompt];
    [[NSUserDefaults standardUserDefaults] synchronize];
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

#pragma mark - NSTextViewDelegate

- (void)textDidChange:(NSNotification *)notification {
    // Optionally save on every text change (with debouncing)
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(saveCurrentState) object:nil];
    [self performSelector:@selector(saveCurrentState) withObject:nil afterDelay:1.0];
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

#pragma mark - Drag and Drop

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
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    if ([pboard availableTypeFromArray:@[NSFilenamesPboardType]]) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        for (NSString *file in files) {
            NSString *extension = [[file pathExtension] lowercaseString];
            if ([@[@"jpg", @"jpeg", @"png", @"gif", @"bmp"] containsObject:extension]) {
                NSImage *image = [[NSImage alloc] initWithContentsOfFile:file];
                if (image) {
                    [self attachImageFromSource:image];
                    return YES;
                }
            }
        }
    } else if ([pboard availableTypeFromArray:@[NSTIFFPboardType]]) {
        NSData *imageData = [pboard dataForType:NSTIFFPboardType];
        NSImage *image = [[NSImage alloc] initWithData:imageData];
        if (image) {
            [self attachImageFromSource:image];
            return YES;
        }
    } else if ([pboard availableTypeFromArray:@[NSPasteboardTypePNG]]) {
        NSData *imageData = [pboard dataForType:NSPasteboardTypePNG];
        NSImage *image = [[NSImage alloc] initWithData:imageData];
        if (image) {
            [self attachImageFromSource:image];
            return YES;
        }
    }
    
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
    [self.attachImageButton setTitle:@"Remove Image"];
    [self saveAttachedImage];
}

- (void)toggleOptionsDrawer:(id)sender {
    NSDrawerState state = [self.optionsDrawer state];
    if (state == NSDrawerOpenState || state == NSDrawerOpeningState) {
        [self.optionsDrawer close];
    } else {
        [self.optionsDrawer open];
    }
}

@end