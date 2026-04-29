import Hummingbird
import Foundation

@main
struct VLDiscogsBot {
    static func main() async throws {
        let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8080") ?? 8080
        let app = buildApplication(hostname: "0.0.0.0", port: port)
        try await app.runService()
    }
}

func buildApplication(
    hostname: String,
    port: Int
) -> some ApplicationProtocol {
    let env = ProcessInfo.processInfo.environment

    let sessionStore = SessionStore()

    let executor = DiscogsToolExecutor(
        token:    env["DISCOGS_TOKEN"]    ?? "",
        username: env["DISCOGS_USERNAME"] ?? ""
    )
    let claude = ClaudeClient(apiKey: env["ANTHROPIC_API_KEY"] ?? "")
    let toolBridge  = ToolBridge(claude: claude, executor: executor)
    let slackClient = SlackClient(botToken: env["SLACK_BOT_TOKEN"] ?? "")

    let router = Router()
    SlackEventController(
        signingSecret: env["SLACK_SIGNING_SECRET"] ?? "",
        sessionStore:  sessionStore,
        toolBridge:    toolBridge,
        slackClient:   slackClient
    )
    .addRoutes(to: router.group("slack"))

    return Application(
        router: router,
        configuration: .init(address: .hostname(hostname, port: port))
    )
}
