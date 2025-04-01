# Safari Reading List Menu Bar App

A simple macOS menu bar app that displays your Safari Reading List items and lets you open them directly from the menu.

## Features

- Shows your Safari Reading List in the menu bar
- Opens articles in your default browser when clicked
- Add URLs to your Safari Reading List
- Displays domain names under each item
- **Auto-refreshes every 60 seconds**
- Manual refresh option

## Requirements

- macOS 11.0 or later
- Xcode 13.0 or later

## Building and Running

1. Open the project in Xcode
2. Select your target device (macOS)
3. Build and run (⌘+R)

## Usage

After launching the app, you'll see a bookmark icon in your menu bar. Click it to see your Safari Reading List. Click on any item to open it in your default browser.

### Accessing Safari Reading List

The app directly reads Safari's Bookmarks.plist file at `~/Library/Safari/Bookmarks.plist`. Due to macOS security restrictions, you may need to grant permission for the app to access files on your system. This typically happens automatically when you run the app from Xcode.

### Additional Features

- **Auto-refresh**: The reading list automatically updates every 60 seconds to stay in sync with Safari
- **Manual Refresh**: Click the "Refresh" menu item to immediately update the reading list
- **Add to Reading List**: Add new URLs to your Safari reading list using the app's "Add Current URL to Reading List" menu option

## Privacy

This app does not transmit any data externally. All operations are performed locally on your Mac.