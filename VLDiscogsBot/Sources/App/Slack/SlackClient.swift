import Foundation

struct SlackClient: Sendable {
    private let botToken: String

    init(botToken: String) {
        self.botToken = botToken
    }

    func postMessage(channel: String, text: String) async throws {
        let url = URL(string: "https://slack.com/api/chat.postMessage")!
        let body = try JSONSerialization.data(withJSONObject: [
            "channel": channel,
            "text": text,
        ])

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(botToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw SlackError.httpError(http.statusCode, String(decoding: data, as: UTF8.self))
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if json["ok"] as? Bool != true {
            let error = json["error"] as? String ?? "unknown"
            throw SlackError.apiError(error)
        }
    }
}

enum SlackError: Error {
    case httpError(Int, String)
    case apiError(String)
}
