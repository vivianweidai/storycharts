import SwiftUI

struct StoryDetailView: View {
    let storyId: Int
    @State private var detail: StoryDetail?
    @State private var isLoading = true
    @State private var chartPoints: [ChartPoint] = []

    // Playback state
    @State private var isPlaying = false
    @State private var playX: Int? = nil
    @State private var highlightedPoint: PointHighlight? = nil
    @State private var playTask: Task<Void, Never>? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if let detail = detail {
                VStack(spacing: 0) {
                    ChartView(
                        plots: detail.plots,
                        chartPoints: chartPoints,
                        isEditable: detail.isOwner ?? false,
                        playX: playX,
                        highlightedPoint: highlightedPoint,
                        onPointTapped: { hl in
                            stopPlayback()
                            highlightedPoint = (hl == highlightedPoint) ? nil : hl
                        }
                    )
                    .padding()

                    // Info panel
                    infoPanel
                        .frame(height: 50)
                }
            } else {
                ContentUnavailableView("Not Found", systemImage: "questionmark", description: Text("Story could not be loaded."))
            }
        }
        .navigationTitle(detail?.story.title ?? "Story")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if detail != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if isPlaying { stopPlayback() }
                        else { startPlayback() }
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    }
                }
            }
        }
        .task {
            await loadStory()
        }
        .onDisappear {
            stopPlayback()
        }
    }

    @ViewBuilder
    private var infoPanel: some View {
        if let hl = highlightedPoint {
            VStack(spacing: 2) {
                Text(hl.plotTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(hl.color)
                if !hl.label.isEmpty {
                    Text(hl.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .transition(.opacity)
        } else {
            Color.clear
        }
    }

    // MARK: - Playback

    private func allPointsSorted() -> [(plotIndex: Int, pointIndex: Int, x: Int, label: String, plotTitle: String, color: Color)] {
        guard let detail = detail else { return [] }
        var all: [(plotIndex: Int, pointIndex: Int, x: Int, label: String, plotTitle: String, color: Color)] = []
        let chartView = ChartView(plots: detail.plots, chartPoints: chartPoints, isEditable: false)
        for (idx, plot) in detail.plots.enumerated() {
            let pts = chartPoints
                .filter { $0.plot_id == plot.id }
                .sorted { $0.x_pos < $1.x_pos }
            for (pi, pt) in pts.enumerated() {
                all.append((idx, pi, pt.x_pos, pt.label, plot.title, chartView.colorForPlot(plot, index: idx)))
            }
        }
        all.sort { $0.x < $1.x }
        return all
    }

    private func startPlayback() {
        let allPts = allPointsSorted()
        guard !allPts.isEmpty else { return }

        // If a point is selected, find its index in the sorted list to start from
        let startFromIndex: Int
        if let hl = highlightedPoint,
           let idx = allPts.firstIndex(where: { $0.plotIndex == hl.plotIndex && $0.pointIndex == hl.pointIndex }) {
            startFromIndex = idx
        } else {
            startFromIndex = 0
        }

        isPlaying = true
        highlightedPoint = nil

        playTask = Task { @MainActor in
            let sweepMs: Double = 1500 // sweep between TPs (for full 0-10000 range)
            let pauseMin: Double = 2.0
            let pauseMax: Double = 4.0

            func pauseDuration(_ label: String) -> Double {
                let t = min(Double(label.count) / 60.0, 1.0)
                return pauseMin + t * (pauseMax - pauseMin)
            }

            // Build segments: sweep to each point, pause, then sweep to next
            struct Segment {
                let startX: Int
                let endX: Int
                let point: (plotIndex: Int, pointIndex: Int, x: Int, label: String, plotTitle: String, color: Color)?
                let sweepDuration: Double
                let pauseDuration: Double
            }

            var segments: [Segment] = []

            // First segment: sweep from starting x to the first point in range
            let startX = startFromIndex > 0 ? allPts[startFromIndex].x : 0
            let first = allPts[startFromIndex]
            let firstSweep = startFromIndex > 0 ? 0.0 : sweepMs * (Double(first.x) / 10000.0)
            segments.append(Segment(startX: startX, endX: first.x, point: first, sweepDuration: firstSweep, pauseDuration: pauseDuration(first.label)))

            // Between remaining points
            for i in (startFromIndex + 1)..<allPts.count {
                let dist = Double(allPts[i].x - allPts[i-1].x)
                let sweep = sweepMs * (dist / 10000.0)
                segments.append(Segment(startX: allPts[i-1].x, endX: allPts[i].x, point: allPts[i], sweepDuration: sweep, pauseDuration: pauseDuration(allPts[i].label)))
            }

            // Final sweep to end
            let lastX = allPts.last!.x
            if lastX < 10000 {
                let sweep = sweepMs * (Double(10000 - lastX) / 10000.0)
                segments.append(Segment(startX: lastX, endX: 10000, point: nil, sweepDuration: sweep, pauseDuration: 0))
            }

            let fps: Double = 60
            let frameDuration = 1.0 / fps

            for seg in segments {
                guard !Task.isCancelled else { break }

                // Sweep phase
                if seg.sweepDuration > 0 {
                    let frames = max(1, Int(seg.sweepDuration / 1000.0 * fps))
                    for f in 0...frames {
                        guard !Task.isCancelled else { break }
                        let t = Double(f) / Double(frames)
                        playX = seg.startX + Int(Double(seg.endX - seg.startX) * t)
                        highlightedPoint = nil
                        try? await Task.sleep(for: .seconds(frameDuration))
                    }
                }

                guard !Task.isCancelled else { break }

                // Pause at point
                if let pt = seg.point {
                    playX = seg.endX
                    highlightedPoint = PointHighlight(
                        plotIndex: pt.plotIndex,
                        pointIndex: pt.pointIndex,
                        plotTitle: pt.plotTitle,
                        label: pt.label,
                        color: pt.color
                    )
                    try? await Task.sleep(for: .seconds(seg.pauseDuration))
                }
            }

            stopPlayback()
        }
    }

    private func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
        playX = nil
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
