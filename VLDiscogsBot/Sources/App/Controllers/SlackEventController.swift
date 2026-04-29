import Hummingbird
import HTTPTypes
import NIOCore
import Foundation

extension HTTPField.Name {
    static let slackSignature: Self = .init("X-Slack-Signature")!
    static let slackTimestamp: Self = .init("X-Slack-Request-Timestamp")!
}

struct SlackEventController: Sendable {
    private let verifier: SlackSignatureVerifier
    private let sessionStore: SessionStore
    private let toolBridge: ToolBridge
    private let slackClient: SlackClient

    init(
        signingSecret: String,
        sessionStore: SessionStore,
        toolBridge: ToolBridge,
        slackClient: SlackClient
    ) {
        self.verifier     = SlackSignatureVerifier(signingSecret: signingSecret)
        self.sessionStore = sessionStore
        self.toolBridge   = toolBridge
        self.slackClient  = slackClient
    }

    func addRoutes(to group: RouterGroup<some RequestContext>) {
        group.post("events", use: handleEvent)
    }

    @Sendable
    func handleEvent(
        _ request: Request,
        context: some RequestContext
    ) async throws -> Response {
        let buffer = try await request.body.collect(upTo: 1_000_000)
        let body = Data(buffer.readableBytesView)

        guard
            let timestamp = request.headers[.slackTimestamp],
            let signature = request.headers[.slackSignature],
            verifier.verify(signature: signature, timestamp: timestamp, body: body)
        else {
            return Response(status: .unauthorized)
        }

        let envelope = try JSONDecoder().decode(SlackEnvelope.self, from: body)

        switch envelope.type {
        case "url_verification":
            guard let challenge = envelope.challenge else {
                return Response(status: .badRequest)
            }
            return try challengeResponse(challenge)

        case "event_callback":
            guard let event = envelope.event else {
                return Response(status: .badRequest)
            }
            Task { await dispatch(event) }
            return Response(status: .ok)

        default:
            return Response(status: .badRequest)
        }
    }

    // MARK: - Private

    private func dispatch(_ event: SlackEventPayload) async {
        print("[Dispatch] type=\(event.type) user=\(event.user ?? "nil") botId=\(event.botId ?? "nil") channel=\(event.channel ?? "nil") text=\(event.text ?? "nil")")
        guard
            event.botId == nil,
            let userId  = event.user,
            let channel = event.channel,
            let text    = event.text,
            !text.isEmpty
        else {
            print("[Dispatch] guard failed, dropping event")
            return
        }

        await sessionStore.append(Message(role: .user, content: text), forUser: userId)
        let history = await sessionStore.messages(forUser: userId)

        do {
            let reply = try await toolBridge.run(history: history)
            await sessionStore.append(Message(role: .assistant, content: reply), forUser: userId)
            try await slackClient.postMessage(channel: channel, text: reply)
        } catch {
            print("[Error] dispatch failed for user=\(userId): \(error)")
        }
    }

    private func challengeResponse(_ challenge: String) throws -> Response {
        let data = try JSONSerialization.data(withJSONObject: ["challenge": challenge])
        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        return Response(
            status: .ok,
            headers: headers,
            body: ResponseBody(byteBuffer: ByteBuffer(bytes: Array(data)))
        )
    }
}
