import Foundation

/// Redacts secrets from text before it is logged or included in a diagnostics bundle.
///
/// Engines stream subprocess output (and the app logs lifecycle events) into `LogStore`; some of
/// that text can contain bearer tokens, API keys, or JWTs. The scrubber applies a set of
/// conservative regular expressions that replace the secret portion with a fixed marker while
/// leaving surrounding context intact (see plans/dario-integration-architecture.md Sections 78,
/// 84, 100). It errs toward over-redaction: a few false positives are acceptable; a leaked secret
/// is not.
public enum SecretScrubber {
    /// Replacement marker substituted for any matched secret.
    public static let redaction = "[REDACTED]"

    private struct Pattern {
        let regex: NSRegularExpression
        /// The capture group index to replace (0 = whole match).
        let group: Int
    }

    private static let patterns: [Pattern] = {
        let specs: [(String, Int)] = [
            // Anthropic-style keys: sk-ant-..., sk-proj-..., sk-or-..., gsk_..., generic sk-...
            ("(sk-ant-[A-Za-z0-9._-]+)", 1),
            ("(sk-proj-[A-Za-z0-9._-]+)", 1),
            ("(sk-or-[A-Za-z0-9._-]+)", 1),
            ("(gsk_[A-Za-z0-9._-]+)", 1),
            ("(sk-[A-Za-z0-9]{16,})", 1),
            // Bearer tokens: "Authorization: Bearer <token>" -> redact the token only.
            ("(?i)(bearer\\s+)([A-Za-z0-9._\\-]+)", 2),
            // x-api-key / api-key header values.
            ("(?i)(x-api-key[\"']?\\s*[:=]\\s*[\"']?)([A-Za-z0-9._\\-]+)", 2),
            ("(?i)(\"?api[_-]?key\"?\\s*[:=]\\s*\"?)([A-Za-z0-9._\\-]{8,})", 2),
            // JWTs: three base64url segments separated by dots.
            ("(eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+)", 1),
            // access_token / refresh_token JSON fields.
            ("(?i)(\"(?:access|refresh)_token\"\\s*:\\s*\")([^\"]+)", 2)
        ]
        return specs.compactMap { pattern, group in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            return Pattern(regex: regex, group: group)
        }
    }()

    /// Returns `text` with any detected secrets replaced by `redaction`.
    public static func scrub(_ text: String) -> String {
        var result = text
        for pattern in patterns {
            result = replace(in: result, pattern: pattern)
        }
        return result
    }

    private static func replace(in text: String, pattern: Pattern) -> String {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = pattern.regex.matches(in: text, range: fullRange)
        guard !matches.isEmpty else { return text }

        // Rebuild from the end so earlier ranges stay valid as we mutate.
        let output = nsText.mutableCopy() as! NSMutableString
        for match in matches.reversed() {
            let groupRange = match.range(at: pattern.group)
            guard groupRange.location != NSNotFound else { continue }
            output.replaceCharacters(in: groupRange, with: redaction)
        }
        return output as String
    }
}
