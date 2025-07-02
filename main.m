#import <Cocoa/Cocoa.h>
#import "AIAppDelegate.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        AIAppDelegate *appDelegate = [[AIAppDelegate alloc] init];
        [application setDelegate:appDelegate];
        return NSApplicationMain(argc, (const char **)argv);
    }
}