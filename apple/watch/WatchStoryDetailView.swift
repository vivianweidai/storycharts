import SwiftUI

struct WatchStoryDetailView: View {
    let storyId: Int
    let title: String
    @State private var detail: StoryDetail?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let detail = detail {
                ScrollView {
                    VStack(spacing: 12) {
                        // Mini chart (read-only on watch)
                        ChartView(
                            plots: detail.plots,
                            chartPoints: detail.chartPoints,
                            isEditable: false
                        )
                        .frame(height: 140)

                        // Plot names
                        ForEach(detail.plots) { plot in
                            Text(plot.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Failed to load")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title)
        .task {
            do {
                detail = try await APIClient.shared.getStory(storyId)
            } catch {}
            isLoading = false
        }
    }
}
