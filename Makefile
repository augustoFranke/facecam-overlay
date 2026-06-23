.PHONY: all icon app dmg run verify clean

APP_NAME := FaceCam Overlay
EXECUTABLE := FaceCamOverlay
VERSION := 1.0.0
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
ICONSET := $(BUILD_DIR)/AppIcon.iconset
DMG_ROOT := $(BUILD_DIR)/dmg-root
DMG_PATH := $(BUILD_DIR)/FaceCam-Overlay-$(VERSION).dmg
SIGN_IDENTITY ?= -

all: dmg

icon: Resources/AppIcon.icns

Resources/AppIcon.icns: Resources/AppIcon.png
	rm -rf "$(ICONSET)"
	mkdir -p "$(ICONSET)"
	sips -z 16 16 "$<" --out "$(ICONSET)/icon_16x16.png" >/dev/null
	sips -z 32 32 "$<" --out "$(ICONSET)/icon_16x16@2x.png" >/dev/null
	sips -z 32 32 "$<" --out "$(ICONSET)/icon_32x32.png" >/dev/null
	sips -z 64 64 "$<" --out "$(ICONSET)/icon_32x32@2x.png" >/dev/null
	sips -z 128 128 "$<" --out "$(ICONSET)/icon_128x128.png" >/dev/null
	sips -z 256 256 "$<" --out "$(ICONSET)/icon_128x128@2x.png" >/dev/null
	sips -z 256 256 "$<" --out "$(ICONSET)/icon_256x256.png" >/dev/null
	sips -z 512 512 "$<" --out "$(ICONSET)/icon_256x256@2x.png" >/dev/null
	sips -z 512 512 "$<" --out "$(ICONSET)/icon_512x512.png" >/dev/null
	cp "$<" "$(ICONSET)/icon_512x512@2x.png"
	iconutil -c icns "$(ICONSET)" -o "$@"

app: icon
	swift build -c release
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"
	cp ".build/release/$(EXECUTABLE)" "$(APP_DIR)/Contents/MacOS/$(EXECUTABLE)"
	cp Resources/Info.plist "$(APP_DIR)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(APP_DIR)/Contents/Resources/AppIcon.icns"
	xattr -cr "$(APP_DIR)" && codesign --force --deep --options runtime --sign "$(SIGN_IDENTITY)" "$(APP_DIR)"

dmg: app
	rm -rf "$(DMG_ROOT)" "$(DMG_PATH)"
	mkdir -p "$(DMG_ROOT)"
	ditto --noextattr --noqtn "$(APP_DIR)" "$(DMG_ROOT)/$(APP_NAME).app"
	ln -s /Applications "$(DMG_ROOT)/Applications"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DMG_ROOT)" -ov -format UDZO "$(DMG_PATH)"
	codesign --force --sign "$(SIGN_IDENTITY)" "$(DMG_PATH)"

run: app
	open "$(APP_DIR)"

verify: dmg
	plutil -lint "$(APP_DIR)/Contents/Info.plist"
	codesign --verify --deep --strict --verbose=2 "$(APP_DIR)"
	codesign --verify --verbose=2 "$(DMG_PATH)"
	hdiutil verify "$(DMG_PATH)"

clean:
	swift package clean
	rm -rf "$(BUILD_DIR)"
