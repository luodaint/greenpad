import AppKit

struct SyntaxToken {
    let range: NSRange
    let kind: String
}

enum Syntax {
    static func patterns(_ language: Language) -> [(String, String)] {
        if language == .plain { return [] }
        if language == .markdown {
            return [("comment", #"(?s:```.*?```)|`[^`\n]+`"#), ("keyword", #"(?m:^\s{0,3}#{1,6} .*$)"#),
                    ("string", #"\[[^\]\n]+\]\([^\)\n]*\)|\*\*[^*\n]+\*\*"#)]
        }
        if language == .html {
            return [("comment", #"(?s:<!--.*?-->)"#), ("string", #""[^"\n]*"|'[^'\n]*'"#),
                    ("keyword", #"</?[A-Za-z][\w:-]*|/?>"#), ("number", #"\b[\w:-]+(?=\s*=)"#)]
        }
        var patterns: [(String, String)] = []
        if language == .python || language == .shell {
            if language == .python { patterns.append(("string", #"(?s:""".*?"""|'''.*?''')"#)) }
            patterns.append(("comment", #"#[^\n]*"#))
        } else { patterns.append(("comment", #"//[^\n]*|(?s:/\*.*?\*/)"#)) }
        patterns.append(("string", #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#))
        let keywords: String
        switch language {
        case .python: keywords = "False None True and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield self print"
        case .swift: keywords = "actor any as associatedtype async await break case catch class continue convenience defer deinit didSet do else enum extension false fileprivate final for func guard if import in init inout internal is let mutating nil nonisolated open override private protocol public repeat required rethrows return self static struct subscript super switch throws true try typealias var weak where while willSet some"
        case .json: keywords = "true false null"
        case .shell: keywords = "if then else elif fi for do done in case esac function while until export local return echo exit"
        case .css: keywords = "important inherit initial unset auto none block flex grid relative absolute fixed solid transparent"
        case .cpp: keywords = "auto bool break case catch char class const continue default delete do double else enum extern false float for if include int long namespace new null nullptr private protected public return short signed sizeof static struct switch template this throw true try typedef unsigned using virtual void volatile while"
        default: keywords = "as async await break case catch class const constructor continue debugger default delete do else enum export extends false finally for from function get if implements import in instanceof interface let new null of private protected public return set static super switch this throw true try type typeof undefined var void while with yield"
        }
        patterns.append(("keyword", "\\b(?:" + keywords.components(separatedBy: " ").joined(separator: "|") + ")\\b"))
        patterns.append(("number", #"\b(?:0[xX][0-9a-fA-F]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\b"#))
        if language == .css { patterns.append(("type", #"#[0-9a-fA-F]{3,8}\b|--[\w-]+|[\w-]+(?=\s*:)"#)) }
        else { patterns.append(("type", #"\b[A-Z][A-Za-z0-9_]*\b"#)) }
        return patterns
    }

    static var cache: [Language: NSRegularExpression] = [:]
    static func tokens(_ text: String, language: Language) -> [SyntaxToken] {
        let patterns = patterns(language)
        guard !patterns.isEmpty else { return [] }
        let expression: NSRegularExpression
        if let cached = cache[language] { expression = cached }
        else {
            let pattern = patterns.enumerated().map { "(?<t\($0.offset)>\($0.element.1))" }.joined(separator: "|")
            guard let compiled = try? NSRegularExpression(pattern: pattern) else { return [] }
            cache[language] = compiled; expression = compiled
        }
        return expression.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).compactMap { match in
            for (index, item) in patterns.enumerated() {
                let range = match.range(withName: "t\(index)")
                if range.location != NSNotFound { return SyntaxToken(range: range, kind: item.0) }
            }
            return nil
        }
    }

    static func color(_ kind: String, dark: Bool) -> NSColor {
        switch kind {
        case "comment": return dark ? NSColor(srgbRed: 0.52, green: 0.60, blue: 0.56, alpha: 1) : NSColor(srgbRed: 0.40, green: 0.49, blue: 0.43, alpha: 1)
        case "string": return dark ? NSColor(srgbRed: 0.65, green: 0.80, blue: 0.48, alpha: 1) : NSColor(srgbRed: 0.26, green: 0.49, blue: 0.20, alpha: 1)
        case "keyword": return dark ? NSColor(srgbRed: 0.74, green: 0.64, blue: 0.98, alpha: 1) : NSColor(srgbRed: 0.46, green: 0.29, blue: 0.64, alpha: 1)
        case "number": return dark ? NSColor(srgbRed: 0.96, green: 0.70, blue: 0.45, alpha: 1) : NSColor(srgbRed: 0.68, green: 0.37, blue: 0.17, alpha: 1)
        default: return dark ? NSColor(srgbRed: 0.48, green: 0.76, blue: 0.90, alpha: 1) : NSColor(srgbRed: 0.15, green: 0.43, blue: 0.61, alpha: 1)
        }
    }
}
