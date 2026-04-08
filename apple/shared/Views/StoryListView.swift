import SwiftUI

struct StoryListView: View {
    @State private var stories: [Story] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading stories...")
            } else if let error = errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if stories.isEmpty {
                ContentUnavailableView("No Stories", systemImage: "book", description: Text("Create your first story to get started."))
            } else {
                List(stories) { story in
                    NavigationLink(destination: StoryDetailView(storyId: story.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(story.title)
                                .font(.headline)
                            Text(story.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Story Charts")
        .task {
            await loadStories()
        }
        .refreshable {
            await loadStories()
        }
    }

    private func loadStories() async {
        do {
            stories = try await APIClient.shared.listStories()
            isLoading = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
