#import "AIImageGenerationManager.h"
#import "AIPreferencesWindowController.h"
#import <Security/Security.h>

static NSString *const kAIOpenAIGenerationsEndpoint = @"https://api.openai.com/v1/images/generations";
static NSString *const kAIOpenAIEditsEndpoint = @"https://api.openai.com/v1/images/edits";
static NSString *const kAIKeychainService = @"AutoImage";
static NSString *const kAIKeychainAccount = @"OpenAI-API-Key";
static NSString *const kAIPreferencesModeration = @"AIPreferencesModeration";

@interface AIImageGenerationManager () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, copy) AIImageGenerationCompletionHandler completionHandler;
@property (nonatomic) NSInteger retryCount;
@property (nonatomic) NSInteger maxRetries;
@property (nonatomic, strong) NSURLRequest *currentRequest;
@property (nonatomic, strong) NSURLConnection *currentConnection;
@property (nonatomic, strong) NSString *cachedAPIKey;
@end

@implementation AIImageGenerationManager

- (id)init {
    self = [super init];
    if (self) {
        self.maxRetries = 10;
    }
    return self;
}

- (void)generateImageWithPrompt:(NSString *)prompt
                          size:(NSString *)size
                       quality:(NSString *)quality
                  attachedImage:(NSImage *)attachedImage
              completionHandler:(AIImageGenerationCompletionHandler)completionHandler {
    
    self.completionHandler = completionHandler;
    self.retryCount = 0;
    
    // Get API key (use cached value if available from hasAPIKey check)
    NSString *apiKey = self.cachedAPIKey ? self.cachedAPIKey : [self loadAPIKeyFromKeychain];
    self.cachedAPIKey = nil; // Clear cache after use
    if (!apiKey || [apiKey length] == 0) {
        NSError *error = [NSError errorWithDomain:@"AIImageGeneration" 
                                            code:401 
                                        userInfo:@{NSLocalizedDescriptionKey: @"API key not set. Please set your OpenAI API key in Preferences."}];
        completionHandler(nil, error);
        return;
    }
    
    // Get moderation level
    NSString *moderation = [[NSUserDefaults standardUserDefaults] stringForKey:kAIPreferencesModeration];
    if ([moderation isEqualToString:@"Normal"]) {
        moderation = @"auto";
    } else {
        moderation = @"low";
    }
    
    NSMutableURLRequest *request;
    
    if (attachedImage) {
        // Use edits endpoint with multipart/form-data
        request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kAIOpenAIEditsEndpoint]];
        [request setHTTPMethod:@"POST"];
        [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];
        [request setTimeoutInterval:300.0]; // 5 minutes for image generation
        
        // Create multipart form data
        NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
        [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
        
        NSMutableData *body = [NSMutableData data];
        
        // Add image
        NSData *imageData = [self pngDataFromImage:attachedImage];
        if (imageData) {
            [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[@"Content-Disposition: form-data; name=\"image\"; filename=\"image.png\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[@"Content-Type: image/png\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:imageData];
            [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        }
        
        // Add other fields
        NSDictionary *fields = @{
            @"model": @"gpt-image-1",
            @"prompt": prompt,
            @"n": @"1",
            @"size": size,
            @"quality": quality,
            @"background": @"auto",
            @"moderation": moderation
        };
        
        for (NSString *key in fields) {
            [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[fields objectForKey:key] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        }
        
        [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [request setHTTPBody:body];
        
    } else {
        // Use generations endpoint with JSON
        request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kAIOpenAIGenerationsEndpoint]];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];
        [request setTimeoutInterval:300.0]; // 5 minutes for image generation
        
        NSDictionary *requestBody = @{
            @"model": @"gpt-image-1",
            @"prompt": prompt,
            @"n": @1,
            @"size": size,
            @"quality": quality,
            @"moderation": moderation
        };
        
        NSError *jsonError;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:requestBody options:0 error:&jsonError];
        
        if (jsonError) {
            completionHandler(nil, jsonError);
            return;
        }
        
        [request setHTTPBody:jsonData];
    }
    
    self.currentRequest = request;
    [self sendRequest];
}

