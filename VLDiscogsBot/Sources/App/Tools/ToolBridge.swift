import Foundation

struct ToolBridge: Sendable {
    let claude: ClaudeClient
    let executor: DiscogsToolExecutor

    private static let maxToolRounds = 10

    private static let systemPrompt = """
    You are a helpful Discogs assistant for a record collector. Help users explore their vinyl \
    collection, search the Discogs database, and get information about releases and artists. \
    Keep responses concise and conversational — you're replying in a Slack channel.
    """

    static let tools: [ClaudeTool] = [
        ClaudeTool(
            name: "search_discogs",
            description: "Search the Discogs database for releases, artists, labels, or masters.",
            inputSchema: ToolInputSchema(
                properties: [
                    "query": SchemaProperty("string", "The search query"),
                    "type":  SchemaProperty("string", "Type of result", enum: ["release", "master", "artist", "label"]),
                ],
                required: ["query"]
            )
        ),
        ClaudeTool(
            name: "get_release",
            description: "Get detailed information about a specific Discogs release by ID.",
            inputSchema: ToolInputSchema(
                properties: [
                    "release_id": SchemaProperty("integer", "The Discogs release ID"),
                ],
                required: ["release_id"]
            )
        ),
        ClaudeTool(
            name: "get_collection",
            description: "Browse the user's Discogs collection.",
            inputSchema: ToolInputSchema(
                properties: [
                    "page":     SchemaProperty("integer", "Page number, starting at 1"),
                    "per_page": SchemaProperty("integer", "Results per page (max 100)"),
                ],
                required: []
            )
        ),
        ClaudeTool(
            name: "get_collection_value",
            description: "Get the minimum, median, and maximum estimated value of the user's collection.",
            inputSchema: ToolInputSchema(properties: [:], required: [])
        ),
        ClaudeTool(
            name: "random_from_collection",
            description: "Pick a random record from the user's Discogs collection.",
            inputSchema: ToolInputSchema(properties: [:], required: [])
        ),
        ClaudeTool(
            name: "search_collection",
            description: "Search the user's Discogs collection by artist name or album title. Use this instead of get_collection when looking for specific artists or albums.",
            inputSchema: ToolInputSchema(
                properties: [
                    "query": SchemaProperty("string", "Artist name or album title to search for"),
                ],
                required: ["query"]
            )
        ),
    ]

    func run(history: [Message]) async throws -> String {
        var messages = history.map {
            ClaudeMessage(role: $0.role.rawValue, content: .text($0.content))
        }

        for _ in 0..<Self.maxToolRounds {
            let response = try await claude.send(
                system: Self.systemPrompt,
                messages: messages,
                tools: Self.tools
            )

            switch response.stopReason ?? "end_turn" {
            case "end_turn":
                let text = response.content.compactMap(\.text).joined(separator: "\n")
                return text.isEmpty ? "(no response)" : text

            case "tool_use":
                // Append the full assistant turn (text + tool_use blocks)
                let assistantBlocks: [RequestBlock] = response.content.map { block in
                    if block.type == "tool_use" {
                        return .toolUse(
                            id: block.id ?? "",
                            name: block.name ?? "",
                            input: block.input ?? [:]
                        )
                    }
                    return .text(block.text ?? "")
                }
                messages.append(ClaudeMessage(role: "assistant", content: .blocks(assistantBlocks)))

                // Execute each tool call
                var resultBlocks: [RequestBlock] = []
                for block in response.content where block.type == "tool_use" {
                    guard let toolId = block.id, let toolName = block.name else { continue }
                    let result: String
                    do {
                        result = try await executor.execute(tool: toolName, input: block.input ?? [:])
                    } catch {
                        result = "Tool error: \(error.localizedDescription)"
                    }
                    resultBlocks.append(.toolResult(toolUseId: toolId, content: result))
                }
                messages.append(ClaudeMessage(role: "user", content: .blocks(resultBlocks)))

            default:
                break
            }
        }

        throw ClaudeError.maxToolRoundsExceeded
    }
}
