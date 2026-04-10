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
                            // Chart — fills the full visible viewport so it
                            // acts as a "full screen" top section; scenes list
                            // appears below when the user scrolls.
                            ChartView(
                                plots: detail.plots,
                                chartPoints: detail.chartPoints,
                                isEditable: false,
                                playX: playX,
                                highlightedPoint: highlightedPoint
                            )
                            .frame(height: geo.size.height)

                            // Scenes in timeline order (sorted by x_pos),
                            // not grouped by plot. Each row shows the plot's
                            // color dot + the scene label. The row for the
                            // currently-animated scene is highlighted.
                            let timeline = timelineScenes(detail: detail)
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(timeline, id: \.scene.id) { item in
                                    let isActive = highlightedPoint?.plotIndex == item.plotIndex
                                        && highlightedPoint?.pointIndex == item.pointIndexInPlot
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(item.color)
                                            .frame(width: 6, height: 6)
                                        Text(item.scene.label.isEmpty ? "—" : item.scene.label)
                                            .font(.caption2)
                                            .fontWeight(isActive ? .bold : .regular)
                                            .foregroundStyle(isActive ? item.color : .primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(item.color.opacity(isActive ? 0.2 : 0))
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

    private func plotColorIndex(_ plot: Plot, index: Int) -> Int {
        guard let plots = detail?.plots else { return index % ChartView.plotColors.count }
        return ChartView.resolvedColorIndex(plots: plots, at: index)
    }

    // MARK: - Timeline scene list

    private struct TimelineItem {
        let scene: ChartPoint
        let plotIndex: Int
        let pointIndexInPlot: Int
        let color: Color
    }

    // Flat list of all scenes sorted by x_pos (timeline order), each tagged
    // with the plot index and its index *within that plot's scene list* so
    // it can be matched against the playback highlightedPoint.
    private func timelineScenes(detail: StoryDetail) -> [TimelineItem] {
        var items: [TimelineItem] = []
        for (pIdx, plot) in detail.plots.enumerated() {
            let sortedInPlot = detail.chartPoints
                .filter { $0.plot_id == plot.id }
                .sorted { $0.x_pos < $1.x_pos }
            let color = ChartView.plotColors[plotColorIndex(plot, index: pIdx)]
            for (sIdx, scene) in sortedInPlot.enumerated() {
                items.append(TimelineItem(scene: scene, plotIndex: pIdx, pointIndexInPlot: sIdx, color: color))
            }
        }
        items.sort { $0.scene.x_pos < $1.scene.x_pos }
        return items
    }

    // MARK: - Playback

    private func allPointsSorted() -> [(plotIndex: Int, pointIndex: Int, x: Int, label: String, plotTitle: String, color: Color)] {
        guard let detail = detail else { return [] }
        var all: [(plotIndex: Int, pointIndex: Int, x: Int, label: String, plotTitle: String, color: Color)] = []
        for (idx, plot) in detail.plots.enumerated() {
            let pts = detail.chartPoints
                .filter { $0.plot_id == plot.id }
                .sorted { $0.x_pos < $1.x_pos }
            let color = ChartView.plotColors[plotColorIndex(plot, index: idx)]
            for (pi, pt) in pts.enumerated() {
                all.append((idx, pi, pt.x_pos, pt.label, plot.title, color))
            }
        }
        all.sort { $0.x < $1.x }
        return all
    }

    private func startPlayback() {
        let allPts = allPointsSorted()
        guard !allPts.isEmpty else { return }

        isPlaying = true
        highlightedPoint = nil

        playTask = Task { @MainActor in
            let sweepMs: Double = 1500
            let pauseMin: Double = 2.0
            let pauseMax: Double = 4.0

            func pauseDuration(_ label: String) -> Double {
                let t = min(Double(label.count) / 60.0, 1.0)
                return pauseMin + t * (pauseMax - pauseMin)
            }

            struct Segment {
                let startX: Int
                let endX: Int
                let point: (plotIndex: Int, pointIndex: Int, x: Int, label: String, plotTitle: String, color: Color)?
                let sweepDuration: Double
                let pauseDuration: Double
            }

            var segments: [Segment] = []

            let first = allPts[0]
            let firstSweep = sweepMs * (Double(first.x) / 10000.0)
            segments.append(Segment(startX: 0, endX: first.x, point: first, sweepDuration: firstSweep, pauseDuration: pauseDuration(first.label)))

            for i in 1..<allPts.count {
                let dist = Double(allPts[i].x - allPts[i-1].x)
                let sweep = sweepMs * (dist / 10000.0)
                segments.append(Segment(startX: allPts[i-1].x, endX: allPts[i].x, point: allPts[i], sweepDuration: sweep, pauseDuration: pauseDuration(allPts[i].label)))
            }

            let lastX = allPts.last!.x
            if lastX < 10000 {
                let sweep = sweepMs * (Double(10000 - lastX) / 10000.0)
                segments.append(Segment(startX: lastX, endX: 10000, point: nil, sweepDuration: sweep, pauseDuration: 0))
            }

            let fps: Double = 30 // Lower FPS for watch performance
            let frameDuration = 1.0 / fps
            let loopPause: Double = 1.5 // beat between loop iterations

            // Loop the full sweep-and-highlight cycle until the task is
            // cancelled (navigating away or stopPlayback).
            while !Task.isCancelled {
                for seg in segments {
                    guard !Task.isCancelled else { break }

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

                guard !Task.isCancelled else { break }
                // Brief reset before the next loop so the start is visible.
                playX = nil
                highlightedPoint = nil
                try? await Task.sleep(for: .seconds(loopPause))
            }

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
