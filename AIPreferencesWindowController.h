#import <Cocoa/Cocoa.h>

@interface AIPreferencesWindowController : NSWindowController

@property (nonatomic, strong) NSTextField *apiKeyTextField;
@property (nonatomic, strong) NSPopUpButton *moderationPopUpButton;
@property (nonatomic, strong) NSButton *saveButton;

@end