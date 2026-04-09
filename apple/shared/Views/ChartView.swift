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

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                gridBackground(size: size)
                midline(size: size)
                if let px = playX {
                    sweepLine(size: size, x: px)
                }
                if let hl = highlightedPoint {
                    halo(size: size, highlight: hl)
                }
                plotLines(size: size)
                plotDots(size: size)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { location in
                handleTap(at: location, chartSize: size)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func handleTap(at location: CGPoint, chartSize: CGFloat) {
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

    private func sweepLine(size: CGFloat, x: Int) -> some View {
        let px = CGFloat(x) / 10000.0 * size
        return Path { path in
            path.move(to: CGPoint(x: px, y: 0))
            path.addLine(to: CGPoint(x: px, y: size))
        }
        .stroke(Color.blue.opacity(0.35), lineWidth: 1)
    }

    private func halo(size: CGFloat, highlight: PointHighlight) -> some View {
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

    private func gridBackground(size: CGFloat) -> some View {
        Canvas { ctx, _ in
            let step = size / CGFloat(gridCount)
            let gridColor = Color(red: 0.85, green: 0.9, blue: 0.95)
            for i in 0...gridCount {
                let pos = CGFloat(i) * step
                var hPath = Path()
                hPath.move(to: CGPoint(x: 0, y: pos))
                hPath.addLine(to: CGPoint(x: size, y: pos))
                ctx.stroke(hPath, with: .color(gridColor), lineWidth: 0.5)
                var vPath = Path()
                vPath.move(to: CGPoint(x: pos, y: 0))
                vPath.addLine(to: CGPoint(x: pos, y: size))
                ctx.stroke(vPath, with: .color(gridColor), lineWidth: 0.5)
            }
        }
        .frame(width: size, height: size)
        .background(Color(red: 0.97, green: 0.98, blue: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func midline(size: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size / 2))
            path.addLine(to: CGPoint(x: size, y: size / 2))
        }
        .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
    }

    func colorForPlot(_ plot: Plot, index: Int) -> Color {
        let ci = (plot.color != nil && plot.color! >= 0) ? plot.color! : index
        return Self.plotColors[ci % Self.plotColors.count]
    }

    private func plotLines(size: CGFloat) -> some View {
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
                .stroke(colorForPlot(plot, index: idx), lineWidth: 2.5)
            }
        }
    }

    private func plotDots(size: CGFloat) -> some View {
        ForEach(Array(plots.enumerated()), id: \.element.id) { idx, plot in
            let points = chartPoints
                .filter { $0.plot_id == plot.id }
                .sorted { $0.x_pos < $1.x_pos }

            ForEach(Array(points.enumerated()), id: \.element.id) { pi, pt in
                let pos = chartPosition(pt, in: size)
                let isHighlighted = highlightedPoint?.plotIndex == idx && highlightedPoint?.pointIndex == pi
                Circle()
                    .fill(colorForPlot(plot, index: idx))
                    .frame(width: isHighlighted ? 14 : 10, height: isHighlighted ? 14 : 10)
                    .position(pos)
            }
        }
    }

    private func chartPosition(_ point: ChartPoint, in size: CGFloat) -> CGPoint {
        CGPoint(
            x: CGFloat(point.x_pos) / 10000.0 * size,
            y: (1.0 - CGFloat(point.y_val) / 10000.0) * size
        )
    }
}

// MARK: - Thumbnail for story list

struct ChartThumbnailView: View {
    let plots: [StoryListPlot]

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

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                thumbnailGrid(size: size)
                thumbnailMidline(size: size)
                thumbnailLines(size: size)
                thumbnailDots(size: size)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func colorForPlot(_ plot: StoryListPlot, index: Int) -> Color {
        let ci = (plot.color != nil && plot.color! >= 0) ? plot.color! : index
        return plotColors[ci % plotColors.count]
    }

    private func thumbnailGrid(size: CGFloat) -> some View {
        Canvas { ctx, _ in
            let step = size / CGFloat(gridCount)
            let gridColor = Color(red: 0.85, green: 0.9, blue: 0.95)
            for i in 0...gridCount {
                let pos = CGFloat(i) * step
                var hPath = Path()
                hPath.move(to: CGPoint(x: 0, y: pos))
                hPath.addLine(to: CGPoint(x: size, y: pos))
                ctx.stroke(hPath, with: .color(gridColor), lineWidth: 0.5)
                var vPath = Path()
                vPath.move(to: CGPoint(x: pos, y: 0))
                vPath.addLine(to: CGPoint(x: pos, y: size))
                ctx.stroke(vPath, with: .color(gridColor), lineWidth: 0.5)
            }
        }
        .frame(width: size, height: size)
        .background(Color(red: 0.97, green: 0.98, blue: 1.0))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func thumbnailMidline(size: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size / 2))
            path.addLine(to: CGPoint(x: size, y: size / 2))
        }
        .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
    }

    private func thumbnailLines(size: CGFloat) -> some View {
        ForEach(Array(plots.enumerated()), id: \.element.id) { idx, plot in
            let sorted = plot.points.sorted { $0.x < $1.x }
            if sorted.count > 1 {
                Path { path in
                    for (i, pt) in sorted.enumerated() {
                        let p = thumbPosition(pt, in: size)
                        if i == 0 { path.move(to: p) }
                        else { path.addLine(to: p) }
                    }
                }
                .stroke(colorForPlot(plot, index: idx), lineWidth: 2)
            }
        }
    }

    private func thumbnailDots(size: CGFloat) -> some View {
        ForEach(Array(plots.enumerated()), id: \.element.id) { idx, plot in
            ForEach(Array(plot.points.enumerated()), id: \.offset) { _, pt in
                Circle()
                    .fill(colorForPlot(plot, index: idx))
                    .frame(width: 8, height: 8)
                    .position(thumbPosition(pt, in: size))
            }
        }
    }

    private func thumbPosition(_ point: StoryListPoint, in size: CGFloat) -> CGPoint {
        CGPoint(
            x: CGFloat(point.x) / 10000.0 * size,
            y: (1.0 - CGFloat(point.y) / 10000.0) * size
        )
    }
}
