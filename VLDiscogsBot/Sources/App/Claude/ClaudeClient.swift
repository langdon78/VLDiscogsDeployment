import Foundation

struct ClaudeClient: Sendable {
    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "claude-sonnet-4-6") {
        self.apiKey = apiKey
        self.model = model
    }

    func send(
        system: String,
        messages: [ClaudeMessage],
        tools: [ClaudeTool],
        maxTokens: Int = 1024
    ) async throws -> ClaudeResponse {
        let body = ClaudeRequest(
            model: model,
            maxTokens: maxTokens,
            system: system,
            messages: messages,
            tools: tools
        )

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ClaudeError.httpError(http.statusCode, String(decoding: data, as: UTF8.self))
        }

        return try JSONDecoder().decode(ClaudeResponse.self, from: data)
    }
}
