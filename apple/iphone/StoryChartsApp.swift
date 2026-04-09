import SwiftUI

@main
struct StoryChartsApp: App {
    @StateObject private var auth = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                StoryListView()
            }
            .environmentObject(auth)
        }
    }
}
