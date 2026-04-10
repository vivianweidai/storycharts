import SwiftUI

// Represents a highlighted point (plot index + point index)
struct PointHighlight: Equatable {
    let plotIndex: Int
    let pointIndex: Int
    let plotTitle: String
    let label: String
    let color: Color
}

struct ChartView: View {
    let plots: [Plot]
    let chartPoints: [ChartPoint]
    let isEditable: Bool
    var onPointDragged: ((ChartPoint, CGPoint) -> Void)?
    var onPointDragChanged: ((ChartPoint, CGPoint) -> Void)?
    var onDragSelected: ((PointHighlight) -> Void)?

    // Playback / tap state — driven by parent
    var playX: Int? = nil  // 0-10000, vertical sweep line position
    var highlightedPoint: PointHighlight? = nil
    var onPointTapped: ((PointHighlight?) -> Void)? = nil

    static let plotColors: [Color] = [
        Color(red: 0.29, green: 0.50, blue: 0.83),
        Color(red: 0.88, green: 0.38, blue: 0.25),
        Color(red: 0.31, green: 0.63, blue: 0.25),
        Color(red: 0.83, green: 0.63, blue: 0.13),
        Color(red: 0.56, green: 0.38, blue: 0.75),
        Color(red: 0.16, green: 0.62, blue: 0.56),
        Color(red: 0.88, green: 0.44, blue: 0.60),
        Color(red: 0.54, green: 0.40, blue: 0.25),
        Color(red: 0.31, green: 0.31, blue: 0.69),
        Color(red: 0.88, green: 0.50, blue: 0.31),
    ]
    private let gridCount = 20
    private let inset: CGFloat = 0.05 // 5% padding inside chart edges
    private let snapThresholdPx: CGFloat = 14 // drag x-snap tolerance (touch-friendly)
    @State private var isDragging = false
    @State private var snappedX: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            ZStack {
                gridBackground(size: s)
                midline(size: s)
                if let px = playX {
                    sweepLine(size: s, x: px)
                }
                if let hl = highlightedPoint {
                    halo(size: s, highlight: hl)
                }
                if isDragging, let sx = snappedX {
                    snapGuide(size: s, x: sx)
                }
                plotLines(size: s)
                plotDots(size: s)
            }
            .frame(width: s.width, height: s.height)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isEditable ? Color.blue.opacity(0.5) : Color(red: 0.55, green: 0.7, blue: 0.75).opacity(0.5), lineWidth: 1.5)
            )
            .coordinateSpace(name: "chart")
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard !isDragging else { return }
                handleTap(at: location, chartSize: s)
            }
        }
        // Callers apply .aspectRatio(1, contentMode: .fit) when they want
        // a square chart (iPhone editor). Watch leaves it unconstrained
        // so the chart can fill a non-square viewport.
    }

    private func handleTap(at location: CGPoint, chartSize: CGSize) {
        let hitRadius: CGFloat = 30
        var bestDist: CGFloat = hitRadius
        var bestHL: PointHighlight? = nil

        for (idx, plot) in plots.enumerated() {
            let pts = chartPoints
                .filter { $0.plot_id == plot.id }
                .sorted { $0.x_pos < $1.x_pos }

            for (pi, pt) in pts.enumerated() {
                let pos = chartPosition(pt, in: chartSize)
                let dist = hypot(location.x - pos.x, location.y - pos.y)
                if dist < bestDist {
                    bestDist = dist
                    bestHL = PointHighlight(
                        plotIndex: idx,
                        pointIndex: pi,
                        plotTitle: plot.title,
                        label: pt.label,
                        color: colorForPlot(plot, index: idx)
                    )
                }
            }
        }
        onPointTapped?(bestHL)
    }

    private func sweepLine(size: CGSize, x: Int) -> some View {
        let padX = size.width * inset
        let innerW = size.width - 2 * padX
        let px = padX + CGFloat(x) / 10000.0 * innerW
        return Path { path in
            path.move(to: CGPoint(x: px, y: 0))
            path.addLine(to: CGPoint(x: px, y: size.height))
        }
        .stroke(Color.blue.opacity(0.35), lineWidth: 1)
    }

    private func snapGuide(size: CGSize, x: Int) -> some View {
        let padX = size.width * inset
        let padY = size.height * inset
        let innerW = size.width - 2 * padX
        let px = padX + CGFloat(x) / 10000.0 * innerW
        return Path { path in
            path.move(to: CGPoint(x: px, y: padY))
            path.addLine(to: CGPoint(x: px, y: size.height - padY))
        }
        .stroke(Color(red: 0.04, green: 0.41, blue: 0.85).opacity(0.35), lineWidth: 1)
    }

    private func halo(size: CGSize, highlight: PointHighlight) -> some View {
        let plot = plots[highlight.plotIndex]
        let pts = chartPoints
            .filter { $0.plot_id == plot.id }
            .sorted { $0.x_pos < $1.x_pos }
        guard highlight.pointIndex < pts.count else { return AnyView(EmptyView()) }
        let pos = chartPosition(pts[highlight.pointIndex], in: size)
        let color = highlight.color
        return AnyView(
            Circle()
                .fill(color.opacity(0.08))
                .overlay(Circle().stroke(color.opacity(0.25), lineWidth: 1.5))
                .frame(width: 44, height: 44)
                .position(pos)
        )
    }

    private func gridBackground(size: CGSize) -> some View {
        Canvas { ctx, _ in
            let hStep = size.width / CGFloat(gridCount)
            let vStep = size.height / CGFloat(gridCount)
            let gridColor = Color(red: 0.85, green: 0.9, blue: 0.95)
            for i in 0...gridCount {
                let y = CGFloat(i) * vStep
                var hPath = Path()
                hPath.move(to: CGPoint(x: 0, y: y))
                hPath.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(hPath, with: .color(gridColor), lineWidth: 0.5)
                let x = CGFloat(i) * hStep
                var vPath = Path()
                vPath.move(to: CGPoint(x: x, y: 0))
                vPath.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(vPath, with: .color(gridColor), lineWidth: 0.5)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color(red: 0.97, green: 0.98, blue: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func midline(size: CGSize) -> some View {
        let padY = size.height * inset
        let innerH = size.height - 2 * padY
        let midY = padY + innerH / 2
        return Path { path in
            path.move(to: CGPoint(x: 0, y: midY))
            path.addLine(to: CGPoint(x: size.width, y: midY))
        }
        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
    }

    func colorForPlot(_ plot: Plot, index: Int) -> Color {
        return Self.plotColors[Self.resolvedColorIndex(plots: plots, at: index)]
    }

    // Resolve each plot's color index so no two plots share a color.
    // Explicit colors (>= 0) win in order; conflicts and unassigned plots
    // get reassigned to the next free color.
    static func resolvedColorIndex(plots: [Plot], at target: Int) -> Int {
        var used = Set<Int>()
        var assigned = Array(repeating: -1, count: plots.count)
        var pending: [Int] = []
        for (i, plot) in plots.enumerated() {
            if let c = plot.color, c >= 0, c < plotColors.count, !used.contains(c) {
                used.insert(c)
                assigned[i] = c
            } else {
                pending.append(i)
            }
        }
        for i in pending {
            var pick = -1
            for k in 0..<plotColors.count where !used.contains(k) {
                pick = k
                break
            }
            if pick < 0 { pick = i % plotColors.count }
            used.insert(pick)
            assigned[i] = pick
        }
        return assigned[target]
    }

    private func plotLines(size: CGSize) -> some View {
        ForEach(Array(plots.enumerated()), id: \.element.id) { idx, plot in
            let points = chartPoints
                .filter { $0.plot_id == plot.id }
                .sorted { $0.x_pos < $1.x_pos }

            if points.count > 1 {
                Path { path in
                    for (i, pt) in points.enumerated() {
                        let p = chartPosition(pt, in: size)
                        if i == 0 { path.move(to: p) }
                        else { path.addLine(to: p) }
                    }
                }
                .stroke(colorForPlot(plot, index: idx), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            }
        }
    }

    private func plotDots(size: CGSize) -> some View {
        ForEach(Array(plots.enumerated()), id: \.element.id) { idx, plot in
            let points = chartPoints
                .filter { $0.plot_id == plot.id }
                .sorted { $0.x_pos < $1.x_pos }

            ForEach(Array(points.enumerated()), id: \.element.id) { pi, pt in
                let pos = chartPosition(pt, in: size)
                let isHighlighted = highlightedPoint?.plotIndex == idx && highlightedPoint?.pointIndex == pi
                let dotSize: CGFloat = isHighlighted ? 14 : 10

                Circle()
                    .fill(colorForPlot(plot, index: idx))
                    .frame(width: dotSize, height: dotSize)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle().size(width: 44, height: 44))
                    .position(pos)
                    .gesture(isEditable ? dragGesture(for: pt, plotIndex: idx, pointIndex: pi, plot: plot, chartSize: size) : nil)
            }
        }
    }

    private func dragGesture(for point: ChartPoint, plotIndex: Int, pointIndex: Int, plot: Plot, chartSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named("chart"))
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    onDragSelected?(PointHighlight(
                        plotIndex: plotIndex,
                        pointIndex: pointIndex,
                        plotTitle: plot.title,
                        label: point.label,
                        color: colorForPlot(plot, index: plotIndex)
                    ))
                }
                let raw = normalizedFromPixel(value.location, chartSize: chartSize)
                let snappedRawX = snapXToNeighbor(rawX: raw.x, excludeId: point.id, chartSize: chartSize)
                snappedX = (snappedRawX != raw.x) ? snappedRawX : nil
                onPointDragChanged?(point, CGPoint(x: CGFloat(snappedRawX), y: CGFloat(raw.y)))
            }
            .onEnded { value in
                let raw = normalizedFromPixel(value.location, chartSize: chartSize)
                let snappedRawX = snapXToNeighbor(rawX: raw.x, excludeId: point.id, chartSize: chartSize)
                onPointDragged?(point, CGPoint(x: CGFloat(snappedRawX), y: CGFloat(raw.y)))
                snappedX = nil
                isDragging = false
            }
    }

    // Snap the raw x (0-10000) to any other scene's x within snapThresholdPx
    // pixel distance. Mirrors the webapp's SNAP_PX=12 behavior, with a
    // slightly larger threshold to suit touch input.
    private func snapXToNeighbor(rawX: Int, excludeId: Int, chartSize: CGSize) -> Int {
        let padX = chartSize.width * inset
        let innerW = chartSize.width - 2 * padX
        let rawPx = padX + CGFloat(rawX) / 10000.0 * innerW
        var bestDist = snapThresholdPx + 1
        var bestX = rawX
        for pt in chartPoints where pt.id != excludeId {
            let px = padX + CGFloat(pt.x_pos) / 10000.0 * innerW
            let d = abs(px - rawPx)
            if d < bestDist {
                bestDist = d
                bestX = pt.x_pos
            }
        }
        return bestX
    }

    private func chartPosition(_ point: ChartPoint, in size: CGSize) -> CGPoint {
        let padX = size.width * inset
        let padY = size.height * inset
        let innerW = size.width - 2 * padX
        let innerH = size.height - 2 * padY
        return CGPoint(
            x: padX + CGFloat(point.x_pos) / 10000.0 * innerW,
            y: padY + (1.0 - CGFloat(point.y_val) / 10000.0) * innerH
        )
    }

    private func normalizedFromPixel(_ location: CGPoint, chartSize: CGSize) -> (x: Int, y: Int) {
        let padX = chartSize.width * inset
        let padY = chartSize.height * inset
        let innerW = chartSize.width - 2 * padX
        let innerH = chartSize.height - 2 * padY
        let nx = Int(max(0, min(10000, (location.x - padX) / innerW * 10000)))
        let ny = Int(max(0, min(10000, (1.0 - (location.y - padY) / innerH) * 10000)))
        return (nx, ny)
    }
}

