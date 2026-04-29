import Foundation

struct SlackEnvelope: Decodable {
    let type: String
    let challenge: String?
    let event: SlackEventPayload?
    let teamId: String?

    enum CodingKeys: String, CodingKey {
        case type, challenge, event
        case teamId = "team_id"
    }
}

struct SlackEventPayload: Decodable, Sendable {
    let type: String
    let user: String?
    let botId: String?
    let text: String?
    let channel: String?
    let ts: String?

    enum CodingKeys: String, CodingKey {
        case type, user, text, channel, ts
        case botId = "bot_id"
    }
}
