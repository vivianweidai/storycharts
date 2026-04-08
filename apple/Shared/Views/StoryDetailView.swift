import SwiftUI

struct StoryDetailView: View {
    let storyId: Int
    @State private var detail: StoryDetail?
    @State private var isLoading = true
    @State private var chartPoints: [ChartPoint] = []

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if let detail = detail {
                ScrollView {
                    VStack(spacing: 20) {
                        ChartView(
                            plots: detail.plots,
                            chartPoints: chartPoints,
                            isEditable: detail.isOwner,
                            onPointDragged: { point, location in
                                handleDrag(point: point, location: location)
                            }
                        )
                        .padding()

                        // Legend
                        legendSection(detail: detail)

                        // Plot details
                        plotsSection(detail: detail)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("Not Found", systemImage: "questionmark", description: Text("Story could not be loaded."))
            }
        }
        .navigationTitle(detail?.story.title ?? "Story")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadStory()
        }
    }

    private func legendSection(detail: StoryDetail) -> some View {
        let colors: [Color] = [.blue, .red, .green, .orange, .purple, .cyan]
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(detail.plots.enumerated()), id: \.element.id) { idx, plot in
                HStack(spacing: 8) {
                    Circle()
                        .fill(colors[idx % colors.count])
                        .frame(width: 10, height: 10)
                    Text(plot.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
    }

    private func plotsSection(detail: StoryDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(detail.plots) { plot in
                VStack(alignment: .leading, spacing: 4) {
                    Text(plot.title)
                        .font(.headline)
                    if !plot.description.isEmpty {
                        Text(plot.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    let points = chartPoints
                        .filter { $0.plot_id == plot.id }
                        .sorted { $0.x_pos < $1.x_pos }

                    if !points.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(points) { pt in
                                    if !pt.label.isEmpty {
                                        Text(pt.label)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.quaternary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func handleDrag(point: ChartPoint, location: CGPoint) {
        // TODO: convert screen coordinates back to 0-10000 range and update
    }

    private func loadStory() async {
        do {
            let d = try await APIClient.shared.getStory(storyId)
            detail = d
            chartPoints = d.chartPoints
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}
