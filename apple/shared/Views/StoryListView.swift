import SwiftUI

struct StoryListView: View {
    @EnvironmentObject var auth: AuthManager
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
                ContentUnavailableView("No Stories", systemImage: "book", description: Text("No stories yet."))
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
            let result = try await APIClient.shared.createStory(title: "My Story")
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
