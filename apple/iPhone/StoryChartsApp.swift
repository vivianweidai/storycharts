import SwiftUI

@main
struct StoryChartsApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                StoryListView()
            }
        }
    }
}
