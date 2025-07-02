#import "AIImageGenerationManager.h"
#import "AIPreferencesWindowController.h"
#import <Security/Security.h>

static NSString *const kAIOpenAIEndpoint = @"https://api.openai.com/v1/images/generations";
static NSString *const kAIKeychainService = @"AutoImage";
static NSString *const kAIKeychainAccount = @"OpenAI-API-Key";
static NSString *const kAIPreferencesModeration = @"AIPreferencesModeration";

@interface AIImageGenerationManager () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, copy) AIImageGenerationCompletionHandler completionHandler;
@property (nonatomic) NSInteger retryCount;
@property (nonatomic) NSInteger maxRetries;
@property (nonatomic, strong) NSURLRequest *currentRequest;
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
                  attachedImage:(NSImage *)attachedImage
              completionHandler:(AIImageGenerationCompletionHandler)completionHandler {
    
    self.completionHandler = completionHandler;
    self.retryCount = 0;
    
    // Get API key
    NSString *apiKey = [self loadAPIKeyFromKeychain];
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
        moderation = @"normal";
    } else {
        moderation = @"low";
    }
    
    // Build request body
    NSMutableDictionary *requestBody = [@{
        @"model": @"gpt-image-1",
        @"prompt": prompt,
        @"n": @1,
        @"size": size,
        @"quality": @"low",
        @"moderation": moderation
    } mutableCopy];
    
    // Add attached image if present
    if (attachedImage) {
        NSString *base64Image = [self base64StringFromImage:attachedImage];
        if (base64Image) {
            [requestBody setObject:@[@{@"b64_json": base64Image}] forKey:@"images"];
        }
    }
    
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:requestBody options:0 error:&jsonError];
    
    if (jsonError) {
        completionHandler(nil, jsonError);
        return;
    }
    
    // Create request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kAIOpenAIEndpoint]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];
    [request setHTTPBody:jsonData];
    [request setTimeoutInterval:60.0];
    
    self.currentRequest = request;
    [self sendRequest];
}

- (void)sendRequest {
    self.responseData = [NSMutableData data];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:self.currentRequest delegate:self startImmediately:YES];
    
    if (!connection) {
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
        NSString *errorMessage = [NSString stringWithFormat:@"Failed after %ld attempts: %@", 
                                 (long)self.maxRetries, error.localizedDescription];
        NSError *finalError = [NSError errorWithDomain:@"AIImageGeneration" 
                                                 code:error.code 
                                             userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
        self.completionHandler(nil, finalError);
    }
}

#pragma mark - Helper Methods

- (NSString *)base64StringFromImage:(NSImage *)image {
    NSData *imageData = [image TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    NSData *pngData = [imageRep representationUsingType:NSPNGFileType properties:@{}];
    return [pngData base64EncodedStringWithOptions:0];
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

@end