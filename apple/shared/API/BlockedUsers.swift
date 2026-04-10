import Foundation

// Per-device list of user IDs (emails) whose stories should be hidden from
// the local story list. Used to satisfy Apple guideline 1.2 (UGC apps must
// let users block other users). Blocking is purely local — the server still
// stores and serves the blocked user's content to everyone else.
final class BlockedUsers: ObservableObject {
    static let shared = BlockedUsers()

    private static let storageKey = "blockedUserIDs"

    @Published private(set) var ids: Set<String>

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
        self.ids = Set(stored)
    }

    func isBlocked(_ userid: String) -> Bool {
        ids.contains(userid)
    }

    func block(_ userid: String) {
        guard !userid.isEmpty else { return }
        ids.insert(userid)
        persist()
    }

    func unblock(_ userid: String) {
        ids.remove(userid)
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(ids), forKey: Self.storageKey)
    }
}
