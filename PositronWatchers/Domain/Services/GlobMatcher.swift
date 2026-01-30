import Foundation

final class GlobMatcher {
    private var compiledPatterns: [String: NSRegularExpression] = [:]

    func matches(_ text: String, pattern: String) -> Bool {
        guard let regex = getOrCompileRegex(for: pattern) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    func matchesAny(_ text: String, patterns: [ProcessPattern]) -> Bool {
        for pattern in patterns where pattern.isEnabled {
            if matches(text, pattern: pattern.pattern) {
                return true
            }
        }
        return false
    }

    private func getOrCompileRegex(for pattern: String) -> NSRegularExpression? {
        if let cached = compiledPatterns[pattern] {
            return cached
        }

        let regexPattern = globToRegex(pattern)
        do {
            let regex = try NSRegularExpression(pattern: regexPattern, options: .caseInsensitive)
            compiledPatterns[pattern] = regex
            return regex
        } catch {
            return nil
        }
    }

    private func globToRegex(_ glob: String) -> String {
        var result = "^"
        for char in glob {
            switch char {
            case "*":
                result += ".*"
            case "?":
                result += "."
            case ".":
                result += "\\."
            case "+":
                result += "\\+"
            case "^":
                result += "\\^"
            case "$":
                result += "\\$"
            case "(", ")":
                result += "\\\(char)"
            case "[", "]":
                result += "\\\(char)"
            case "{", "}":
                result += "\\\(char)"
            case "|":
                result += "\\|"
            case "\\":
                result += "\\\\"
            default:
                result += String(char)
            }
        }
        result += "$"
        return result
    }

    func clearCache() {
        compiledPatterns.removeAll()
    }
}
