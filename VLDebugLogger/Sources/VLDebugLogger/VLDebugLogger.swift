import Foundation
#if canImport(os)
import os.log
#endif
import OrderedCollections

public final class VLDebugLogger: Sendable {

    // MARK: - Shared Instance

    public static let shared = VLDebugLogger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.app.logger",
        enabled: true,
        defaultFormat: [
            .prefix,
            .emoji,
            .category,
            .error,
            .message
        ]
    )

    // MARK: - Properties

    public let subsystem: String

    #if canImport(os)
    private let logger: Logger
    private let _enabled: OSAllocatedUnfairLock<Bool>
    #else
    nonisolated(unsafe) private var _enabled: Bool
    #endif

    public var enabled: Bool {
        #if canImport(os)
        _enabled.withLock { $0 }
        #else
        _enabled
        #endif
    }

    public let destination: Set<LogDestination>
    public let logLevels: Set<LogLevel>
    public let defaultPrefix: String
    public let defaultFormat: OrderedSet<MessageFormatOption>

    // MARK: - Initialization

    public init(
        subsystem: String,
        category: Category = .general,
        logLevels: Set<LogLevel> = Set(LogLevel.allCases),
        enabled: Bool = false,
        destination: Set<LogDestination> = [.console, .osLog],
        defaultPrefix: String = "DEBUG",
        defaultFormat: OrderedSet<MessageFormatOption> = [
            .prefix,
            .emoji,
            .subsystem,
            .category,
            .error,
            .message
        ]
    ) {
        self.subsystem = subsystem
        self.logLevels = logLevels
        self.destination = destination
        self.defaultPrefix = defaultPrefix
        self.defaultFormat = defaultFormat
        #if canImport(os)
        self.logger = Logger(subsystem: subsystem, category: category.description)
        self._enabled = OSAllocatedUnfairLock(initialState: enabled)
        #else
        self._enabled = enabled
        #endif
    }

    public func toggleEnabled(to value: Bool) {
        #if canImport(os)
        _enabled.withLock { $0 = value }
        #else
        _enabled = value
        #endif
    }

    // MARK: - Public Logging Methods

    private func debug(_ message: String) {
        guard enabled, logLevels.contains(.debug) else { return }
        if destination.contains(.console) { print(message) }
        #if canImport(os)
        if destination.contains(.osLog) { logger.debug("\(message, privacy: .auto)") }
        #endif
    }

    private func info(_ message: String) {
        guard enabled, logLevels.contains(.info) else { return }
        if destination.contains(.console) { print(message) }
        #if canImport(os)
        if destination.contains(.osLog) { logger.info("\(message)") }
        #endif
    }

    private func warning(_ message: String) {
        guard enabled, logLevels.contains(.warning) else { return }
        if destination.contains(.console) { print(message) }
        #if canImport(os)
        if destination.contains(.osLog) { logger.warning("\(message)") }
        #endif
    }

    private func error(_ message: String) {
        guard enabled, logLevels.contains(.error) else { return }
        if destination.contains(.console) { print(message) }
        #if canImport(os)
        if destination.contains(.osLog) { logger.error("\(message)") }
        #endif
    }

    private func critical(_ message: String) {
        guard enabled, logLevels.contains(.critical) else { return }
        if destination.contains(.console) { print(message) }
        #if canImport(os)
        if destination.contains(.osLog) { logger.critical("\(message)") }
        #endif
    }

    // MARK: - Convenience Methods

    public func log(
        _ message: String,
        category: Category = .general,
        level: MessageLogLevel = .debug,
        prefix: String? = nil,
        emoji: String? = nil,
        showSubsystem: Bool = true,
        format: OrderedSet<MessageFormatOption>? = nil
    ) {
        let formattedLogOutput = formatLogOutput(
            prefix: prefix,
            defaultPrefix: defaultPrefix,
            category: category,
            emoji: emoji,
            level: level.asLogLevel,
            subsystem: subsystem,
            error: nil,
            message: message,
            with: format ?? defaultFormat
        )
        log(formattedLogOutput, level: level.asLogLevel)
    }

    public func log(
        _ error: Error,
        message: String? = nil,
        category: Category = .general,
        level: ErrorLogLevel = .error,
        prefix: String? = nil,
        emoji: String? = nil,
        showSubsystem: Bool = true,
        format: OrderedSet<MessageFormatOption>? = nil
    ) {
        let formattedLogOutput = formatLogOutput(
            prefix: prefix,
            defaultPrefix: defaultPrefix,
            category: category,
            emoji: emoji,
            level: level.asLogLevel,
            subsystem: subsystem,
            error: error,
            message: message,
            with: format ?? defaultFormat
        )
        log(formattedLogOutput, level: level.asLogLevel)
    }

    private func formatLogOutput(
        prefix: String?,
        defaultPrefix: String,
        category: Category,
        emoji: String?,
        level: LogLevel,
        subsystem: String,
        error: Error?,
        message: String?,
        with format: OrderedSet<MessageFormatOption>
    ) -> String {
        var components: [String] = []
        for option in format {
            switch option {
            case .prefix:   components.append(prefix ?? defaultPrefix)
            case .category: components.append("[\(category.description)]")
            case .emoji:    components.append(emoji ?? level.defaultEmoji)
            case .subsystem: components.append("[\(subsystem)]")
            case .error:
                if let error { components.append("Error: \(error.localizedDescription)") }
            case .message:
                if let message, !message.isEmpty { components.append(message) }
            }
        }
        return components.joined(separator: " ")
    }

    private func log(_ message: String, level: LogLevel) {
        switch level {
        case .debug:    debug(message)
        case .info:     info(message)
        case .warning:  warning(message)
        case .error:    error(message)
        case .critical: critical(message)
        }
    }

    // MARK: - Network Helpers

    public func log(_ request: URLRequest) {
        log(
            "REQUEST: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")",
            category: .network,
            emoji: "🌐"
        )
        logRequestHeaders(request.allHTTPHeaderFields)
        logRequestBody(request.httpBody)
    }

    private func logRequestHeaders(_ headers: [String: String]?) {
        if let headers {
            let safeHeaders = headers.filter { !["Authorization", "X-API-Key"].contains($0.key) }
            log("Headers: \(safeHeaders)", category: .network, emoji: "📋")
        }
    }

    private func logRequestBody(_ body: Data?) {
        if let body {
            log(
                "Body: \(String(data: body, encoding: .utf8) ?? "Binary data")",
                category: .network,
                emoji: "📝"
            )
        }
    }

    public func log(_ response: URLResponse, data: Data?, showData: Bool = false) {
        if let httpResponse = response as? HTTPURLResponse {
            let statusEmoji = httpResponse.statusCode < 400 ? "✅" : "❌"
            log(
                "RESPONSE: \(httpResponse.statusCode) for \(httpResponse.url?.absoluteString ?? "")",
                category: .network,
                emoji: statusEmoji
            )
            logResponseData(data, showData: showData)
        }
    }

    private func logResponseData(_ data: Data?, showData: Bool = false) {
        if let data {
            log("Response size: \(data.count) bytes", category: .network, emoji: "📦")
            if showData {
                log(
                    "Response payload: \(String(data: data, encoding: .utf8) ?? "Binary data")",
                    category: .network,
                    emoji: "📝"
                )
            }
        }
    }
}


