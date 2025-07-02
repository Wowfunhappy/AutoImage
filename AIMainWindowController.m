#import "AIMainWindowController.h"
#import "AIImageGenerationManager.h"

static NSString *const kAILastPrompt = @"AILastPrompt";
static NSString *const kAILastOutputSize = @"AILastOutputSize";

@interface AIMainWindowController () <NSWindowDelegate, NSTextViewDelegate>
@property (nonatomic, strong) AIImageGenerationManager *imageGenerator;
@property (nonatomic, strong) NSButton *removeImageButton;
@end

@implementation AIMainWindowController

- (id)init {
    NSRect windowRect = NSMakeRect(0, 0, 600, 500);
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
        [self setupUI];
        
        self.imageGenerator = [[AIImageGenerationManager alloc] init];
        
        // Register for app termination notification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(saveCurrentState)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:nil];
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
    self.progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(margin + 140, currentY + 6, 300, 20)];
    [self.progressIndicator setStyle:NSProgressIndicatorBarStyle];
    [self.progressIndicator setIndeterminate:YES];
    [self.progressIndicator setHidden:YES];
    [contentView addSubview:self.progressIndicator];
    
    // Size selection
    currentY += 50;
    NSTextField *sizeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, currentY + 3, 100, 20)];
    [sizeLabel setStringValue:@"Output Size:"];
    [sizeLabel setBordered:NO];
    [sizeLabel setEditable:NO];
    [sizeLabel setBackgroundColor:[NSColor clearColor]];
    [contentView addSubview:sizeLabel];
    
    self.sizePopUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(margin + 110, currentY, 200, 26)];
    [self.sizePopUpButton addItemsWithTitles:@[@"1024x1024", @"1024x1536", @"1536x1024"]];
    
    // Load saved size or default to 1024x1536
    NSString *savedSize = [[NSUserDefaults standardUserDefaults] stringForKey:kAILastOutputSize];
    if (savedSize && [[self.sizePopUpButton itemTitles] containsObject:savedSize]) {
        [self.sizePopUpButton selectItemWithTitle:savedSize];
    } else {
        [self.sizePopUpButton selectItemWithTitle:@"1024x1536"];
    }
    
    [contentView addSubview:self.sizePopUpButton];
    
    // Image attachment area
    currentY += 50;
    self.attachImageButton = [[NSButton alloc] initWithFrame:NSMakeRect(margin, currentY, 120, 25)];
    [self.attachImageButton setTitle:@"Attach Image"];
    [self.attachImageButton setBezelStyle:NSRoundedBezelStyle];
    [self.attachImageButton setTarget:self];
    [self.attachImageButton setAction:@selector(attachImage:)];
    [contentView addSubview:self.attachImageButton];
    
    self.removeImageButton = [[NSButton alloc] initWithFrame:NSMakeRect(margin + 130, currentY, 120, 25)];
    [self.removeImageButton setTitle:@"Remove Image"];
    [self.removeImageButton setBezelStyle:NSRoundedBezelStyle];
    [self.removeImageButton setTarget:self];
    [self.removeImageButton setAction:@selector(removeImage:)];
    [self.removeImageButton setEnabled:NO];
    [contentView addSubview:self.removeImageButton];
    
    self.attachedImageView = [[NSImageView alloc] initWithFrame:NSMakeRect(margin + 260, currentY - 17, 60, 60)];
    [self.attachedImageView setImageFrameStyle:NSImageFrameGrayBezel];
    [self.attachedImageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [contentView addSubview:self.attachedImageView];
    
    // Prompt text view with scroll view (fill remaining space)
    currentY += 70;
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

- (void)attachImage:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowedFileTypes:@[@"jpg", @"jpeg", @"png", @"gif", @"bmp"]];
    [openPanel setAllowsMultipleSelection:NO];
    
    [openPanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [[openPanel URLs] objectAtIndex:0];
            self.attachedImage = [[NSImage alloc] initWithContentsOfURL:url];
            [self.attachedImageView setImage:self.attachedImage];
            [self.removeImageButton setEnabled:YES];
        }
    }];
}

- (void)removeImage:(id)sender {
    self.attachedImage = nil;
    [self.attachedImageView setImage:nil];
    [self.removeImageButton setEnabled:NO];
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
    
    // Save size for next run (prompt is saved automatically)
    [[NSUserDefaults standardUserDefaults] setObject:[[self.sizePopUpButton selectedItem] title] forKey:kAILastOutputSize];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Show save panel immediately
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAllowedFileTypes:@[@"png"]];
    [savePanel setNameFieldStringValue:@"generated_image.png"];
    
    [savePanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *saveURL = [savePanel URL];
            
            // Start generation
            [self.generateButton setEnabled:NO];
            [self.progressIndicator setHidden:NO];
            [self.progressIndicator startAnimation:nil];
            
            NSString *size = [[self.sizePopUpButton selectedItem] title];
            
            [self.imageGenerator generateImageWithPrompt:prompt
                                                   size:size
                                           attachedImage:self.attachedImage
                                       completionHandler:^(NSImage *image, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.progressIndicator stopAnimation:nil];
                    [self.progressIndicator setHidden:YES];
                    [self.generateButton setEnabled:YES];
                    
                    if (error) {
                        NSAlert *alert = [[NSAlert alloc] init];
                        [alert setMessageText:@"Image Generation Failed"];
                        [alert setInformativeText:[error localizedDescription]];
                        [alert addButtonWithTitle:@"OK"];
                        [alert runModal];
                    } else if (image) {
                        // Save the image
                        NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
                        NSData *pngData = [imageRep representationUsingType:NSPNGFileType properties:@{}];
                        [pngData writeToURL:saveURL atomically:YES];
                        
                        // Show success
                        NSAlert *alert = [[NSAlert alloc] init];
                        [alert setMessageText:@"Image Generated Successfully"];
                        [alert setInformativeText:[NSString stringWithFormat:@"Image saved to: %@", [saveURL path]]];
                        [alert addButtonWithTitle:@"OK"];
                        [alert runModal];
                    }
                });
            }];
        }
    }];
}

- (void)clearDocument {
    [self.promptTextView setString:@""];
    [self removeImage:nil];
    
    // Clear saved prompt as well
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAILastPrompt];
    [[NSUserDefaults standardUserDefaults] synchronize];
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

@end