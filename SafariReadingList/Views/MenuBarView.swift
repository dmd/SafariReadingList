import SwiftUI

// This file is no longer used since we switched to AppKit for the menu bar
// Kept for reference in case we want to use SwiftUI again in the future

struct MenuBarView: View {
    @ObservedObject var readingListService: ReadingListService
    
    var body: some View {
        VStack {
            if readingListService.items.isEmpty {
                Text("Your reading list is empty")
                    .padding()
            } else {
                List {
                    ForEach(readingListService.items) { item in
                        Button(action: {
                            item.open()
                        }) {
                            VStack(alignment: .leading) {
                                Text(item.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(item.url.absoluteString)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            Divider()
            
            Button(action: {
                readingListService.loadReadingList()
            }) {
                Text("Refresh")
            }
            .padding(.vertical, 5)
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
            }
            .padding(.vertical, 5)
        }
        .frame(width: 300, height: 400)
    }
}