// MARK: - Log Level

public extension VLDebugLogger {
    enum LogLevel: CaseIterable, Sendable {
        case debug, info, warning, error, critical

        var defaultEmoji: String {
            switch self {
            case .debug:    return "🔎"
            case .info:     return "📣"
            case .warning:  return "⚠️"
            case .error:    return "❌"
            case .critical: return "🔴"
            }
        }
    }

    enum MessageLogLevel {
        case debug, info, warning

        var asLogLevel: LogLevel {
            switch self {
            case .debug:   return .debug
            case .info:    return .info
            case .warning: return .warning
            }
        }

        var defaultEmoji: String { asLogLevel.defaultEmoji }
    }

    enum ErrorLogLevel {
        case warning, error, critical

        var asLogLevel: LogLevel {
            switch self {
            case .warning:  return .warning
            case .error:    return .error
            case .critical: return .critical
            }
        }

        var defaultEmoji: String { asLogLevel.defaultEmoji }
    }
}


// MARK: - Log Categories

extension VLDebugLogger {
    public enum Category: CustomStringConvertible {
        case oauth, keychain, network, general, error
        case custom(customCategory: String)

        public var description: String {
            switch self {
            case .custom(let category): return category
            case .oauth:    return "OAuth"
            case .keychain: return "Keychain"
            case .network:  return "Network"
            case .general:  return "General"
            case .error:    return "Error"
            }
        }
    }
}


// MARK: - Message Format Options

public extension VLDebugLogger {
    enum MessageFormatOption: Sendable {
        case prefix, message, subsystem, category, emoji, error
    }
}


// MARK: - Log Destination

public extension VLDebugLogger {
    enum LogDestination: Sendable {
        case console, osLog
    }
}
