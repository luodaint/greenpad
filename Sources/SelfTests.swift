import AppKit

private var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fputs("FAIL: \(message)\n", stderr); exit(1) }
}

func runCoreTests() throws {
    for encoding in [TextFormat.Encoding.utf8, .utf16LE, .utf16BE] {
        for newline in ["\n", "\r\n", "\r"] {
            var format = TextFormat(); format.encoding = encoding; format.bom = true; format.newline = newline
            let text = "café 🐸\n第二行\n"
            let encoded = try format.encode(text)
            let (decoded, detected) = try TextFormat.decode(encoded)
            check(decoded == text, "Unicode round trip: \(encoding) \(newline.debugDescription)")
            check(detected.encoding == encoding && detected.newline == newline && detected.bom, "Format retained")
            let roundTrip = try detected.encode(decoded)
            check(roundTrip == encoded, "Byte-for-byte save for consistent line endings")
        }
    }
    let empty = try TextFormat.decode(Data())
    check(empty.0.isEmpty && !empty.1.bom, "Empty file")
    do { _ = try TextFormat.decode(Data([0xFF, 0x00, 0xAB])); check(false, "Reject binary bytes") } catch { check(true, "Rejected binary bytes") }
    let matches = try SearchQuery(text: "café").matches(in: "🐸 CAFÉ café")
    check(matches.count == 2 && matches[0].range.location == 3, "Unicode offsets and case insensitive find")
    let sensitive = try SearchQuery(text: "café", matchCase: true).matches(in: "CAFÉ café")
    check(sensitive.count == 1, "Case-sensitive find")
    let literal = try SearchQuery(text: ".").replacingAll(in: "a.b.c", with: "$1\\")
    check(literal.0 == "a$1\\b$1\\c" && literal.1 == 2, "Literal replacement characters")
    let regex = try SearchQuery(text: #"(\w+)=(\d+)"#, regex: true).replacingAll(in: "a=12 b=3", with: "$2:$1")
    check(regex.0 == "12:a 3:b", "Regex capture replacement")
    let zero = try SearchQuery(text: "^", regex: true).replacingAll(in: "abc", with: "x")
    check(zero.0 == "xabc" && zero.1 == 1, "Zero-length regex replacement")
    do { _ = try SearchQuery(text: "[", regex: true).expression(); check(false, "Reject invalid regex") } catch { check(true, "Invalid regex") }
    let emptySearch = try SearchQuery(text: "").replacingAll(in: "abc", with: "x")
    check(emptySearch.0 == "abc" && emptySearch.1 == 0, "Empty search doesn't replace")
    let position = lineAndColumn("🐸\nabc", offset: 5)
    check(position.0 == 2 && position.1 == 3, "Caret column after Unicode")
    check(lineStarts("a\n🐸\n") == [0, 2, 5], "Trailing blank line and UTF-16 offsets")
    let samples: [Language: String] = [.javascript: "// const ignored\nconst value = \"hello\";", .typescript: "interface Test { value: number }", .python: "# comment\ndef hello(): return 'hi'", .swift: "let value = 12", .cpp: "int main() { return 0; }", .json: "{\"key\": true}", .html: "<!-- hi --><div id=\"app\">", .css: "body { color: #fff; display: flex; }", .shell: "# hi\necho 'hello'", .markdown: "# Hello\n`code`"]
    for (language, text) in samples {
        let tokens = Syntax.tokens(text, language: language)
        check(!tokens.isEmpty, "Highlight lexer compiled for \(language.rawValue)")
        for token in tokens { check(NSMaxRange(token.range) <= (text as NSString).length, "Highlight within text") }
    }
    let comments = Syntax.tokens("// const \"hello\"\nconst x = 1", language: .javascript)
    check(comments.first?.kind == "comment" && comments.first?.range.length == 16, "Comment contents don't become keywords")
    print("PASS: \(checks) core checks")
}

func runUITests(_ app: AppDelegate) {
    do {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("Greenpad-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        app.newDocument(nil)
        guard let first = app.active else { check(false, "New document"); return }
        check(!first.isDirty && app.documents.count == 1, "New blank tab")
        first.textView.insertText("const café = 1;\nconst next = 2;", replacementRange: NSRange(location: 0, length: 0))
        check(first.isDirty && first.starts.count == 2, "Typing updates dirty flag and lines")
        first.language = .javascript; first.highlight()
        check(first.textView.textStorage?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == Syntax.color("keyword", dark: first.isDark), "Native syntax attributes")
        first.textView.undoManager?.removeAllActions()
        app.findField.stringValue = "const"; app.replaceField.stringValue = "let"
        app.replaceAll()
        check(first.textView.string == "let café = 1;\nlet next = 2;", "Replace all changes editor")
        first.textView.undoManager?.undo()
        check(first.textView.string == "const café = 1;\nconst next = 2;", "Replace all undo restores text")
        first.textView.setSelectedRange(NSRange(location: 0, length: 0)); app.findNext(nil)
        check(first.textView.selectedRange() == NSRange(location: 0, length: 5), "Find first")
        app.findNext(nil)
        check(first.textView.selectedRange().location == 16, "Find next")
        app.findNext(nil)
        check(first.textView.selectedRange().location == 0, "Find wraps")
        app.findPrevious(nil)
        check(first.textView.selectedRange().location == 16, "Previous wraps")
        app.regex.state = .on; app.findField.stringValue = "(?=o)"
        first.textView.setSelectedRange(NSRange(location: 0, length: 0)); app.findNext(nil)
        let firstZero = first.textView.selectedRange().location; app.findNext(nil)
        check(first.textView.selectedRange().location > firstZero, "Zero-length matches advance")
        app.regex.state = .off
        first.url = temporary.appendingPathComponent("sample.js")
        check(app.save(first), "Save without panel")
        let disk = try Data(contentsOf: first.url!)
        check(String(data: disk, encoding: .utf8) == first.textView.string && !first.isDirty, "Save writes exact text and clears dirty")
        app.newDocument(nil)
        check(app.documents.count == 2 && app.active?.id != first.id, "Independent tabs")
        if let scratch = app.active {
            scratch.textView.insertText("a\r\nb\rc", replacementRange: NSRange(location: 0, length: 0))
            check(scratch.textView.string == "a\nb\nc", "Pasted newlines normalize before encoding")
            scratch.replace(range: NSRange(location: 0, length: (scratch.textView.string as NSString).length), with: "")
        }
        app.select(first)
        app.openFile(first.url!)
        check(app.documents.count == 2 && app.active?.id == first.id, "Open file avoids duplicate tab")
        first.setWrap(true); check(first.textView.textContainer?.widthTracksTextView == true, "Wrap enabled")
        first.setWrap(false); check(first.textView.textContainer?.widthTracksTextView == false, "Wrap disabled")
        app.showFind(nil); check(!app.searchPanel.isHidden, "Search panel shown")
        app.hideFind(); check(app.searchPanel.isHidden, "Search panel hidden")
        app.close(first); check(app.documents.count == 1, "Clean tab closes")
        let url = temporary.appendingPathComponent("utf16.txt")
        var format = TextFormat(); format.encoding = .utf16LE; format.bom = true; format.newline = "\r\n"
        let data = try format.encode("hello\nworld\n"); try data.write(to: url)
        app.openFile(url)
        check(app.active?.format.encoding == .utf16LE && app.active?.format.newline == "\r\n", "Open retains encoding")
        if let document = app.active { check(app.save(document), "UTF-16 save") }
        let afterSave = try Data(contentsOf: url)
        check(afterSave == data, "UTF-16 disk round trip")
        print("PASS: \(checks) UI integration checks")
        exit(0)
    } catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
}