- (void)sendRequest {
    self.responseData = [NSMutableData data];
    self.currentConnection = [[NSURLConnection alloc] initWithRequest:self.currentRequest delegate:self startImmediately:YES];
    
    if (!self.currentConnection) {
        NSError *error = [NSError errorWithDomain:@"AIImageGeneration" 
                                            code:500 
                                        userInfo:@{NSLocalizedDescriptionKey: @"Failed to create connection"}];
        self.completionHandler(nil, error);
    }
}

#pragma mark - NSURLConnection Delegate Methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSError *jsonError;
    NSDictionary *response = [NSJSONSerialization JSONObjectWithData:self.responseData options:0 error:&jsonError];
    
    if (jsonError) {
        [self handleError:jsonError];
        return;
    }
    
    // Check for API error
    if (response[@"error"]) {
        NSString *errorMessage = response[@"error"][@"message"] ?: @"Unknown error";
        NSError *error = [NSError errorWithDomain:@"AIImageGeneration" 
                                            code:400 
                                        userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
        [self handleError:error];
        return;
    }
    
    // Extract image data
    NSArray *dataArray = response[@"data"];
    if ([dataArray count] > 0) {
        NSString *base64String = dataArray[0][@"b64_json"];
        if (base64String) {
            NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
            NSImage *image = [[NSImage alloc] initWithData:imageData];
            
            if (image) {
                self.completionHandler(image, nil);
                self.currentConnection = nil;
            } else {
                NSError *error = [NSError errorWithDomain:@"AIImageGeneration" 
                                                    code:500 
                                                userInfo:@{NSLocalizedDescriptionKey: @"Failed to decode image"}];
                [self handleError:error];
            }
        }
    } else {
        NSError *error = [NSError errorWithDomain:@"AIImageGeneration" 
                                            code:500 
                                        userInfo:@{NSLocalizedDescriptionKey: @"No image data in response"}];
        [self handleError:error];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self handleError:error];
}

#pragma mark - Error Handling with Retry

- (void)handleError:(NSError *)error {
    self.retryCount++;
    
    if (self.retryCount < self.maxRetries) {
        NSLog(@"Request failed (attempt %ld/%ld): %@. Retrying in 2 seconds...", 
              (long)self.retryCount, (long)self.maxRetries, error.localizedDescription);
        
        // Wait 2 seconds and retry
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self sendRequest];
        });
    } else {
        // Max retries reached
        NSString *errorMessage = [NSString stringWithFormat:@"%@", error.localizedDescription];
        NSError *finalError = [NSError errorWithDomain:@"AIImageGeneration" 
                                                 code:error.code 
                                             userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
        self.completionHandler(nil, finalError);
        self.currentConnection = nil;
    }
}

#pragma mark - Helper Methods

- (NSData *)pngDataFromImage:(NSImage *)image {
    NSData *imageData = [image TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    return [imageRep representationUsingType:NSPNGFileType properties:@{}];
}

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

- (BOOL)hasAPIKey {
    // Cache the API key to avoid double keychain access
    self.cachedAPIKey = [self loadAPIKeyFromKeychain];
    return (self.cachedAPIKey && [self.cachedAPIKey length] > 0);
}

- (void)cancelGeneration {
    if (self.currentConnection) {
        [self.currentConnection cancel];
        self.currentConnection = nil;
        self.completionHandler = nil;
        self.responseData = nil;
    }
}

- (void)promptForAPIKeyWithCompletionHandler:(void (^)(NSString *apiKey))completionHandler {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Enter OpenAI API Key"];
    [alert setInformativeText:@"Please enter your OpenAI API key to generate images:"];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 420, 24)];
    [[textField cell] setPlaceholderString:@"sk-..."];
    [alert setAccessoryView:textField];
    
    // Get reference to OK button and disable it
    NSArray *buttons = [alert buttons];
    NSButton *okButton = [buttons objectAtIndex:0];
    [okButton setEnabled:NO];
    
    // Monitor text changes to enable/disable OK button
    [[NSNotificationCenter defaultCenter] addObserverForName:NSControlTextDidChangeNotification
                                                      object:textField
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        NSString *text = [textField stringValue];
        // Enable OK button only if text starts with "sk-" and has more characters after
        BOOL isValid = [text length] > 3 && [text hasPrefix:@"sk-"];
        [okButton setEnabled:isValid];
    }];
    
    NSInteger result = [alert runModal];
    
    if (result == NSAlertFirstButtonReturn) {
        NSString *apiKey = [textField stringValue];
        completionHandler(apiKey);
    } else {
        completionHandler(nil);
    }
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