import SwiftUI

struct WatchStoryListView: View {
    @State private var stories: [Story] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if stories.isEmpty {
                Text("No stories")
                    .foregroundStyle(.secondary)
            } else {
                List(stories) { story in
                    NavigationLink(destination: WatchStoryDetailView(storyId: story.id, title: story.title)) {
                        Text(story.title)
                            .lineLimit(2)
                    }
                }
            }
        }
        .navigationTitle("Stories")
        .task {
            do {
                stories = try await APIClient.shared.listStories()
            } catch {}
            isLoading = false
        }
    }
}
