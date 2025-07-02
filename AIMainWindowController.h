#import <Cocoa/Cocoa.h>

@interface AIMainWindowController : NSWindowController

@property (nonatomic, strong) NSTextView *promptTextView;
@property (nonatomic, strong) NSButton *attachImageButton;
@property (nonatomic, strong) NSImageView *attachedImageView;
@property (nonatomic, strong) NSPopUpButton *sizePopUpButton;
@property (nonatomic, strong) NSButton *generateButton;
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;
@property (nonatomic, strong) NSImage *attachedImage;

- (void)clearDocument;
- (void)attachImage:(id)sender;
- (void)removeImage:(id)sender;
- (void)generateImage:(id)sender;

@end