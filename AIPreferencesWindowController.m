#import "AIPreferencesWindowController.h"
#import <Security/Security.h>

static NSString *const kAIPreferencesModeration = @"AIPreferencesModeration";
static NSString *const kAIKeychainService = @"AutoImage";
static NSString *const kAIKeychainAccount = @"OpenAI-API-Key";

@implementation AIPreferencesWindowController

- (id)init {
    NSRect windowRect = NSMakeRect(0, 0, 400, 200);
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
    CGFloat labelWidth = 120;
    CGFloat currentY = NSHeight([contentView bounds]) - margin - 30;
    
    // API Key
    NSTextField *apiKeyLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, currentY, labelWidth, 20)];
    [apiKeyLabel setStringValue:@"API Key:"];
    [apiKeyLabel setBordered:NO];
    [apiKeyLabel setEditable:NO];
    [apiKeyLabel setBackgroundColor:[NSColor clearColor]];
    [apiKeyLabel setAlignment:NSRightTextAlignment];
    [contentView addSubview:apiKeyLabel];
    
    self.apiKeyTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(margin + labelWidth + 10, currentY - 2, 230, 22)];
    [[self.apiKeyTextField cell] setPlaceholderString:@"sk-..."];
    [[self.apiKeyTextField cell] setUsesSingleLineMode:YES];
    [contentView addSubview:self.apiKeyTextField];
    
    // Moderation level
    currentY -= 40;
    NSTextField *moderationLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin, currentY, labelWidth, 20)];
    [moderationLabel setStringValue:@"Moderation:"];
    [moderationLabel setBordered:NO];
    [moderationLabel setEditable:NO];
    [moderationLabel setBackgroundColor:[NSColor clearColor]];
    [moderationLabel setAlignment:NSRightTextAlignment];
    [contentView addSubview:moderationLabel];
    
    self.moderationPopUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(margin + labelWidth + 10, currentY - 2, 150, 25)];
    [self.moderationPopUpButton addItemsWithTitles:@[@"Normal", @"Low"]];
    [contentView addSubview:self.moderationPopUpButton];
    
    // Save button
    currentY -= 50;
    NSButton *saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(NSWidth([contentView bounds]) - margin - 80, currentY, 80, 32)];
    [saveButton setTitle:@"Save"];
    [saveButton setBezelStyle:NSRoundedBezelStyle];
    [saveButton setTarget:self];
    [saveButton setAction:@selector(savePreferences:)];
    [saveButton setKeyEquivalent:@"\r"];
    [contentView addSubview:saveButton];
    
    NSButton *cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(NSWidth([contentView bounds]) - margin - 170, currentY, 80, 32)];
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

@end