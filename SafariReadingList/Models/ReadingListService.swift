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
            promptForBookmarksFileToDelete(item: item)
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
            
            // Check if error is permission/access related
            if error is CocoaError, (error as NSError).domain == NSCocoaErrorDomain {
                let errorCode = (error as NSError).code
                if errorCode == NSFileReadNoPermissionError || 
                   errorCode == NSFileReadUnknownError ||
                   errorCode == NSFileWriteNoPermissionError {
                    // This is likely a permissions error
                    promptForBookmarksFileToDelete(item: item)
                    return
                }
            }
            
            // Show an alert about the error
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Error Removing Item"
                alert.informativeText = "Could not remove the item from Safari's Reading List: \(error.localizedDescription)"
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    /// Prompts the user to manually select the Safari Bookmarks.plist file for deletion
    private func promptForBookmarksFileToDelete(item: ReadingListItem) {
        print("Prompting user to select Safari Bookmarks.plist file for deletion...")
        
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.canChooseDirectories = false
            openPanel.allowsMultipleSelection = false
            openPanel.allowedFileTypes = ["plist"]
            openPanel.message = "Please select Safari's Bookmarks.plist file to delete this item"
            openPanel.prompt = "Select"
            openPanel.directoryURL = URL(fileURLWithPath: "/Library/Safari")
            
            if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
                print("User selected Bookmarks file for deletion: \(selectedURL.path)")
                self.processSelectedBookmarksFileForDeletion(selectedURL, item: item)
            } else {
                print("User cancelled Bookmarks file selection for deletion")
                
                // Show an alert that the item couldn't be removed from Safari
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Item Not Removed"
                    alert.informativeText = "The item was removed from the app, but could not be removed from Safari's Reading List."
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
    
    /// Process a manually selected Bookmarks.plist file for deletion
    private func processSelectedBookmarksFileForDeletion(_ fileURL: URL, item: ReadingListItem) {
        do {
            // Read the bookmarks file
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
                
                // Show success message
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Item Removed"
                    alert.informativeText = "The item was successfully removed from Safari's Reading List."
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            } else {
                print("Item not found in Safari Reading List plist: \(item.title)")
                
                // Show not found message
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Item Not Found"
                    alert.informativeText = "The item was not found in Safari's Reading List."
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
            
        } catch {
            print("Error modifying selected Safari bookmarks: \(error.localizedDescription)")
            
            // Show an alert about the error
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Error Removing Item"
                alert.informativeText = "Could not remove the item from Safari's Reading List: \(error.localizedDescription)"
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
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
            promptForBookmarksFile()
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
            // Check if error is permission/access related
            if error is CocoaError, (error as NSError).domain == NSCocoaErrorDomain {
                let errorCode = (error as NSError).code
                if errorCode == NSFileReadNoPermissionError || 
                   errorCode == NSFileReadUnknownError {
                    // This is likely a permissions error
                    promptForBookmarksFile()
                    return
                }
            }
            loadFallbackItems()
        }
    }
    
    /// Shows alert about permissions error
    private func loadFallbackItems() {
        print("Unable to access Safari Reading List directly.")
        
        // Set empty items list
        self.items = []
        
        // Explain the error and provide fix instructions
        let alert = NSAlert()
        alert.messageText = "Cannot Access Safari Reading List"
        alert.informativeText = "The app needs special permission to access Safari's bookmarks. This requires a temporary entitlement in the app's code. Please rebuild the app using Xcode with the updated entitlements file."
        alert.addButton(withTitle: "OK")
        
        DispatchQueue.main.async {
            alert.runModal()
        }
    }
    
    /// Prompts the user to manually select the Safari Bookmarks.plist file
    private func promptForBookmarksFile() {
        print("Prompting user to select Safari Bookmarks.plist file...")
        
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.canChooseDirectories = false
            openPanel.allowsMultipleSelection = false
            openPanel.allowedFileTypes = ["plist"]
            openPanel.message = "Please select Safari's Bookmarks.plist file"
            openPanel.prompt = "Select"
            openPanel.directoryURL = URL(fileURLWithPath: "/Library/Safari")
            
            if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
                print("User selected Bookmarks file: \(selectedURL.path)")
                self.processSelectedBookmarksFile(selectedURL)
            } else {
                print("User cancelled Bookmarks file selection")
                self.loadFallbackItems()
            }
        }
    }
    
    /// Process a manually selected Bookmarks.plist file
    private func processSelectedBookmarksFile(_ fileURL: URL) {
        do {
            // Read the bookmarks file
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
            print("Error reading selected Safari bookmarks: \(error.localizedDescription)")
            loadFallbackItems()
        }
    }
}