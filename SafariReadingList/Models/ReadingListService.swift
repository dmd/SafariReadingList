import Foundation
import AppKit

class ReadingListService: ObservableObject {
    @Published var items: [ReadingListItem] = []
    private let bookmarksPath = "~/Library/Safari/Bookmarks.plist"
    private var refreshTimer: Timer?
    
    init() {
        // Load the reading list immediately
        loadReadingList()
        
        // Set up a timer to refresh every 60 seconds
        setupRefreshTimer()
    }
    
    func deleteFromReadingList(item: ReadingListItem) {
        // Remove the item from our local list
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        }
        
        // Attempt to remove the item from the plist file directly
        let expandedPath = NSString(string: bookmarksPath).expandingTildeInPath
        
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            print("Error: Safari bookmarks file not found at \(expandedPath)")
            return
        }
        
        do {
            // Read the bookmarks file
            let fileURL = URL(fileURLWithPath: expandedPath)
            let data = try Data(contentsOf: fileURL)
            
            // Parse the plist
            guard var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                  var children = plist["Children"] as? [[String: Any]] else {
                print("Error: Failed to parse Safari bookmarks plist")
                return
            }
            
            // Primary approach: Find the Reading List folder and remove the item
            var modified = false
            
            // First check the dedicated Reading List folder
            for i in 0..<children.count {
                if let title = children[i]["Title"] as? String, title == "com.apple.ReadingList",
                   var readingListChildren = children[i]["Children"] as? [[String: Any]] {
                    
                    // Find and remove the item from the Reading List children
                    let initialCount = readingListChildren.count
                    readingListChildren.removeAll { child in
                        if let urlString = child["URLString"] as? String,
                           let url = URL(string: urlString),
                           url == item.url {
                            return true
                        }
                        return false
                    }
                    
                    // If we removed items, update the plist
                    if readingListChildren.count < initialCount {
                        children[i]["Children"] = readingListChildren
                        plist["Children"] = children
                        modified = true
                    }
                    
                    break
                }
            }
            
            // If we didn't find it in the special folder, check all children (older macOS versions)
            if !modified {
                let initialCount = children.count
                children.removeAll { child in
                    if let urlString = child["URLString"] as? String,
                       let url = URL(string: urlString),
                       url == item.url,
                       child["ReadingList"] != nil {
                        return true
                    }
                    return false
                }
                
                if children.count < initialCount {
                    plist["Children"] = children
                    modified = true
                }
            }
            
            // If we modified the plist, write it back to the file
            if modified {
                let newData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try newData.write(to: fileURL)
                print("Successfully removed item from Safari Reading List plist: \(item.title)")
            } else {
                print("Item not found in Safari Reading List plist: \(item.title)")
            }
            
        } catch {
            print("Error modifying Safari bookmarks: \(error.localizedDescription)")
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    private func setupRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.loadReadingList()
        }
    }
    
    func loadReadingList() {
        print("Loading Safari reading list...")
        
        // Always read from the standard bookmarks path
        let expandedPath = NSString(string: bookmarksPath).expandingTildeInPath
        
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            print("Error: Safari bookmarks file not found at \(expandedPath)")
            loadFallbackItems()
            return
        }
        
        do {
            // Read the bookmarks file
            let fileURL = URL(fileURLWithPath: expandedPath)
            let data = try Data(contentsOf: fileURL)
            
            // Parse the plist
            guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                  let children = plist["Children"] as? [[String: Any]] else {
                print("Error: Failed to parse Safari bookmarks plist")
                loadFallbackItems()
                return
            }
            
            var newItems: [ReadingListItem] = []
            
            // Primary approach: Find the Reading List folder and extract items from it
            var foundReadingList = false
            for item in children {
                // Look for the dedicated Reading List folder/dictionary
                if let title = item["Title"] as? String, title == "com.apple.ReadingList",
                   let readingListChildren = item["Children"] as? [[String: Any]] {
                    
                    foundReadingList = true
                    
                    // Iterate through the children of the Reading List folder
                    for child in readingListChildren {
                        // Check if it's a leaf item (actual bookmark/URL)
                        if let bookmarkType = child["WebBookmarkType"] as? String, 
                           bookmarkType == "WebBookmarkTypeLeaf",
                           let urlString = child["URLString"] as? String,
                           let url = URL(string: urlString) {
                            
                            // Get the title from URIDictionary or Title
                            let title: String
                            if let uriDict = child["URIDictionary"] as? [String: Any],
                               let uriTitle = uriDict["title"] as? String {
                                title = uriTitle
                            } else if let itemTitle = child["Title"] as? String {
                                title = itemTitle
                            } else {
                                // Use URL as fallback title
                                title = urlString
                            }
                            
                            // Get the date added
                            let dateAdded: Date
                            if let readingList = child["ReadingList"] as? [String: Any],
                               let date = readingList["DateAdded"] as? Date {
                                dateAdded = date
                            } else {
                                dateAdded = Date()
                            }
                            
                            let readingListItem = ReadingListItem(
                                title: title,
                                url: url,
                                dateAdded: dateAdded
                            )
                            
                            newItems.append(readingListItem)
                        }
                    }
                    break // Found the Reading List folder, no need to check others
                }
            }
            
            // Fallback check (older macOS versions might have stored them differently)
            if !foundReadingList {
                for item in children {
                    if let bookmarkType = item["WebBookmarkType"] as? String,
                       bookmarkType == "WebBookmarkTypeLeaf",
                       let urlString = item["URLString"] as? String,
                       let url = URL(string: urlString),
                       item["ReadingList"] != nil {
                        
                        // Get the title from URIDictionary or Title
                        let title: String
                        if let uriDict = item["URIDictionary"] as? [String: Any],
                           let uriTitle = uriDict["title"] as? String {
                            title = uriTitle
                        } else if let itemTitle = item["Title"] as? String {
                            title = itemTitle
                        } else {
                            // Use URL as fallback title
                            title = urlString
                        }
                        
                        // Get the date added
                        let dateAdded: Date
                        if let readingList = item["ReadingList"] as? [String: Any],
                           let date = readingList["DateAdded"] as? Date {
                            dateAdded = date
                        } else {
                            dateAdded = Date()
                        }
                        
                        let readingListItem = ReadingListItem(
                            title: title,
                            url: url,
                            dateAdded: dateAdded
                        )
                        
                        newItems.append(readingListItem)
                    }
                }
            }
            
            // Sort by date added (newest first)
            self.items = newItems.sorted(by: { $0.dateAdded > $1.dateAdded })
            
            // Debug output
            if newItems.isEmpty {
                print("Reading list is empty (0 items found)")
                self.items = [] // Set to empty array, not fallback items
            } else {
                print("Found \(newItems.count) Reading List items")
            }
            
        } catch {
            print("Error reading Safari bookmarks: \(error.localizedDescription)")
            loadFallbackItems()
        }
    }
    
    /// Uses fallback items when there's a genuine access error
    private func loadFallbackItems() {
        print("Unable to access Safari Reading List directly. Using fallback items.")
        
        // Add fallback items to explain the access issue
        let fallbackItems = [
            ReadingListItem(
                title: "Cannot access Safari Reading List directly",
                url: URL(string: "https://developer.apple.com/documentation/security")!,
                dateAdded: Date()
            ),
            ReadingListItem(
                title: "Please ensure the app has permission to access files",
                url: URL(string: "https://developer.apple.com/macos")!,
                dateAdded: Date()
            )
        ]
        
        self.items = fallbackItems
        
        // Try to explain the error and possible solutions
        let alert = NSAlert()
        alert.messageText = "Cannot Access Safari Reading List"
        alert.informativeText = "This app needs permission to read Safari's Bookmarks.plist file. Please ensure the app has sufficient permissions or try running it from a different location."
        alert.addButton(withTitle: "OK")
        
        DispatchQueue.main.async {
            alert.runModal()
        }
    }
    
}