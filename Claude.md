Auto Image is an Objective-C app for Mac OS X 10.6+ which can generate images using the OpenAI `gpt-image-1` API.

## Main Window Layout

The main window contains, from top to bottom:
1. A large text area for the user to enter their prompt
2. A single toggle button for image attachment that switches between "Attach Image" and "Remove Image", with a 60x60 image preview box
3. Two dropdowns on the same line:
   - Output Size: "Square" (1024x1024), "Portrait" (1024x1536), "Landscape" (1536x1024)
   - Quality: "Low", "Medium", "High"
4. A "Generate" button
5. A progress bar that appears during image generation

## Key Features

- **Image Attachment**: Users can attach images in three ways:
  1. Click the "Attach Image" button
  2. Drag and drop image files anywhere on the window
  3. Paste images from clipboard (Edit → Paste)
  
- **Persistence**: The app remembers between launches:
  - Last entered prompt
  - Selected output size
  - Selected quality
  - Attached image (saved to ~/Library/Application Support/AutoImage/)

- **Save Flow**: After clicking Generate, a save dialog appears immediately while generation happens in background

## API Integration

- **Without attached image**: Uses `/v1/images/generations` endpoint with JSON
- **With attached image**: Uses `/v1/images/edits` endpoint with multipart/form-data
- Automatic retry: 10 attempts with 2-second delays on failure
- Quality values map to API: "Low" → "low", "Medium" → "medium", "High" → "high"

## Preferences Window

Accessible via ⌘, (Preferences menu item):
1. API key text field (stored securely in Keychain)
2. Moderation dropdown: "Normal" (maps to "auto") or "Low" (maps to "low")

## Menu Bar

Following Apple HIG with complete standard menus:
- **Auto Image menu**: About, Preferences, Services, Hide/Show options, Quit
- **File menu**: Clear, Attach Image (dynamically changes to "Remove Image"), Generate (⌘G), Close
- **Edit menu**: Standard edit commands, Find submenu, Spelling submenu, Dictation, Emoji & Symbols
- **Window menu**: Standard window commands
- **Help menu**: Auto Image Help

## Technical Details

- Built without Xcode using Makefile
- All UI created programmatically (no XIB files)
- Uses NSURLConnection for compatibility with OS X 10.9
- Calendar-based versioning (YYYY.MM.DD) set automatically during build
- Custom drag-drop view classes for window and image preview area

## Important Implementation Notes

- When attaching images, the API requires multipart/form-data, not JSON
- The "standard" quality value should be mapped to "medium" for the API
- Use NSUserDefaults for preferences except API key (use Keychain)
- Image attachments are saved as PNG to Application Support directory

Please reference the Docs folder for:
- Documentation on the gpt-image-1 API
- An example curl request to the gpt-image-1 API
- Apple's Human Interface Guidelines

You _must_ reference this documentation, it will help you!