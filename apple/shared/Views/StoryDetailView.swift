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
                    .aspectRatio(1, contentMode: .fit)
                    .padding()

                    // Info / edit panel
                    infoPanel
                        .frame(height: detail.isOwner ?? false ? 108 : 78)
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
                            Button("Change Title", systemImage: "pencil") {
                                editTitleText = detail.story.title
                                isEditingTitle = true
                            }
                            Button("Add Plot", systemImage: "plus.square") {
                                Task { await addPlot() }
                            }
                            .disabled(detail.plots.count >= 10)
                            Button("Add Scene", systemImage: "plus.circle") {
                                Task { await addScene() }
                            }
                            .disabled(chartPoints.count >= 100 || detail.plots.isEmpty)
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
        VStack(spacing: 12) {
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
        VStack(spacing: 14) {
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
        // Preserve the plot's color on rename; if somehow still unassigned,
        // resolve to the next free index so we never write -1 back.
        let colorToSave = (plot.color ?? -1) >= 0
            ? plot.color!
            : ChartView.resolvedColorIndex(plots: detail.plots, at: highlight.plotIndex)
        Task {
            try? await APIClient.shared.updatePlot(plot.id, title: trimmed, color: colorToSave)
        }
    }

    private func saveSceneLabel(highlight: PointHighlight) {
        guard let detail = detail else { return }
        guard highlight.plotIndex < detail.plots.count else { return }
        let plot = detail.plots[highlight.plotIndex]
        let pts = chartPoints.scenes(for: plot.id)
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
        let pts = chartPoints.scenes(for: plot.id)
        guard highlight.pointIndex < pts.count else { return }
        let point = pts[highlight.pointIndex]

        chartPoints.removeAll { $0.id == point.id }
        highlightedPoint = nil
        await saveAllPoints()
    }

    private var pointPayloads: [ChartPointPayload] {
        chartPoints.map {
            ChartPointPayload(plot_id: $0.plot_id, x_pos: $0.x_pos, y_val: $0.y_val, label: $0.label)
        }
    }

    private func saveAllPoints() async {
        try? await APIClient.shared.saveChartPoints(storyId: storyId, points: pointPayloads)
    }

    // MARK: - Playback

    private func startPlayback() {
        guard let detail = detail else { return }
        let scenes = playbackScenes(plots: detail.plots, chartPoints: chartPoints)
        guard !scenes.isEmpty else { return }

        // If a point is selected, resume playback from its position.
        let startIdx = highlightedPoint
            .flatMap { hl in scenes.firstIndex { $0.plotIndex == hl.plotIndex && $0.pointIndex == hl.pointIndex } }
            ?? 0

        let segments = buildSegments(from: scenes, startingAt: startIdx)
        isPlaying = true
        highlightedPoint = nil

        playTask = Task { @MainActor in
            await runPlayback(
                segments: segments, fps: 60, loop: false,
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
    }

    private func nextFreeColor(existingPlots: [Plot]) -> Int {
        // Resolve the effective color index of every existing plot, then
        // return the smallest color index not among them.
        let used = Set(ChartView.resolveColorIndices(colors: existingPlots.map { $0.color }))
        return (0..<ChartView.plotColors.count).first(where: { !used.contains($0) })
            ?? (existingPlots.count % ChartView.plotColors.count)
    }

    private static let plotNames = ["Plot A", "Plot B", "Plot C", "Plot D", "Plot E", "Plot F", "Plot G", "Plot H", "Plot I", "Plot J"]

    private func newScenePayload(plotId: Int) -> ChartPointPayload {
        ChartPointPayload(plot_id: plotId,
                          x_pos: Int.random(in: 0...10000),
                          y_val: Int.random(in: 0...10000),
                          label: "New scene")
    }

    private func addPlot() async {
        guard let detail = detail, detail.plots.count < 10 else { return }
        let name = Self.plotNames[detail.plots.count % Self.plotNames.count]
        let color = nextFreeColor(existingPlots: detail.plots)
        do {
            let resp = try await APIClient.shared.createPlot(storyId: storyId, title: name, color: color)
            // Seed 3 random initial scenes on the new plot, matching webapp.
            var pts = pointPayloads
            for _ in 0..<3 { pts.append(newScenePayload(plotId: resp.id)) }
            try await APIClient.shared.saveChartPoints(storyId: storyId, points: pts)
            await reloadStory()
        } catch {}
    }

    private func addScene() async {
        guard let detail = detail, chartPoints.count < 100 else { return }
        // Target plot: the highlighted one, else the last plot, else create one.
        let targetPlotId: Int
        if let hl = highlightedPoint, hl.plotIndex < detail.plots.count {
            targetPlotId = detail.plots[hl.plotIndex].id
        } else if let last = detail.plots.last {
            targetPlotId = last.id
        } else {
            guard let resp = try? await APIClient.shared.createPlot(storyId: storyId, title: "Plot A", color: 0) else { return }
            targetPlotId = resp.id
        }
        var pts = pointPayloads
        pts.append(newScenePayload(plotId: targetPlotId))
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

    private func reloadStory() async { await loadStory(resetLoadingFlag: false) }

    private func loadStory(resetLoadingFlag: Bool = true) async {
        do {
            let d = try await APIClient.shared.getStory(storyId)
            detail = d
            chartPoints = d.chartPoints
            if resetLoadingFlag { isLoading = false }
            await lockInPlotColors()
        } catch {
            if resetLoadingFlag { isLoading = false }
        }
    }

    // Persist an explicit color for any plot that still has nil/-1, so that
    // colors are stable across future renders and deletions. Runs after every
    // load; a no-op when all plots already have explicit colors.
    private func lockInPlotColors() async {
        guard var current = detail else { return }
        guard current.plots.contains(where: { ($0.color ?? -1) < 0 }) else { return }
        guard current.isOwner ?? false else { return }
        for i in 0..<current.plots.count {
            let plot = current.plots[i]
            if (plot.color ?? -1) < 0 {
                let resolved = ChartView.resolvedColorIndex(plots: current.plots, at: i)
                do {
                    try await APIClient.shared.updatePlot(plot.id, title: plot.title, color: resolved)
                    current.plots[i].color = resolved
                } catch {}
            }
        }
        detail = current
    }
}
