# Safari Reading List Menu Bar App - Development Guide

## Build & Run Commands
- Open project in Xcode: `open SafariReadingList/SafariReadingList.xcodeproj`
- Build and run: ⌘+R in Xcode
- Archive for distribution: Product > Archive in Xcode
- Clean build: ⌘+Shift+K in Xcode

## Code Style Guidelines
- **Imports**: Group imports (Foundation, SwiftUI, AppKit) at the top, with system frameworks first
- **Formatting**: 4-space indentation, no trailing whitespace
- **Types**: Use Swift's strong type system, prefer structs for models (ReadingListItem)
- **Naming**: Use descriptive camelCase for variables/functions, CapitalCase for types
- **Error Handling**: Use do/catch with descriptive error messages, provide fallbacks when possible
- **Architecture**: Follow Observable/Publisher pattern for data services
- **Documentation**: Use /// for function and property documentation
- **File Structure**: Organize by Models/, Views/ directories

## Best Practices
- Prefer weak self in closures to prevent memory leaks
- Use guard for early returns and unwrapping optionals
- Check file permissions before attempting file operations
- For UI changes, update on the main thread (DispatchQueue.main.async)
- Use a 60-second refresh timer for reading list data