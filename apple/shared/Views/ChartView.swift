import SwiftUI

struct ChartView: View {
    let plots: [Plot]
    let chartPoints: [ChartPoint]
    let isEditable: Bool
    var onPointDragged: ((ChartPoint, CGPoint) -> Void)?

    private let plotColors: [Color] = [
        Color(red: 0.29, green: 0.50, blue: 0.83),  // blue
        Color(red: 0.88, green: 0.38, blue: 0.25),  // red/orange
        Color(red: 0.31, green: 0.63, blue: 0.25),  // green
        Color(red: 0.83, green: 0.63, blue: 0.13),  // gold
        Color(red: 0.56, green: 0.38, blue: 0.75),  // purple
        Color(red: 0.16, green: 0.62, blue: 0.56),  // teal
        Color(red: 0.88, green: 0.44, blue: 0.60),  // pink
        Color(red: 0.54, green: 0.40, blue: 0.25),  // brown
        Color(red: 0.31, green: 0.31, blue: 0.69),  // indigo
        Color(red: 0.88, green: 0.50, blue: 0.31),  // coral
    ]
    private let gridCount = 20

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                gridBackground(size: size)
                midline(size: size)
                plotLines(size: size)
                plotDots(size: size)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func gridBackground(size: CGFloat) -> some View {
        Canvas { ctx, canvasSize in
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

    private func colorForPlot(_ plot: Plot, index: Int) -> Color {
        let ci = (plot.color != nil && plot.color! >= 0) ? plot.color! : index
        return plotColors[ci % plotColors.count]
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

            ForEach(points) { pt in
                let pos = chartPosition(pt, in: size)
                Circle()
                    .fill(colorForPlot(plot, index: idx))
                    .frame(width: 12, height: 12)
                    .position(pos)
                    .gesture(
                        isEditable ?
                        DragGesture()
                            .onChanged { value in
                                onPointDragged?(pt, value.location)
                            } : nil
                    )
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
