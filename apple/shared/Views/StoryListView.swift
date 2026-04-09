import SwiftUI

struct StoryListView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var stories: [StoryListItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading stories...")
            } else if let error = errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if stories.isEmpty {
                ContentUnavailableView("No Stories", systemImage: "book", description: Text("No stories yet."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(stories) { story in
                            NavigationLink(destination: StoryDetailView(storyId: story.id)) {
                                storyCard(story)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Story Charts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if auth.isAuthenticated {
                    Menu {
                        Button("Create Story", systemImage: "plus") {
                            Task { await createStory() }
                        }
                        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            auth.signOut()
                        }
                    } label: {
                        Label(auth.userEmail ?? "Account", systemImage: "person.crop.circle.fill")
                    }
                } else {
                    Button("Sign In") {
                        Task { await signIn() }
                    }
                }
            }
        }
        .task {
            await loadStories()
        }
        .refreshable {
            await loadStories()
        }
    }

    private func storyCard(_ story: StoryListItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ChartThumbnailView(plots: story.plots)
                .padding(12)

            Divider()

            Text(story.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }

    private func loadStories() async {
        do {
            stories = try await APIClient.shared.listStories()
            isLoading = false
            errorMessage = nil
        } catch {
            // If decoding fails, API might be behind CF Access still
            errorMessage = "Could not load stories"
            isLoading = false
        }
    }

    private func signIn() async {
        do {
            try await auth.signIn()
        } catch AuthError.cancelled {
            // User cancelled, do nothing
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createStory() async {
        do {
            _ = try await APIClient.shared.createStory(title: "My Story")
            // Reload to show new story
            await loadStories()
        } catch APIError.unauthorized {
            // Token expired, need to re-auth
            auth.signOut()
        } catch {
            errorMessage = "Failed to create story"
        }
    }
}
