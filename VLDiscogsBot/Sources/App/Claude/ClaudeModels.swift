import Foundation

// MARK: - Shared JSON value

indirect enum JSONValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self)             { self = .bool(v);   return }
        if let v = try? c.decode(Int.self)              { self = .int(v);    return }
        if let v = try? c.decode(Double.self)           { self = .double(v); return }
        if let v = try? c.decode(String.self)           { self = .string(v); return }
        if let v = try? c.decode([JSONValue].self)      { self = .array(v);  return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.typeMismatch(
            JSONValue.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON type")
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v):    try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v):   try c.encode(v)
        case .array(let v):  try c.encode(v)
        case .object(let v): try c.encode(v)
        case .null:          try c.encodeNil()
        }
    }

    var string: String? { if case .string(let v) = self { return v }; return nil }
    var int: Int? {
        if case .int(let v) = self { return v }
        if case .double(let v) = self, v == v.rounded() { return Int(v) }
        return nil
    }
}

// MARK: - Request

struct ClaudeRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [ClaudeMessage]
    let tools: [ClaudeTool]

    enum CodingKeys: String, CodingKey {
        case model, system, messages, tools
        case maxTokens = "max_tokens"
    }
}

struct ClaudeMessage: Encodable {
    let role: String
    let content: MessageContent
}

enum MessageContent: Encodable {
    case text(String)
    case blocks([RequestBlock])

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .text(let s):    try c.encode(s)
        case .blocks(let b):  try c.encode(b)
        }
    }
}

enum RequestBlock: Encodable {
    case text(String)
    case toolUse(id: String, name: String, input: [String: JSONValue])
    case toolResult(toolUseId: String, content: String)

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let t):
            try c.encode("text", forKey: .type)
            try c.encode(t, forKey: .text)
        case .toolUse(let id, let name, let input):
            try c.encode("tool_use", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name)
            try c.encode(input, forKey: .input)
        case .toolResult(let toolUseId, let content):
            try c.encode("tool_result", forKey: .type)
            try c.encode(toolUseId, forKey: .toolUseId)
            try c.encode(content, forKey: .content)
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input, content
        case toolUseId = "tool_use_id"
    }
}

struct ClaudeTool: Encodable {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

struct ToolInputSchema: Encodable {
    let type = "object"
    let properties: [String: SchemaProperty]
    let required: [String]
}

struct SchemaProperty: Encodable {
    let type: String
    let description: String
    let `enum`: [String]?

    init(_ type: String, _ description: String, enum values: [String]? = nil) {
        self.type = type
        self.description = description
        self.enum = values
    }
}

// MARK: - Response

struct ClaudeResponse: Decodable {
    let content: [ResponseBlock]
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
    }
}

struct ResponseBlock: Decodable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: [String: JSONValue]?
}

// MARK: - Errors

enum ClaudeError: Error {
    case httpError(Int, String)
    case maxToolRoundsExceeded
    case noTextResponse
}
