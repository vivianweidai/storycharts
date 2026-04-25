import SwiftUI

struct StoryListView: View {
    // Must match pipeline/worker/src/index.js (createStory limit) and web/index.html.
    static let maxStoriesPerUser = 30

    @EnvironmentObject var auth: AuthManager
    @ObservedObject private var blocked = BlockedUsers.shared
    @State private var stories: [StoryListItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var createdStoryId: Int?
    @State private var showDemoPrompt = false
    @State private var demoPassword = ""
    @State private var showDeleteConfirm = false
    @State private var showCapAlert = false

    private var visibleStories: [StoryListItem] {
        stories.filter { !blocked.isBlocked($0.userid) }
    }

    private var myStoryCount: Int {
        guard let email = auth.userEmail else { return 0 }
        return stories.filter { $0.userid == email }.count
    }

    private var atStoryCap: Bool { myStoryCount >= Self.maxStoriesPerUser }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading stories...")
            } else if let error = errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if visibleStories.isEmpty {
                ContentUnavailableView("No Stories", systemImage: "book", description: Text("No stories yet."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(visibleStories) { story in
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
        .navigationDestination(item: $createdStoryId) { storyId in
            StoryDetailView(storyId: storyId)
        }
        .navigationTitle("Story Charts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if auth.isAuthenticated {
                    Menu {
                        Button("Create Story", systemImage: "plus") {
                            if atStoryCap { showCapAlert = true }
                            else { Task { await createStory() } }
                        }
                        .disabled(atStoryCap)
                        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            auth.signOut()
                        }
                        Button("Delete Account", systemImage: "trash", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    } label: {
                        Label(auth.userEmail ?? "Account", systemImage: "person.crop.circle.fill")
                    }
                } else {
                    Menu {
                        Button("Sign in with email", systemImage: "person.crop.circle") {
                            Task { await signIn() }
                        }
                        Button("Demo account", systemImage: "star") {
                            demoPassword = ""
                            showDemoPrompt = true
                        }
                    } label: {
                        Label("Sign In", systemImage: "person.crop.circle")
                            .labelStyle(.titleOnly)
                    }
                }
            }
        }
        .alert("Demo Account", isPresented: $showDemoPrompt) {
            SecureField("Password", text: $demoPassword)
            Button("Sign In") {
                if demoPassword == "johnyappleseed" {
                    auth.signInAsDemo()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter the demo account password.")
        }
        .alert("Delete Account", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete your account and all your stories. This cannot be undone.")
        }
        .alert("Story Limit Reached", isPresented: $showCapAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Maximum \(Self.maxStoriesPerUser) stories per user. Delete a story to make room.")
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
            let response = try await APIClient.shared.createStory(title: "My Story")
            await loadStories()
            createdStoryId = response.id
        } catch APIError.unauthorized {
            auth.signOut()
        } catch {
            errorMessage = "Failed to create story"
        }
    }

    private func deleteAccount() async {
        do {
            try await auth.deleteAccount()
            await loadStories()
        } catch {
            errorMessage = "Failed to delete account"
        }
    }
}
