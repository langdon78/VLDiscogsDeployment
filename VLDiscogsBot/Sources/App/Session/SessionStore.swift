import Foundation

// MARK: - Models

struct Message: Sendable {
    enum Role: String, Sendable {
        case user
        case assistant
    }

    let role: Role
    let content: String
}

struct DiscogsToken: Sendable {
    let accessToken: String
    let accessTokenSecret: String
}

// MARK: - SessionStore

actor SessionStore {
    private struct UserSession {
        var messages: [Message] = []
        var discogsToken: DiscogsToken?
    }

    private var sessions: [String: UserSession] = [:]
    private let maxMessages: Int

    init(maxMessages: Int = 20) {
        self.maxMessages = maxMessages
    }

    func append(_ message: Message, forUser userId: String) {
        sessions[userId, default: UserSession()].messages.append(message)
        let count = sessions[userId]!.messages.count
        if count > maxMessages {
            sessions[userId]!.messages.removeFirst(count - maxMessages)
        }
    }

    func messages(forUser userId: String) -> [Message] {
        sessions[userId]?.messages ?? []
    }

    func clearHistory(forUser userId: String) {
        sessions[userId]?.messages.removeAll()
    }

    func setDiscogsToken(_ token: DiscogsToken, forUser userId: String) {
        sessions[userId, default: UserSession()].discogsToken = token
    }

    func discogsToken(forUser userId: String) -> DiscogsToken? {
        sessions[userId]?.discogsToken
    }
}
