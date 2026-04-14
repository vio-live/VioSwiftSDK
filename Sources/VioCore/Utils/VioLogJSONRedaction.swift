import Foundation

/// Shallow JSON redaction for console / WebSocket debug logs (apiKey, tokens, secrets).
enum VioLogJSONRedaction {
    static func redact(_ any: Any) -> Any {
        if var dict = any as? [String: Any] {
            for (k, v) in dict {
                let lower = k.lowercased()
                if lower.contains("apikey") || lower == "authorization" || lower.contains("api_key")
                    || lower.contains("secret") || lower.contains("token") || lower.contains("password")
                {
                    if let s = v as? String, !s.isEmpty {
                        dict[k] = "<redacted len=\(s.count)>"
                    } else {
                        dict[k] = "<redacted>"
                    }
                } else {
                    dict[k] = redact(v)
                }
            }
            return dict
        }
        if let arr = any as? [Any] {
            return arr.map { redact($0) }
        }
        return any
    }

    /// Pretty-prints JSON after redaction, capped in UTF-8 length for logs.
    static func prettyRedactedString(fromJSONText text: String, maxUTF8Bytes: Int = 6144) -> String {
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data, options: [])
        else {
            return String(text.prefix(500)) + (text.count > 500 ? "…(unparsed JSON)" : "")
        }
        let redactedRoot = redact(root)
        guard JSONSerialization.isValidJSONObject(redactedRoot),
              let out = try? JSONSerialization.data(withJSONObject: redactedRoot, options: [.prettyPrinted, .sortedKeys]),
              var s = String(data: out, encoding: .utf8)
        else {
            return String(text.prefix(500)) + "…(redact/pretty failed)"
        }
        var bytes = Array(s.utf8)
        let n = bytes.count
        if n > maxUTF8Bytes {
            bytes = Array(bytes.prefix(maxUTF8Bytes))
            s = String(decoding: bytes, as: UTF8.self) + "\n…(truncated, \(n) UTF-8 bytes)"
        }
        return s
    }
}
