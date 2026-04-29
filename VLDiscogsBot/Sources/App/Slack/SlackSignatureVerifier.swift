import CryptoKit
import Foundation

struct SlackSignatureVerifier: Sendable {
    private let signingSecret: String

    init(signingSecret: String) {
        self.signingSecret = signingSecret
    }

    func verify(signature: String, timestamp: String, body: Data) -> Bool {
        guard
            let ts = TimeInterval(timestamp),
            abs(Date().timeIntervalSince1970 - ts) < 300,
            signature.hasPrefix("v0="),
            let expectedBytes = Data(hexEncoded: String(signature.dropFirst(3)))
        else {
            return false
        }

        let message = "v0:\(timestamp):\(String(decoding: body, as: UTF8.self))"
        let key = SymmetricKey(data: Data(signingSecret.utf8))
        return HMAC<SHA256>.isValidAuthenticationCode(
            expectedBytes,
            authenticating: Data(message.utf8),
            using: key
        )
    }
}

private extension Data {
    init?(hexEncoded hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
