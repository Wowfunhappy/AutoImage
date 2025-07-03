#import <Cocoa/Cocoa.h>

@interface AIMainWindowController : NSWindowController

@property (nonatomic, strong) NSDrawer *optionsDrawer;
@property (nonatomic, strong) NSTextView *promptTextView;
@property (nonatomic, strong) NSButton *attachImageButton;
@property (nonatomic, strong) NSImageView *attachedImageView;
@property (nonatomic, strong) NSPopUpButton *sizePopUpButton;
@property (nonatomic, strong) NSPopUpButton *qualityPopUpButton;
@property (nonatomic, strong) NSButton *generateButton;
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;
@property (nonatomic, strong) NSButton *drawerToggleButton;
@property (nonatomic, strong) NSImage *attachedImage;
@property (nonatomic, assign) BOOL drawerWasOpenBeforeMinimize;

- (void)clearDocument;
- (void)attachImage:(id)sender;
- (void)removeImage:(id)sender;
- (void)generateImage:(id)sender;
- (void)toggleOptionsDrawer:(id)sender;
- (void)attachImageFromSource:(NSImage *)image;
- (BOOL)isGeneratingImage;

@end