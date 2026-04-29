// The Swift Programming Language
// https://docs.swift.org/swift-book

//
//  VLDebugLogger.swift
//  VLDebugLogger
//
//  Created by James Langdon on 1/11/26.
//

import Foundation
import os.log
import OrderedCollections

public final class VLDebugLogger: Sendable {
    
    // MARK: - Shared Instance
    
    /// Shared singleton instance for convenient app-wide logging.
    /// For module-specific logging, create dedicated instances with custom subsystems.
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
    private let logger: Logger
    public let subsystem: String
    
    /// Controls whether debug logging is enabled. Set to false in production builds.
    private let _enabled: OSAllocatedUnfairLock<Bool>
    public var enabled: Bool {
        get { _enabled.withLock { $0 } }
    }
    
    /// Skip OS logging and print directly to debug console
    public let destination: Set<LogDestination>
    
    /// Store LogLevel filters
    public let logLevels: Set<LogLevel>
    
    /// Default prefix
    public let defaultPrefix: String
    
    /// Default log format
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
        self.logger = Logger(subsystem: subsystem, category: category.description)
        self._enabled = OSAllocatedUnfairLock(initialState: enabled)
        self.destination = destination
        self.defaultPrefix = defaultPrefix
        self.defaultFormat = defaultFormat
    }
    
    public func toggleEnabled(to value: Bool) {
        _enabled.withLock { $0 = value }
    }
    
    // MARK: - Public Logging Methods
    
    /// Log a debug message
    /// - Parameters:
    ///   - message: The message to log
    private func debug(_ message: String) {
        guard enabled, logLevels.contains(.debug) else { return }
        
        if destination.contains(.console) {
            print(message)
        }
        
        if destination.contains(.osLog) {
            logger.debug("\(message, privacy: .auto)")
        }
    }
    
    /// Log an info message
    /// - Parameters:
    ///   - message: The message to log
    private func info(_ message: String) {
        guard enabled, logLevels.contains(.info) else { return }
        
        if destination.contains(.console) {
            print(message)
        }
        
        if destination.contains(.osLog) {
            logger.info("\(message)")
        }
    }
    
    /// Log a warning message
    /// - Parameters:
    ///   - message: The message to log
    private func warning(_ message: String) {
        guard enabled, logLevels.contains(.warning) else { return }
        
        if destination.contains(.console) {
            print(message)
        }
        
        if destination.contains(.osLog) {
            logger.warning("\(message)")
        }
    }
    
    /// Log an error message
    /// - Parameters:
    ///   - message: The message to log
    private func error(_ message: String) {
        guard enabled, logLevels.contains(.error) else { return }

        if destination.contains(.console) {
            print(message)
        }
        
        if destination.contains(.osLog) {
            logger.error("\(message)")
        }
    }
    
    /// Log a critical error
    /// - Parameters:
    ///   - message: The message to log
    private func critical(_ message: String) {
        guard enabled, logLevels.contains(.critical) else { return }
        
        if destination.contains(.console) {
            print(message)
        }
        
        if destination.contains(.osLog) {
            logger.critical("\(message)")
        }
    }
    
    // MARK: - Convenience Method
    
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
            case .prefix:
                components.append(prefix ?? defaultPrefix)
            case .category:
                components.append("[\(category.description)]")
            case .emoji:
                components.append(emoji ?? level.defaultEmoji)
            case .subsystem:
                components.append("[\(subsystem)]")
            case .error:
                if let error {
                    components.append("Error: \(error.localizedDescription)")
                }
            case .message:
                if let message, !message.isEmpty {
                    components.append(message)
                }
            }
        }
        
        return components.joined(separator: " ")
    }
    
    // MARK: - Private Helpers
    
    private func log(_ message: String, level: LogLevel) {
        switch level {
        case .debug:
            debug(message)
        case .info:
            info(message)
        case .warning:
            warning(message)
        case .error:
            error(message)
        case .critical:
            critical(message)
        }
    }
    
    // MARK: - Network Helpers
    
    public func log(
        _ request: URLRequest
    ) {
        log(
            "REQUEST: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")",
            category: .network,
            emoji: "🌐"
        )
        logRequestHeaders(request.allHTTPHeaderFields)
        logRequestBody(request.httpBody)
    }
    
    private func logRequestHeaders(
        _ headers: [String: String]?
    ) {
        if let headers {
            let safeHeaders = headers.filter { key, _ in
                !["Authorization", "X-API-Key"].contains(key)
            }
            log(
                "Headers: \(safeHeaders)",
                category: .network,
                emoji: "📋"
            )
        }
    }
    
    private func logRequestBody(
        _ body: Data?
    ) {
        if let body {
            log(
                "Body: \(String(data: body, encoding: .utf8) ?? "Binary data")",
                category: .network,
                emoji: "📝"
            )
        }
    }
    
    public func log(
        _ response: URLResponse,
        data: Data?,
        showData: Bool = false
    ) {
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
    
    private func logResponseData(
        _ data: Data?,
        showData: Bool = false
    ) {
        if let data {
            log(
                "Response size: \(data.count) bytes",
                category: .network,
                emoji: "📦"
            )
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
        case debug
        case info
        case warning
        case error
        case critical
        
        var defaultEmoji: String {
            switch self {
            case .debug: return "🔎"
            case .info: return "📣"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🔴"
            }
        }
    }
    
    enum MessageLogLevel {
        case debug
        case info
        case warning
        
        var asLogLevel: LogLevel {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .warning
            }
        }
        
        var defaultEmoji: String {
            asLogLevel.defaultEmoji
        }
    }
    
    enum ErrorLogLevel {
        case warning
        case error
        case critical
        
        var asLogLevel: LogLevel {
            switch self {
            case .warning: return .warning
            case .error: return .error
            case .critical: return .critical
            }
        }
        
        var defaultEmoji: String {
            asLogLevel.defaultEmoji
        }
    }
}


// MARK: - Log Categories

extension VLDebugLogger {
    public enum Category: CustomStringConvertible {
        case oauth
        case keychain
        case network
        case general
        case error
        case custom(customCategory: String)
        
        public var description: String {
            switch self {
            case .custom(customCategory: let category):
                return category
            case .oauth: return "OAuth"
            case .keychain: return "Keychain"
            case .network: return "Network"
            case .general: return "General"
            case .error: return "Error"
            }
        }
    }
}


// MARK: - Message Format Options

public extension VLDebugLogger {
    enum MessageFormatOption : Sendable{
        case prefix
        case message
        case subsystem
        case category
        case emoji
        case error
    }
}


// MARK: - Log Destination

public extension VLDebugLogger {
    enum LogDestination : Sendable{
        case console
        case osLog
    }
}
