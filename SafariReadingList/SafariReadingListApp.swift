import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let readingListService = ReadingListService()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusBarDelegate = StatusBarDelegate()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupApp()
    }
    
    func setupApp() {
        // Set up the status bar menu
        setupStatusBar()
        
        // Load the reading list when the app starts
        DispatchQueue.main.async { [weak self] in
            self?.readingListService.loadReadingList()
        }
        
        // NOTE: The ReadingListService now handles its own timer (refreshes every 60 seconds)
    }
    
    private func setupStatusBar() {
        if let button = statusItem.button {
            // Create a fallback icon since systemSymbolName might not be available on older systems
            if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: "bookmark.fill", accessibilityDescription: "Safari Reading List")
            } else {
                // Fallback for older macOS versions - create a simple template image
                let bookmarkImage = NSImage(named: NSImage.bookmarksTemplateName)
                bookmarkImage?.isTemplate = true
                button.image = bookmarkImage
            }
        }
        
        statusBarDelegate.readingListService = readingListService
        
        let menu = NSMenu()
        menu.delegate = statusBarDelegate
        statusItem.menu = menu
    }
}

@main
struct SafariReadingListApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {}
    }
}

class StatusBarDelegate: NSObject, NSMenuDelegate {
    var readingListService: ReadingListService?
    
    func menuWillOpen(_ menu: NSMenu) {
        // Clear all items
        menu.removeAllItems()
        
        guard let readingListService = readingListService else { return }
        
        if readingListService.items.isEmpty {
            menu.addItem(NSMenuItem(title: "Your Safari reading list is empty", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Add items using Safari's share button", action: nil, keyEquivalent: ""))
        } else {
            // Add each reading list item
            for item in readingListService.items {
                let menuItem = NSMenuItem(title: item.title, action: #selector(openURL(_:)), keyEquivalent: "")
                menuItem.representedObject = item
                menuItem.target = self
                
                // Enable right-click menu for deletion
                let submenu = NSMenu()
                let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteReadingListItem(_:)), keyEquivalent: "")
                deleteItem.target = self
                deleteItem.representedObject = item
                submenu.addItem(deleteItem)
                menuItem.submenu = submenu
                
                // Add subtitle with URL domain for context
                if let host = item.url.host {
                    menuItem.indentationLevel = 1
                    let domainItem = NSMenuItem(title: "  \(host)", action: nil, keyEquivalent: "")
                    domainItem.isEnabled = false
                    domainItem.indentationLevel = 2
                    domainItem.attributedTitle = NSAttributedString(string: "  \(host)", attributes: [
                        .font: NSFont.systemFont(ofSize: 10),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ])
                    menu.addItem(menuItem)
                    menu.addItem(domainItem)
                } else {
                    menu.addItem(menuItem)
                }
            }
        }
        
        // Add separator and actions
        menu.addItem(NSMenuItem.separator())
        
        // Refresh menu item
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshReadingList), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        // Quit menu item
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @objc func openURL(_ sender: NSMenuItem) {
        if let item = sender.representedObject as? ReadingListItem {
            NSWorkspace.shared.open(item.url)
        }
    }
    
    @objc func refreshReadingList() {
        readingListService?.loadReadingList()
    }
    
    @objc func deleteReadingListItem(_ sender: NSMenuItem) {
        if let item = sender.representedObject as? ReadingListItem {
            readingListService?.deleteFromReadingList(item: item)
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}