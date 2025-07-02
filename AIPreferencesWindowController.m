#import "AIPreferencesWindowController.h"
#import <Security/Security.h>

static NSString *const kAIPreferencesModeration = @"AIPreferencesModeration";
static NSString *const kAIKeychainService = @"AutoImage";
static NSString *const kAIKeychainAccount = @"OpenAI-API-Key";

@implementation AIPreferencesWindowController

- (id)init {
    NSRect windowRect = NSMakeRect(0, 0, 550, 150);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowRect
                                                   styleMask:(NSTitledWindowMask |
                                                            NSClosableWindowMask)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    
    self = [super initWithWindow:window];
    if (self) {
        [window setTitle:@"Preferences"];
        [window center];
        [self setupUI];
        [self loadPreferences];
    }
    return self;
}

- (void)setupUI {
    NSView *contentView = [[self window] contentView];
    
    CGFloat margin = 20;
    CGFloat labelWidth = 80;
    CGFloat windowWidth = NSWidth([contentView bounds]);
    CGFloat windowHeight = NSHeight([contentView bounds]);
    
    // Calculate positions for centered layout
    CGFloat buttonHeight = 32;
    CGFloat fieldSpacing = 35;
    
    // API Key field - positioned at center
    CGFloat centerY = windowHeight / 2;
    CGFloat apiKeyY = centerY + 15; // Slightly above center
    
    NSTextField *apiKeyLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, apiKeyY, labelWidth, 20)];
    [apiKeyLabel setStringValue:@"API Key:"];
    [apiKeyLabel setBordered:NO];
    [apiKeyLabel setEditable:NO];
    [apiKeyLabel setBackgroundColor:[NSColor clearColor]];
    [apiKeyLabel setAlignment:NSRightTextAlignment];
    [contentView addSubview:apiKeyLabel];
    
    self.apiKeyTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(margin + labelWidth + 10, apiKeyY - 2, windowWidth - margin - labelWidth - 10 - margin, 22)];
    [[self.apiKeyTextField cell] setPlaceholderString:@"sk-..."];
    [[self.apiKeyTextField cell] setUsesSingleLineMode:YES];
    [contentView addSubview:self.apiKeyTextField];
    
    // Moderation level - below API key
    CGFloat moderationY = apiKeyY - fieldSpacing;
    NSTextField *moderationLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, moderationY, labelWidth, 20)];
    [moderationLabel setStringValue:@"Moderation:"];
    [moderationLabel setBordered:NO];
    [moderationLabel setEditable:NO];
    [moderationLabel setBackgroundColor:[NSColor clearColor]];
    [moderationLabel setAlignment:NSRightTextAlignment];
    [contentView addSubview:moderationLabel];
    
    self.moderationPopUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(margin + labelWidth + 10, moderationY - 2, 150, 25)];
    [self.moderationPopUpButton addItemsWithTitles:@[@"Normal", @"Low"]];
    [contentView addSubview:self.moderationPopUpButton];
    
    // Buttons at bottom
    CGFloat buttonY = margin;
    NSButton *saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(windowWidth - margin - 80, buttonY, 80, buttonHeight)];
    [saveButton setTitle:@"Save"];
    [saveButton setBezelStyle:NSRoundedBezelStyle];
    [saveButton setTarget:self];
    [saveButton setAction:@selector(savePreferences:)];
    [saveButton setKeyEquivalent:@"\r"];
    [contentView addSubview:saveButton];
    
    NSButton *cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(windowWidth - margin - 170, buttonY, 80, buttonHeight)];
    [cancelButton setTitle:@"Cancel"];
    [cancelButton setBezelStyle:NSRoundedBezelStyle];
    [cancelButton setTarget:self];
    [cancelButton setAction:@selector(cancel:)];
    [cancelButton setKeyEquivalent:@"\033"];
    [contentView addSubview:cancelButton];
}

- (void)loadPreferences {
    // Load API key from Keychain
    NSString *apiKey = [self loadAPIKeyFromKeychain];
    if (apiKey) {
        [self.apiKeyTextField setStringValue:apiKey];
    }
    
    // Load moderation from NSUserDefaults
    NSString *moderation = [[NSUserDefaults standardUserDefaults] stringForKey:kAIPreferencesModeration];
    if (!moderation) {
        moderation = @"Normal";
    }
    [self.moderationPopUpButton selectItemWithTitle:moderation];
}

- (void)savePreferences:(id)sender {
    // Save API key to Keychain
    NSString *apiKey = [self.apiKeyTextField stringValue];
    if ([apiKey length] > 0) {
        [self saveAPIKeyToKeychain:apiKey];
    } else {
        // Delete API key from Keychain if empty
        [self deleteAPIKeyFromKeychain];
    }
    
    // Save moderation to NSUserDefaults
    NSString *moderation = [[self.moderationPopUpButton selectedItem] title];
    [[NSUserDefaults standardUserDefaults] setObject:moderation forKey:kAIPreferencesModeration];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[self window] close];
}

- (void)cancel:(id)sender {
    [[self window] close];
}

#pragma mark - Keychain Methods

- (NSString *)loadAPIKeyFromKeychain {
    OSStatus status;
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kAIKeychainService,
        (__bridge id)kSecAttrAccount: kAIKeychainAccount,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    
    CFTypeRef result = NULL;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    
    if (status == errSecSuccess) {
        NSData *data = (__bridge_transfer NSData *)result;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    
    return nil;
}

- (void)saveAPIKeyToKeychain:(NSString *)apiKey {
    NSData *apiKeyData = [apiKey dataUsingEncoding:NSUTF8StringEncoding];
    
    // First try to update existing item
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kAIKeychainService,
        (__bridge id)kSecAttrAccount: kAIKeychainAccount
    };
    
    NSDictionary *attributesToUpdate = @{
        (__bridge id)kSecValueData: apiKeyData
    };
    
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query,
                                   (__bridge CFDictionaryRef)attributesToUpdate);
    
    if (status == errSecItemNotFound) {
        // Item doesn't exist, add it
        NSMutableDictionary *newItem = [query mutableCopy];
        [newItem setObject:apiKeyData forKey:(__bridge id)kSecValueData];
        
        status = SecItemAdd((__bridge CFDictionaryRef)newItem, NULL);
    }
    
    if (status != errSecSuccess) {
        NSLog(@"Error saving API key to keychain: %d", (int)status);
    }
}

- (void)deleteAPIKeyFromKeychain {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kAIKeychainService,
        (__bridge id)kSecAttrAccount: kAIKeychainAccount
    };
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    
    if (status != errSecSuccess && status != errSecItemNotFound) {
        NSLog(@"Error deleting API key from keychain: %d", (int)status);
    }
}

@end