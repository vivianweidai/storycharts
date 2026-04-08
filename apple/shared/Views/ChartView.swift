import SwiftUI

struct ChartView: View {
    let plots: [Plot]
    let chartPoints: [ChartPoint]
    let isEditable: Bool
    var onPointDragged: ((ChartPoint, CGPoint) -> Void)?

    private let plotColors: [Color] = [.blue, .red, .green, .orange, .purple, .cyan]
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
                .stroke(plotColors[idx % plotColors.count], lineWidth: 2.5)
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
                    .fill(plotColors[idx % plotColors.count])
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
