#import "AIGenerateImageAction.h"
#import "../AIImageGenerationManager.h"

@interface AIGenerateImageAction ()
@property (nonatomic, strong) NSPopUpButton *qualityPopUp;
@property (nonatomic, strong) NSPopUpButton *orientationPopUp;
@property (nonatomic, strong) AIImageGenerationManager *imageGenerationManager;
@property (nonatomic, strong) NSView *contentView;
@end

@implementation AIGenerateImageAction

- (instancetype)initWithDefinition:(NSDictionary *)dict fromArchive:(BOOL)archived {
    self = [super initWithDefinition:dict fromArchive:archived];
    if (self) {
        self.imageGenerationManager = [[AIImageGenerationManager alloc] init];
    }
    return self;
}

- (NSView *)view {
    if (!self.contentView) {
        [self createView];
    }
    return self.contentView;
}

- (void)createView {
    // Create main view
    self.contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 120)];
    
    // Quality label
    NSTextField *qualityLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 80, 50, 16)];
    [qualityLabel setStringValue:@"Quality:"];
    [qualityLabel setBezeled:NO];
    [qualityLabel setDrawsBackground:NO];
    [qualityLabel setEditable:NO];
    [qualityLabel setSelectable:NO];
    [self.contentView addSubview:qualityLabel];
    
    // Quality popup
    self.qualityPopUp = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(75, 75, 305, 25) pullsDown:NO];
    [self.qualityPopUp removeAllItems];
    [self.qualityPopUp addItemsWithTitles:@[@"Low", @"Medium", @"High"]];
    [self.qualityPopUp setTarget:self];
    [self.qualityPopUp setAction:@selector(updateParameters)];
    [self.contentView addSubview:self.qualityPopUp];
    
    // Orientation label
    NSTextField *orientationLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 40, 75, 16)];
    [orientationLabel setStringValue:@"Orientation:"];
    [orientationLabel setBezeled:NO];
    [orientationLabel setDrawsBackground:NO];
    [orientationLabel setEditable:NO];
    [orientationLabel setSelectable:NO];
    [self.contentView addSubview:orientationLabel];
    
    // Orientation popup
    self.orientationPopUp = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(100, 35, 280, 25) pullsDown:NO];
    [self.orientationPopUp removeAllItems];
    [self.orientationPopUp addItemsWithTitles:@[@"Square", @"Portrait", @"Landscape"]];
    [self.orientationPopUp setTarget:self];
    [self.orientationPopUp setAction:@selector(updateParameters)];
    [self.contentView addSubview:self.orientationPopUp];
    
    // Set defaults from parameters
    NSDictionary *params = [self parameters];
    NSString *quality = params[@"quality"] ?: @"High";
    NSString *orientation = params[@"orientation"] ?: @"Square";
    
    [self.qualityPopUp selectItemWithTitle:quality];
    [self.orientationPopUp selectItemWithTitle:orientation];
}

- (id)runWithInput:(id)input error:(NSError **)error {
    // Get parameters
    NSString *quality = [self.qualityPopUp titleOfSelectedItem];
    NSString *orientation = [self.orientationPopUp titleOfSelectedItem];
    
    // Map quality to API parameter
    NSString *apiQuality;
    if ([quality isEqualToString:@"Low"]) {
        apiQuality = @"low";
    } else if ([quality isEqualToString:@"Medium"]) {
        apiQuality = @"medium";
    } else if ([quality isEqualToString:@"High"]) {
        apiQuality = @"high";
    } else {
        apiQuality = @"high"; // default
    }
    
    // Map orientation to size
    NSString *size;
    if ([orientation isEqualToString:@"Square"]) {
        size = @"1024x1024";
    } else if ([orientation isEqualToString:@"Portrait"]) {
        size = @"1024x1536";
    } else if ([orientation isEqualToString:@"Landscape"]) {
        size = @"1536x1024";
    } else {
        size = @"1024x1024"; // default
    }
    
    // Get input text
    NSString *prompt = nil;
    if ([input isKindOfClass:[NSString class]]) {
        prompt = input;
    } else if ([input isKindOfClass:[NSArray class]] && [input count] > 0) {
        // Join array of strings
        prompt = [input componentsJoinedByString:@" "];
    }
    
    if (!prompt || [prompt length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.autoimage.AutoImage.GenerateImage" 
                                         code:1 
                                     userInfo:@{NSLocalizedDescriptionKey: @"No text input provided"}];
        }
        return nil;
    }
    
    // Generate temporary output path
    NSString *tempDir = NSTemporaryDirectory();
    NSString *fileName = [NSString stringWithFormat:@"AutoImage_%@.png", 
                          [[NSUUID UUID] UUIDString]];
    NSString *outputPath = [tempDir stringByAppendingPathComponent:fileName];
    
    // Generate image synchronously
    __block NSString *resultPath = nil;
    __block NSError *generationError = nil;
    __block BOOL completionHandlerCalled = NO;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    // Check if we have an API key
    BOOL hasKey = [self.imageGenerationManager hasAPIKey];
    if (!hasKey) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.autoimage.AutoImage.GenerateImage" 
                                         code:5 
                                     userInfo:@{NSLocalizedDescriptionKey: @"API key not found. Please ensure Auto Image app has been configured with an API key."}];
        }
        return nil;
    }
    
    [self.imageGenerationManager generateImageWithPrompt:prompt
                                                   size:size
                                                quality:apiQuality
                                           attachedImage:nil
                                       completionHandler:^(NSImage *image, NSError *error) {
        completionHandlerCalled = YES;
        
        if (error) {
            generationError = error;
        } else if (image) {
            // Save image to file
            NSData *imageData = [image TIFFRepresentation];
            NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
            NSDictionary *properties = @{NSImageCompressionFactor: @1.0};
            NSData *pngData = [imageRep representationUsingType:NSPNGFileType 
                                                     properties:properties];
            
            if ([pngData writeToFile:outputPath atomically:YES]) {
                resultPath = outputPath;
            } else {
                generationError = [NSError errorWithDomain:@"com.autoimage.AutoImage.GenerateImage" 
                                                      code:2 
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Failed to save image"}];
            }
        } else {
            // No image and no error
            generationError = [NSError errorWithDomain:@"com.autoimage.AutoImage.GenerateImage" 
                                                  code:4 
                                              userInfo:@{NSLocalizedDescriptionKey: @"No image or error returned"}];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Wait for completion (with timeout matching the app's 300 second timeout)
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_SEC);
    if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
        // Cancel the generation
        [self.imageGenerationManager cancelGeneration];
        
        if (error) {
            *error = [NSError errorWithDomain:@"com.autoimage.AutoImage.GenerateImage" 
                                         code:3 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Image generation timed out"}];
        }
        return nil;
    }
    
    if (generationError) {
        if (error) {
            *error = generationError;
        }
        return nil;
    }
    
    // Return the path to the generated image
    return resultPath;
}

- (void)parametersUpdated {
    // Update UI when parameters change
    NSDictionary *params = [self parameters];
    NSString *quality = params[@"quality"] ?: @"High";
    NSString *orientation = params[@"orientation"] ?: @"Square";
    
    [self.qualityPopUp selectItemWithTitle:quality];
    [self.orientationPopUp selectItemWithTitle:orientation];
}

- (void)updateParameters {
    // Save current UI state to parameters
    NSMutableDictionary *params = [[self parameters] mutableCopy];
    params[@"quality"] = [self.qualityPopUp titleOfSelectedItem];
    params[@"orientation"] = [self.orientationPopUp titleOfSelectedItem];
    
    [self setParameters:params];
}

@end