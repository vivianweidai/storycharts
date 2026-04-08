import SwiftUI

@main
struct StoryChartsWatchApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchStoryListView()
            }
        }
    }
}
