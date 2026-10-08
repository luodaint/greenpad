import Foundation

enum Language: String, CaseIterable {
    case plain = "Plain Text", javascript = "JavaScript", typescript = "TypeScript"
    case python = "Python", swift = "Swift", cpp = "C / C++", json = "JSON"
    case html = "HTML", css = "CSS", shell = "Shell", markdown = "Markdown"

    static func detect(_ url: URL?) -> Language {
        switch url?.pathExtension.lowercased() {
        case "js", "jsx", "mjs", "cjs": return .javascript
        case "ts", "tsx": return .typescript
        case "py", "pyw": return .python
        case "swift": return .swift
        case "c", "h", "cpp", "hpp", "cc", "cs", "java": return .cpp
        case "json", "jsonc": return .json
        case "html", "htm", "xml", "svg": return .html
        case "css", "scss": return .css
        case "sh", "bash", "zsh": return .shell
        case "md", "markdown": return .markdown
        default: return .plain
        }
    }
}

struct TextFormat {
    enum Encoding: String { case utf8 = "UTF-8", utf16LE = "UTF-16 LE", utf16BE = "UTF-16 BE" }
    var encoding: Encoding = .utf8
    var bom = false
    var newline = "\n"
    var newlineLabel: String { newline == "\r\n" ? "CRLF" : newline == "\r" ? "CR" : "LF" }

    static func decode(_ data: Data) throws -> (String, TextFormat) {
        var format = TextFormat()
        var payload = data
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { format.bom = true; payload = data.dropFirst(3) }
        else if data.starts(with: [0xFF, 0xFE]) {
            format.encoding = .utf16LE; format.bom = true; payload = data.dropFirst(2)
        } else if data.starts(with: [0xFE, 0xFF]) {
            format.encoding = .utf16BE; format.bom = true; payload = data.dropFirst(2)
        }
        let encoding: String.Encoding = format.encoding == .utf8 ? .utf8 : format.encoding == .utf16LE ? .utf16LittleEndian : .utf16BigEndian
        guard let text = String(data: payload, encoding: encoding), !text.contains("\0") else {
            throw NSError(domain: "Greenpad", code: 1, userInfo: [NSLocalizedDescriptionKey: "This file isn't supported text. Open UTF-8 or UTF-16 text files (UTF-16 requires a byte-order mark)."])
        }
        let crlf = text.components(separatedBy: "\r\n").count - 1
        let withoutCRLF = text.replacingOccurrences(of: "\r\n", with: "")
        let lf = withoutCRLF.components(separatedBy: "\n").count - 1
        let cr = withoutCRLF.components(separatedBy: "\r").count - 1
        if crlf > 0 && crlf >= lf && crlf >= cr { format.newline = "\r\n" }
        else if cr > lf { format.newline = "\r" }
        return (text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"), format)
    }

    func encode(_ text: String) throws -> Data {
        let converted = text.replacingOccurrences(of: "\n", with: newline)
        let encoding: String.Encoding = self.encoding == .utf8 ? .utf8 : self.encoding == .utf16LE ? .utf16LittleEndian : .utf16BigEndian
        guard var data = converted.data(using: encoding, allowLossyConversion: false) else {
            throw NSError(domain: "Greenpad", code: 2, userInfo: [NSLocalizedDescriptionKey: "The text couldn't be encoded without losing characters."])
        }
        if bom {
            let prefix: [UInt8] = self.encoding == .utf8 ? [0xEF, 0xBB, 0xBF] : self.encoding == .utf16LE ? [0xFF, 0xFE] : [0xFE, 0xFF]
            data.insert(contentsOf: prefix, at: 0)
        }
        return data
    }
}

struct SearchQuery {
    var text: String
    var matchCase = false
    var regex = false

    func expression() throws -> NSRegularExpression {
        try NSRegularExpression(pattern: regex ? text : NSRegularExpression.escapedPattern(for: text), options: matchCase ? [] : [.caseInsensitive])
    }
    func matches(in text: String) throws -> [NSTextCheckingResult] {
        guard !self.text.isEmpty else { return [] }
        return try expression().matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }
    func replacingAll(in source: String, with replacement: String) throws -> (String, Int) {
        guard !text.isEmpty else { return (source, 0) }
        let expression = try expression()
        let range = NSRange(location: 0, length: (source as NSString).length)
        let matches = expression.matches(in: source, range: range)
        let template = regex ? replacement : NSRegularExpression.escapedTemplate(for: replacement)
        return (expression.stringByReplacingMatches(in: source, range: range, withTemplate: template), matches.count)
    }
}

func lineAndColumn(_ text: String, offset: Int) -> (Int, Int) {
    let string = text as NSString
    let prefix = string.substring(to: min(max(offset, 0), string.length))
    let parts = prefix.components(separatedBy: "\n")
    return (parts.count, (parts.last ?? "").count + 1)
}

func lineStarts(_ text: String) -> [Int] {
    var starts = [0]
    for (index, unit) in text.utf16.enumerated() where unit == 10 { starts.append(index + 1) }
    return starts
}
