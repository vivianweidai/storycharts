import SwiftUI

struct WatchStoryDetailView: View {
    let storyId: Int
    let title: String
    @State private var detail: StoryDetail?
    @State private var isLoading = true

    // Playback state
    @State private var isPlaying = false
    @State private var playX: Int? = nil
    @State private var highlightedPoint: PointHighlight? = nil
    @State private var playTask: Task<Void, Never>? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let detail = detail {
                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 8) {
                            // Chart — fills the full visible viewport
                            // (width + height of the watch screen) so it
                            // acts as a "full screen" top section; scenes list
                            // appears below when the user scrolls.
                            ChartView(
                                plots: detail.plots,
                                chartPoints: detail.chartPoints,
                                isEditable: false,
                                playX: playX,
                                highlightedPoint: highlightedPoint
                            )
                            .frame(width: geo.size.width, height: geo.size.height)

                            // Scenes in timeline order (sorted by x_pos),
                            // not grouped by plot. Each row shows the plot's
                            // color dot + the scene label. The row for the
                            // currently-animated scene is highlighted.
                            let scenes = playbackScenes(plots: detail.plots, chartPoints: detail.chartPoints)
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(scenes.enumerated()), id: \.offset) { _, scene in
                                    let isActive = highlightedPoint?.plotIndex == scene.plotIndex
                                        && highlightedPoint?.pointIndex == scene.pointIndex
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(scene.color)
                                            .frame(width: 6, height: 6)
                                        // Keep font, weight, and color stable
                                        // across active/inactive so the row's
                                        // text metrics never change — only the
                                        // background box tints to highlight.
                                        Text(scene.label.isEmpty ? "—" : scene.label)
                                            .font(.caption2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(scene.color.opacity(isActive ? 0.22 : 0))
                                    )
                                }
                            }
                            .padding(.horizontal, 4)
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
            // Auto-start playback
            if detail != nil {
                try? await Task.sleep(for: .seconds(1))
                startPlayback()
            }
        }
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Playback

    private func startPlayback() {
        guard let detail = detail else { return }
        let scenes = playbackScenes(plots: detail.plots, chartPoints: detail.chartPoints)
        guard !scenes.isEmpty else { return }

        let segments = buildSegments(from: scenes)
        isPlaying = true
        highlightedPoint = nil

        playTask = Task { @MainActor in
            await runPlayback(
                segments: segments, fps: 30, loop: true,
                setPlayX: { playX = $0 },
                setHighlight: { highlightedPoint = $0 }
            )
            stopPlayback()
        }
    }

    private func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
        playX = nil
        highlightedPoint = nil
    }
}
