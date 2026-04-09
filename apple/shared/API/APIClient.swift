import Foundation

class APIClient {
    static let shared = APIClient()

    let baseURL = URL(string: "https://storycharts.com/api")!

    private var authToken: String?

    func setAuthToken(_ token: String?) {
        authToken = token
    }

    // MARK: - Stories

    func listStories() async throws -> [Story] {
        return try await get("stories")
    }

    func getStory(_ id: Int) async throws -> StoryDetail {
        return try await get("stories/\(id)")
    }

    func createStory(title: String) async throws -> CreateResponse {
        return try await post("stories", body: ["title": title])
    }

    func updateStory(_ id: Int, title: String) async throws {
        let _: OKResponse = try await put("stories/\(id)", body: ["title": title])
    }

    func deleteStory(_ id: Int) async throws {
        let _: OKResponse = try await delete("stories/\(id)")
    }

    // MARK: - Plots

    func createPlot(storyId: Int, title: String, color: Int = -1) async throws -> CreateResponse {
        return try await post("stories/\(storyId)/plots", body: [
            "title": title,
            "color": color
        ])
    }

    func updatePlot(_ id: Int, title: String, color: Int = -1) async throws {
        let _: OKResponse = try await put("plots/\(id)", body: [
            "title": title,
            "color": color
        ])
    }

    func deletePlot(_ id: Int) async throws {
        let _: OKResponse = try await delete("plots/\(id)")
    }

    // MARK: - Chart Points

    func saveChartPoints(storyId: Int, points: [ChartPointPayload]) async throws {
        let body: [String: Any] = ["points": points.map { $0.dict }]
        let _: OKResponse = try await post("stories/\(storyId)/chartpoints", bodyRaw: body)
    }

    // MARK: - Auth

    func getMe() async throws -> User? {
        do {
            let user: User = try await get("auth/me")
            return user
        } catch APIError.unauthorized {
            return nil
        }
    }

    // MARK: - Networking

    private func get<T: Decodable>(_ path: String) async throws -> T {
        return try await request(path, method: "GET")
    }

    private func post<T: Decodable>(_ path: String, body: [String: String]) async throws -> T {
        return try await request(path, method: "POST", body: body)
    }

    private func post<T: Decodable>(_ path: String, bodyRaw: [String: Any]) async throws -> T {
        return try await request(path, method: "POST", bodyRaw: bodyRaw)
    }

    private func put<T: Decodable>(_ path: String, body: [String: String]) async throws -> T {
        return try await request(path, method: "PUT", body: body)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        return try await request(path, method: "DELETE")
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String,
        body: [String: String]? = nil,
        bodyRaw: [String: Any]? = nil
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method

        if let token = authToken {
            req.addValue("CF_Authorization=\(token)", forHTTPHeaderField: "Cookie")
        }

        if let body = body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if let bodyRaw = bodyRaw {
            req.httpBody = try JSONSerialization.data(withJSONObject: bodyRaw)
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError
        }

        if http.statusCode == 401 { throw APIError.unauthorized }
        if http.statusCode == 403 { throw APIError.forbidden }
        if http.statusCode == 404 { throw APIError.notFound }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.serverError(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
}

struct User: Codable {
    let userid: String
    let email: String
}

struct CreateResponse: Codable {
    let id: Int
}

struct OKResponse: Codable {
    let ok: Bool
}

struct ChartPointPayload {
    let plot_id: Int
    let x_pos: Int
    let y_val: Int
    let label: String

    var dict: [String: Any] {
        ["plot_id": plot_id, "x_pos": x_pos, "y_val": y_val, "label": label]
    }
}

enum APIError: Error {
    case unauthorized
    case forbidden
    case notFound
    case networkError
    case decodingError
    case serverError(Int)
}
