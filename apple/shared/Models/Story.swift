import Foundation

struct Story: Codable, Identifiable {
    let id: Int
    var title: String
    let userid: String
    let email: String
    let created_at: String?
}

struct Plot: Codable, Identifiable {
    let id: Int
    let story_id: Int
    var title: String
    var description: String
    let sort_order: Int
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
    let story: Story
    let plots: [Plot]
    let chartPoints: [ChartPoint]
    let isOwner: Bool
}
