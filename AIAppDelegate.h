#import <Cocoa/Cocoa.h>

@class AIMainWindowController;
@class AIPreferencesWindowController;

@interface AIAppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) AIMainWindowController *mainWindowController;
@property (nonatomic, strong) AIPreferencesWindowController *preferencesWindowController;

- (IBAction)showPreferences:(id)sender;
- (IBAction)newDocument:(id)sender;
- (IBAction)attachImage:(id)sender;
- (IBAction)generateImage:(id)sender;

@end