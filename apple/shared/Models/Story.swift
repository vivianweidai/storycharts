import Foundation

struct Story: Codable, Identifiable {
    let id: Int
    var title: String
    let userid: String
}

struct Plot: Codable, Identifiable {
    let id: Int
    let story_id: Int
    var title: String
    let sort_order: Int
    var color: Int?
}

struct ChartPoint: Codable, Identifiable {
    let id: Int
    let story_id: Int
    let plot_id: Int
    var x_pos: Int
    var y_val: Int
    var label: String

    var xPercent: Double { Double(x_pos) / 100.0 }
    var yPercent: Double { Double(y_val) / 100.0 }
}

struct StoryDetail: Codable {
    var story: Story
    var plots: [Plot]
    let chartPoints: [ChartPoint]
    let isOwner: Bool?
}

extension Array where Element == ChartPoint {
    // Points belonging to a plot, sorted by x_pos (timeline order).
    func scenes(for plotId: Int) -> [ChartPoint] {
        self.filter { $0.plot_id == plotId }.sorted { $0.x_pos < $1.x_pos }
    }
}

// MARK: - List API models (lightweight, inline plots+points)

struct StoryListItem: Codable, Identifiable {
    let id: Int
    let title: String
    let userid: String
    let plots: [StoryListPlot]
}

struct StoryListPlot: Codable, Identifiable {
    let id: Int
    let title: String
    let color: Int?
    let points: [StoryListPoint]
}

struct StoryListPoint: Codable {
    let x: Int
    let y: Int
}
