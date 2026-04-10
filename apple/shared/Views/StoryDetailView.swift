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

    // Drag state
    @State private var isDragging = false

    // Edit state
    @State private var isEditingTitle = false
    @State private var editTitleText = ""
    @State private var editPlotName = ""
    @State private var editSceneLabel = ""

    @Environment(\.dismiss) private var dismiss

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
                        onPointDragged: { point, newPos in
                            if let idx = chartPoints.firstIndex(where: { $0.id == point.id }) {
                                chartPoints[idx].x_pos = Int(newPos.x)
                                chartPoints[idx].y_val = Int(newPos.y)
                            }
                            isDragging = false
                            Task { await saveAllPoints() }
                        },
                        onPointDragChanged: { point, newPos in
                            isDragging = true
                            if let idx = chartPoints.firstIndex(where: { $0.id == point.id }) {
                                chartPoints[idx].x_pos = Int(newPos.x)
                                chartPoints[idx].y_val = Int(newPos.y)
                            }
                        },
                        onDragSelected: { hl in
                            savePendingEdits()
                            stopPlayback()
                            highlightedPoint = hl
                            editPlotName = hl.plotTitle
                            editSceneLabel = hl.label
                        },
                        playX: playX,
                        highlightedPoint: highlightedPoint,
                        onPointTapped: { hl in
                            guard !isDragging else { return }
                            savePendingEdits()
                            stopPlayback()
                            if hl == highlightedPoint {
                                highlightedPoint = nil
                            } else {
                                highlightedPoint = hl
                                if let hl = hl {
                                    editPlotName = hl.plotTitle
                                    editSceneLabel = hl.label
                                }
                            }
                        }
                    )
                    .padding()

                    // Info / edit panel
                    infoPanel
                        .frame(height: detail.isOwner ?? false ? 100 : 70)
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
            if let detail = detail {
                ToolbarItem(placement: .primaryAction) {
                    if detail.isOwner ?? false {
                        Menu {
                            Button("Edit Story Name", systemImage: "pencil") {
                                editTitleText = detail.story.title
                                isEditingTitle = true
                            }
                            Button("Add Plot", systemImage: "plus.square") {
                                Task { await addPlot() }
                            }
                            Button("Add Scene", systemImage: "plus.circle") {
                                Task { await addScene() }
                            }
                            Button("Delete Story", systemImage: "trash", role: .destructive) {
                                Task { await deleteStory() }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    } else {
                        Button {
                            if isPlaying { stopPlayback() }
                            else { startPlayback() }
                        } label: {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        }
                    }
                }
            }
        }
        .alert("Edit Story Name", isPresented: $isEditingTitle) {
            TextField("Title", text: $editTitleText)
            Button("OK") { saveTitle() }
            Button("Cancel", role: .cancel) { }
        }
        .task {
            await loadStory()
            // Auto-start playback for viewers after 3 seconds
            if let d = detail, !(d.isOwner ?? false) {
                try? await Task.sleep(for: .seconds(3))
                if !isPlaying && highlightedPoint == nil {
                    startPlayback()
                }
            }
        }
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Info Panel

    @ViewBuilder
    private var infoPanel: some View {
        if let hl = highlightedPoint {
            if detail?.isOwner ?? false {
                editPanel(highlight: hl)
            } else {
                readOnlyInfoPanel(highlight: hl)
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func readOnlyInfoPanel(highlight: PointHighlight) -> some View {
        VStack(spacing: 6) {
            Text(highlight.plotTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(highlight.color)
            if !highlight.label.isEmpty {
                Text(highlight.label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func editPanel(highlight: PointHighlight) -> some View {
        VStack(spacing: 8) {
            // Row 1: Plot name + delete plot
            HStack(spacing: 8) {
                TextField("Plot name", text: $editPlotName)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(highlight.color)
                    .onSubmit { savePlotName(highlight: highlight) }

                Button(role: .destructive) {
                    Task { await deletePlot(highlight: highlight) }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            // Row 2: Scene label + delete scene
            HStack(spacing: 8) {
                TextField("Scene label", text: $editSceneLabel)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                    .onSubmit { saveSceneLabel(highlight: highlight) }

                Button(role: .destructive) {
                    Task { await deleteScene(highlight: highlight) }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Edit Actions

    private func savePendingEdits() {
        guard let hl = highlightedPoint else { return }
        // Save plot name if changed
        if editPlotName != hl.plotTitle {
            savePlotName(highlight: hl)
        }
        // Save scene label if changed
        if editSceneLabel != hl.label {
            saveSceneLabel(highlight: hl)
        }
    }

    private func saveTitle() {
        let trimmed = String(editTitleText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        let newTitle = trimmed.isEmpty ? "Untitled" : trimmed
        isEditingTitle = false
        detail?.story.title = newTitle
        Task {
            try? await APIClient.shared.updateStory(storyId, title: newTitle)
        }
    }

    private func savePlotName(highlight: PointHighlight) {
        guard let detail = detail else { return }
        guard highlight.plotIndex < detail.plots.count else { return }
        let plot = detail.plots[highlight.plotIndex]
        let trimmed = String(editPlotName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))
        guard !trimmed.isEmpty else { return }
        // Update local state
        self.detail?.plots[highlight.plotIndex].title = trimmed
        highlightedPoint = PointHighlight(
            plotIndex: highlight.plotIndex,
            pointIndex: highlight.pointIndex,
            plotTitle: trimmed,
            label: highlight.label,
            color: highlight.color
        )
        Task {
            try? await APIClient.shared.updatePlot(plot.id, title: trimmed, color: plot.color ?? -1)
        }
    }

    private func saveSceneLabel(highlight: PointHighlight) {
        guard let detail = detail else { return }
        guard highlight.plotIndex < detail.plots.count else { return }
        let plot = detail.plots[highlight.plotIndex]
        let pts = chartPoints
            .filter { $0.plot_id == plot.id }
            .sorted { $0.x_pos < $1.x_pos }
        guard highlight.pointIndex < pts.count else { return }
        let point = pts[highlight.pointIndex]
        let trimmed = String(editSceneLabel.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))

        if let idx = chartPoints.firstIndex(where: { $0.id == point.id }) {
            chartPoints[idx].label = trimmed
        }
        highlightedPoint = PointHighlight(
            plotIndex: highlight.plotIndex,
            pointIndex: highlight.pointIndex,
            plotTitle: highlight.plotTitle,
            label: trimmed,
            color: highlight.color
        )
        Task { await saveAllPoints() }
    }

    private func deletePlot(highlight: PointHighlight) async {
        guard let detail = detail else { return }
        guard highlight.plotIndex < detail.plots.count else { return }
        let plot = detail.plots[highlight.plotIndex]
        do {
            try await APIClient.shared.deletePlot(plot.id)
            highlightedPoint = nil
            await reloadStory()
        } catch {}
    }

    private func deleteScene(highlight: PointHighlight) async {
        guard let detail = detail else { return }
        guard highlight.plotIndex < detail.plots.count else { return }
        let plot = detail.plots[highlight.plotIndex]
        let pts = chartPoints
            .filter { $0.plot_id == plot.id }
            .sorted { $0.x_pos < $1.x_pos }
        guard highlight.pointIndex < pts.count else { return }
        let point = pts[highlight.pointIndex]

        chartPoints.removeAll { $0.id == point.id }
        highlightedPoint = nil
        await saveAllPoints()
    }

    private func saveAllPoints() async {
        let pts = chartPoints.map {
            ChartPointPayload(plot_id: $0.plot_id, x_pos: $0.x_pos, y_val: $0.y_val, label: $0.label)
        }
        do {
            try await APIClient.shared.saveChartPoints(storyId: storyId, points: pts)
        } catch {}
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

    private func nextFreeColor(existingPlots: [Plot]) -> Int {
        var used = Set<Int>()
        for (i, plot) in existingPlots.enumerated() {
            let c = (plot.color != nil && plot.color! >= 0) ? plot.color! % ChartView.plotColors.count : i % ChartView.plotColors.count
            used.insert(c)
        }
        for c in 0..<ChartView.plotColors.count {
            if !used.contains(c) { return c }
        }
        return existingPlots.count % ChartView.plotColors.count
    }

    private func addPlot() async {
        guard detail != nil else { return }
        let plots = detail!.plots
        guard plots.count < 10 else { return }
        let names = ["Plot A", "Plot B", "Plot C", "Plot D", "Plot E", "Plot F", "Plot G", "Plot H", "Plot I", "Plot J"]
        let name = names[plots.count % names.count]
        let color = nextFreeColor(existingPlots: plots)
        do {
            let resp = try await APIClient.shared.createPlot(storyId: storyId, title: name, color: color)
            // Add 3 random initial scenes, matching webapp behavior
            var pts = chartPoints.map { ChartPointPayload(plot_id: $0.plot_id, x_pos: $0.x_pos, y_val: $0.y_val, label: $0.label) }
            for _ in 0..<3 {
                pts.append(ChartPointPayload(plot_id: resp.id, x_pos: Int.random(in: 0...10000), y_val: Int.random(in: 0...10000), label: "New scene"))
            }
            try await APIClient.shared.saveChartPoints(storyId: storyId, points: pts)
            await reloadStory()
        } catch {}
    }

    private func addScene() async {
        guard let detail = detail else { return }
        guard chartPoints.count < 100 else { return }
        // If no plots exist, create one first
        var targetPlotId: Int
        if let hl = highlightedPoint, hl.plotIndex < detail.plots.count {
            targetPlotId = detail.plots[hl.plotIndex].id
        } else if let lastPlot = detail.plots.last {
            targetPlotId = lastPlot.id
        } else {
            do {
                let resp = try await APIClient.shared.createPlot(storyId: storyId, title: "Plot A", color: 0)
                targetPlotId = resp.id
            } catch {
                return
            }
        }
        var pts = chartPoints.map { ChartPointPayload(plot_id: $0.plot_id, x_pos: $0.x_pos, y_val: $0.y_val, label: $0.label) }
        pts.append(ChartPointPayload(plot_id: targetPlotId, x_pos: Int.random(in: 0...10000), y_val: Int.random(in: 0...10000), label: "New scene"))
        do {
            try await APIClient.shared.saveChartPoints(storyId: storyId, points: pts)
            await reloadStory()
        } catch {}
    }

    private func deleteStory() async {
        do {
            try await APIClient.shared.deleteStory(storyId)
            dismiss()
        } catch {}
    }

    private func reloadStory() async {
        do {
            let d = try await APIClient.shared.getStory(storyId)
            detail = d
            chartPoints = d.chartPoints
        } catch {}
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
