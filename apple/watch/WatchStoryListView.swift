import SwiftUI

struct WatchStoryListView: View {
    @ObservedObject private var blocked = BlockedUsers.shared
    @State private var stories: [StoryListItem] = []
    @State private var isLoading = true

    private var visibleStories: [StoryListItem] {
        stories.filter { !blocked.isBlocked($0.userid) }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if visibleStories.isEmpty {
                Text("No stories")
                    .foregroundStyle(.secondary)
            } else {
                List(visibleStories) { story in
                    NavigationLink(destination: WatchStoryDetailView(storyId: story.id, title: story.title)) {
                        Text(story.title)
                            .lineLimit(2)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            blocked.block(story.userid)
                        } label: {
                            Label("Block User", systemImage: "hand.raised")
                        }
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
