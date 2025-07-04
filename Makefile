# AutoImage Makefile
# Build AutoImage without Xcode

CC = clang
OBJC = clang
CFLAGS = -fobjc-arc -Wall -O2 -mmacosx-version-min=10.8
LDFLAGS = -framework Cocoa -framework Foundation -framework Security

TARGET = Auto\ Image.app
EXECUTABLE = $(TARGET)/Contents/MacOS/AutoImage
BUNDLE_IDENTIFIER = com.autoimage.AutoImage

# Calendar-based versioning
VERSION = $(shell date +%Y.%m.%d)

SOURCES = main.m \
          AIAppDelegate.m \
          AIMainWindowController.m \
          AIPreferencesWindowController.m \
          AIImageGenerationManager.m

OBJECTS = $(SOURCES:.m=.o)

# Automator Action
ACTION_NAME = Generate\ Image.action
ACTION_TARGET = $(TARGET)/Contents/Library/Automator/$(ACTION_NAME)
ACTION_SOURCES = AutomatorAction/AIGenerateImageAction.m
ACTION_OBJECTS = $(ACTION_SOURCES:.m=.o)

all: $(TARGET) $(ACTION_TARGET)

$(TARGET): $(EXECUTABLE) Info.plist
	@echo "Building application bundle..."
	@mkdir -p $(TARGET)/Contents/Resources
	@cp Info.plist $(TARGET)/Contents/
	@cp AppIcon.icns $(TARGET)/Contents/Resources/
	@touch $(TARGET)

$(EXECUTABLE): $(OBJECTS)
	@echo "Linking executable..."
	@mkdir -p $(TARGET)/Contents/MacOS
	$(CC) $(LDFLAGS) -o $(EXECUTABLE) $^

%.o: %.m
	@echo "Compiling $<..."
	$(OBJC) $(CFLAGS) -c $< -o $@

Info.plist:
	@echo "Creating Info.plist..."
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > Info.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> Info.plist
	@echo '<plist version="1.0">' >> Info.plist
	@echo '<dict>' >> Info.plist
	@echo '    <key>CFBundleDevelopmentRegion</key>' >> Info.plist
	@echo '    <string>en</string>' >> Info.plist
	@echo '    <key>CFBundleExecutable</key>' >> Info.plist
	@echo '    <string>AutoImage</string>' >> Info.plist
	@echo '    <key>CFBundleIdentifier</key>' >> Info.plist
	@echo '    <string>$(BUNDLE_IDENTIFIER)</string>' >> Info.plist
	@echo '    <key>CFBundleInfoDictionaryVersion</key>' >> Info.plist
	@echo '    <string>6.0</string>' >> Info.plist
	@echo '    <key>CFBundleName</key>' >> Info.plist
	@echo '    <string>Auto Image</string>' >> Info.plist
	@echo '    <key>CFBundlePackageType</key>' >> Info.plist
	@echo '    <string>APPL</string>' >> Info.plist
	@echo '    <key>CFBundleShortVersionString</key>' >> Info.plist
	@echo '    <string>$(VERSION)</string>' >> Info.plist
	@echo '    <key>LSMinimumSystemVersion</key>' >> Info.plist
	@echo '    <string>10.8</string>' >> Info.plist
	@echo '    <key>NSHighResolutionCapable</key>' >> Info.plist
	@echo '    <true/>' >> Info.plist
	@echo '    <key>NSPrincipalClass</key>' >> Info.plist
	@echo '    <string>NSApplication</string>' >> Info.plist
	@echo '    <key>NSApplicationDelegate</key>' >> Info.plist
	@echo '    <string>AIAppDelegate</string>' >> Info.plist
	@echo '    <key>CFBundleIconFile</key>' >> Info.plist
	@echo '    <string>AppIcon</string>' >> Info.plist
	@echo '</dict>' >> Info.plist
	@echo '</plist>' >> Info.plist

$(ACTION_TARGET): $(ACTION_OBJECTS) AIImageGenerationManager.o
	@echo "Building Automator action..."
	@mkdir -p $(TARGET)/Contents/Library/Automator
	@mkdir -p $(ACTION_TARGET)/Contents/MacOS
	$(CC) $(LDFLAGS) -framework Automator -bundle -o $(ACTION_TARGET)/Contents/MacOS/Generate\ Image $(ACTION_OBJECTS) AIImageGenerationManager.o
	@sed 's/VERSION_PLACEHOLDER/$(VERSION)/g' AutomatorAction/Info-Action.plist.template > $(ACTION_TARGET)/Contents/Info.plist

clean:
	@echo "Cleaning build files..."
	rm -rf Auto\ Image.app $(OBJECTS) $(ACTION_OBJECTS) Info.plist

run: $(TARGET)
	@echo "Running Auto Image..."
	open $(TARGET)

.PHONY: all clean run