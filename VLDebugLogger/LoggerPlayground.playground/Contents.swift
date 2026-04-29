import UIKit
import VLDebugLogger
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true
var greeting = "Hello, playground"

var logger = VLDebugLogger(
    subsystem: "Playground",
    category: .general,
    logLevels: [
        .debug,
        .info,
        .warning,
        .error,
        .critical
    ]
)

Task {
    await logger.toggleEnabled(to: true)
    await logger.log(URLError(.badURL), level: .critical)
    await logger.log()
    await logger.log(greeting)
    await logger.log("Some info", category: .custom(customCategory: "Monitor"), level: .info)
    let token = "1234"
    await logger.log("Token: \(token)")
}
