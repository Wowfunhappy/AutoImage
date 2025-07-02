#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

typedef void (^AIImageGenerationCompletionHandler)(NSImage *image, NSError *error);

@interface AIImageGenerationManager : NSObject

- (void)generateImageWithPrompt:(NSString *)prompt
                          size:(NSString *)size
                       quality:(NSString *)quality
                  attachedImage:(NSImage *)attachedImage
              completionHandler:(AIImageGenerationCompletionHandler)completionHandler;

@end