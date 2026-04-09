import SwiftUI

struct WatchSceneListView: View {
    let detail: StoryDetail

    var body: some View {
        List {
            ForEach(allScenesSorted(), id: \.id) { scene in
                HStack(spacing: 8) {
                    Circle()
                        .fill(scene.color)
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(scene.plotTitle)
                            .font(.caption2)
                            .foregroundStyle(scene.color)
                        Text(scene.label.isEmpty ? "—" : scene.label)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Scenes")
    }

    private struct SceneRow: Identifiable {
        let id: Int
        let plotTitle: String
        let label: String
        let color: Color
        let x: Int
    }

    private func allScenesSorted() -> [SceneRow] {
        var rows: [SceneRow] = []
        for (idx, plot) in detail.plots.enumerated() {
            let ci = (plot.color != nil && plot.color! >= 0) ? plot.color! : idx
            let color = ChartView.plotColors[ci % ChartView.plotColors.count]
            let pts = detail.chartPoints
                .filter { $0.plot_id == plot.id }
                .sorted { $0.x_pos < $1.x_pos }
            for pt in pts {
                rows.append(SceneRow(id: pt.id, plotTitle: plot.title, label: pt.label, color: color, x: pt.x_pos))
            }
        }
        rows.sort { $0.x < $1.x }
        return rows
    }
}
