Auto Image is an Objective-C app for Mac OS X 10.6+ which can generate images using the OpenAI `gpt-image-1` API.

The main window contains, from top to bottom:
1. A large text area for the user to enter their prompt.
2. A button for the user to attatch an existing image, and a way to manage attatchments. 
3. A drop down that allows the user to select the output image size.
4. A "Generate" button.
5. A progress bar for during image generation.

After the user presses generate, they will see a dialog asking them where to save their image. They should be able to choose their save location as image generation begins in the background.

The app should also include a Preferences menu, where the user can:
1. Set their API key. (text box)
2. Change the moderation between "Normal" and "Low". (dropdown)

Quality should always be set to "Low".

If the API returns an error, the app should automatically retry up to ten times, waiting two seconds between tries.

The app must build on OS X 10.9 without xCode installed.

Please reference the Docs folder for:
- Documentation on the gpt-image-1 API
- An example curl request to the gpt-image-1 API
- Apple's Human Interface Guidelines

You _must_ reference this documentation, it will help you!