// MARK: - Thumbnail for story list

struct ChartThumbnailView: View {
    let plots: [StoryListPlot]

    private static let goldenRatio: CGFloat = 1.618
    private let plotColors: [Color] = [
        Color(red: 0.29, green: 0.50, blue: 0.83),
        Color(red: 0.88, green: 0.38, blue: 0.25),
        Color(red: 0.31, green: 0.63, blue: 0.25),
        Color(red: 0.83, green: 0.63, blue: 0.13),
        Color(red: 0.56, green: 0.38, blue: 0.75),
        Color(red: 0.16, green: 0.62, blue: 0.56),
        Color(red: 0.88, green: 0.44, blue: 0.60),
        Color(red: 0.54, green: 0.40, blue: 0.25),
        Color(red: 0.31, green: 0.31, blue: 0.69),
        Color(red: 0.88, green: 0.50, blue: 0.31),
    ]
    private let gridCount = 20
    private let inset: CGFloat = 0.05

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / Self.goldenRatio
            ZStack {
                thumbnailGrid(width: w, height: h)
                thumbnailMidline(width: w, height: h)
                thumbnailLines(width: w, height: h)
                thumbnailDots(width: w, height: h)
            }
            .frame(width: w, height: h)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(Self.goldenRatio, contentMode: .fit)
    }

    private func colorForPlot(_ plot: StoryListPlot, index: Int) -> Color {
        var used = Set<Int>()
        var assigned = Array(repeating: -1, count: plots.count)
        var pending: [Int] = []
        for (i, p) in plots.enumerated() {
            if let c = p.color, c >= 0, c < plotColors.count, !used.contains(c) {
                used.insert(c)
                assigned[i] = c
            } else {
                pending.append(i)
            }
        }
        for i in pending {
            var pick = -1
            for k in 0..<plotColors.count where !used.contains(k) {
                pick = k
                break
            }
            if pick < 0 { pick = i % plotColors.count }
            used.insert(pick)
            assigned[i] = pick
        }
        return plotColors[assigned[index]]
    }

    private func thumbnailGrid(width: CGFloat, height: CGFloat) -> some View {
        Canvas { ctx, _ in
            let gridColor = Color(red: 0.85, green: 0.9, blue: 0.95)
            let hStep = width / CGFloat(gridCount)
            let vStep = height / CGFloat(gridCount)
            for i in 0...gridCount {
                var hPath = Path()
                let y = CGFloat(i) * vStep
                hPath.move(to: CGPoint(x: 0, y: y))
                hPath.addLine(to: CGPoint(x: width, y: y))
                ctx.stroke(hPath, with: .color(gridColor), lineWidth: 0.5)
                var vPath = Path()
                let x = CGFloat(i) * hStep
                vPath.move(to: CGPoint(x: x, y: 0))
                vPath.addLine(to: CGPoint(x: x, y: height))
                ctx.stroke(vPath, with: .color(gridColor), lineWidth: 0.5)
            }
        }
        .frame(width: width, height: height)
        .background(Color(red: 0.97, green: 0.98, blue: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func thumbnailMidline(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            let padY = height * inset
            let innerH = height - 2 * padY
            let midY = padY + innerH / 2
            path.move(to: CGPoint(x: 0, y: midY))
            path.addLine(to: CGPoint(x: width, y: midY))
        }
        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
    }

    private func thumbnailLines(width: CGFloat, height: CGFloat) -> some View {
        ForEach(Array(plots.enumerated()), id: \.element.id) { idx, plot in
            let sorted = plot.points.sorted { $0.x < $1.x }
            if sorted.count > 1 {
                Path { path in
                    for (i, pt) in sorted.enumerated() {
                        let p = thumbPosition(pt, width: width, height: height)
                        if i == 0 { path.move(to: p) }
                        else { path.addLine(to: p) }
                    }
                }
                .stroke(colorForPlot(plot, index: idx), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
        }
    }

    private func thumbnailDots(width: CGFloat, height: CGFloat) -> some View {
        ForEach(Array(plots.enumerated()), id: \.element.id) { idx, plot in
            ForEach(Array(plot.points.enumerated()), id: \.offset) { _, pt in
                Circle()
                    .fill(colorForPlot(plot, index: idx))
                    .frame(width: 8, height: 8)
                    .position(thumbPosition(pt, width: width, height: height))
            }
        }
    }

    private func thumbPosition(_ point: StoryListPoint, width: CGFloat, height: CGFloat) -> CGPoint {
        let padX = width * inset
        let padY = height * inset
        let innerW = width - 2 * padX
        let innerH = height - 2 * padY
        return CGPoint(
            x: padX + CGFloat(point.x) / 10000.0 * innerW,
            y: padY + (1.0 - CGFloat(point.y) / 10000.0) * innerH
        )
    }
}
