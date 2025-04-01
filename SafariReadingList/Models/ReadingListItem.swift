import Foundation
import AppKit

struct ReadingListItem: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    let dateAdded: Date
    
    func open() {
        NSWorkspace.shared.open(url)
    }
}