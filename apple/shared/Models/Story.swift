import Foundation

struct Story: Codable, Identifiable {
    let id: Int
    var title: String
    let userid: String
    let created_at: String?

    var email: String { userid }
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

// MARK: - List API models (lightweight, inline plots+points)

struct StoryListItem: Codable, Identifiable {
    let id: Int
    let title: String
    let userid: String
    let created_at: String?
    let plots: [StoryListPlot]

    var email: String { userid }
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
