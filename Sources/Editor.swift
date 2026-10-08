import AppKit

final class CodeTextView: NSTextView {
    var onAppearanceChange: (() -> Void)?
    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        let value = (insertString as? NSAttributedString)?.string ?? (insertString as? String)
        if let value {
            super.insertText(value.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"), replacementRange: replacementRange)
        } else { super.insertText(insertString, replacementRange: replacementRange) }
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
    override func insertTab(_ sender: Any?) { insertText("    ", replacementRange: selectedRange()) }
    override func insertNewline(_ sender: Any?) {
        let string = self.string as NSString
        let location = selectedRange().location
        let lineRange = string.lineRange(for: NSRange(location: location, length: 0))
        let prefix = string.substring(with: NSRange(location: lineRange.location, length: location - lineRange.location))
        let indent = String(prefix.prefix { $0 == " " || $0 == "\t" })
        insertText("\n" + indent, replacementRange: selectedRange())
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty {
            let title: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 23, weight: .medium), .foregroundColor: NSColor.tertiaryLabelColor]
            let subtitle: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.tertiaryLabelColor]
            "A little space for your next idea.".draw(at: NSPoint(x: 26, y: 55), withAttributes: title)
            "Start typing, or open a file with ⌘O.".draw(at: NSPoint(x: 27, y: 92), withAttributes: subtitle)
        }
    }
}

final class LineRuler: NSRulerView {
    weak var editor: EditorDocument?
    init(scrollView: NSScrollView, editor: EditorDocument) {
        self.editor = editor
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = editor.textView
        ruleThickness = 58
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        NSColor.controlBackgroundColor.setFill(); bounds.fill()
        guard let editor, let layout = editor.textView.layoutManager, let container = editor.textView.textContainer, let scrollView else { return }
        let textView = editor.textView
        let origin = textView.textContainerOrigin
        let viewport = scrollView.contentView.bounds
        let glyphs = layout.glyphRange(forBoundingRect: NSRect(x: 0, y: max(0, viewport.minY - origin.y), width: viewport.width, height: viewport.height), in: container)
        let characters = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        let starts = editor.starts
        var lower = 0, upper = starts.count
        while lower < upper {
            let mid = (lower + upper) / 2
            if starts[mid] <= characters.location { lower = mid + 1 } else { upper = mid }
        }
        var index = max(0, lower - 1)
        let caretLine = editor.currentLine
        while index < starts.count && starts[index] <= NSMaxRange(characters) {
            let location = starts[index]
            var fragment: NSRect
            if location < (textView.string as NSString).length {
                let glyph = layout.glyphIndexForCharacter(at: location)
                fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            } else { fragment = layout.extraLineFragmentRect }
            let y = fragment.minY + origin.y - viewport.minY + 1
            if y + fragment.height >= 0 && y <= bounds.height {
                let label = String(index + 1)
                let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: index + 1 == caretLine ? .semibold : .regular), .foregroundColor: index + 1 == caretLine ? NSColor.systemGreen : NSColor.secondaryLabelColor]
                let width = label.size(withAttributes: attrs).width
                label.draw(at: NSPoint(x: ruleThickness - width - 13, y: y), withAttributes: attrs)
            }
            index += 1
        }
        NSColor.separatorColor.setFill()
        NSRect(x: ruleThickness - 1, y: 0, width: 1, height: bounds.height).fill()
    }
}

final class EditorDocument: NSObject, NSTextViewDelegate {
    let id = UUID()
    let textView: CodeTextView
    let scrollView: NSScrollView
    var url: URL?
    var untitledName: String
    var format = TextFormat()
    var language = Language.plain
    var savedText = ""
    var savedData: Data?
    var starts = [0]
    var currentLine = 1
    var onChange: (() -> Void)?
    var onSelection: (() -> Void)?
    var highlightWork: DispatchWorkItem?
    var wrapped = false
    var fontSize: CGFloat = 13
    var isDirty: Bool { textView.string != savedText }
    var title: String { url?.lastPathComponent ?? untitledName }
    var isDark: Bool { textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }

    init(name: String, text: String = "", url: URL? = nil, format: TextFormat = TextFormat(), data: Data? = nil) {
        self.untitledName = name; self.url = url; self.format = format; self.savedData = data
        scrollView = NSScrollView()
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(containerSize: NSSize(width: 10_000_000, height: 10_000_000))
        storage.addLayoutManager(layout); layout.addTextContainer(container)
        textView = CodeTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), textContainer: container)
        super.init()
        language = Language.detect(url)
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 14, height: 15)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: 10_000_000, height: 10_000_000)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        container.widthTracksTextView = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = textView
        scrollView.hasVerticalRuler = true
        scrollView.verticalRulerView = LineRuler(scrollView: scrollView, editor: self)
        scrollView.rulersVisible = true
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        textView.string = text; savedText = text; starts = lineStarts(text)
        textView.delegate = self
        textView.onAppearanceChange = { [weak self] in self?.highlight() }
        highlight()
    }
    deinit { NotificationCenter.default.removeObserver(self); highlightWork?.cancel() }
    @objc func scrolled() { scrollView.verticalRulerView?.needsDisplay = true }
    func textDidChange(_ notification: Notification) {
        starts = lineStarts(textView.string)
        updateRulerWidth()
        highlightWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.highlight() }
        highlightWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        onChange?()
        textViewDidChangeSelection(notification)
    }
    func textViewDidChangeSelection(_ notification: Notification) {
        let location = textView.selectedRange().location
        var lower = 0, upper = starts.count
        while lower < upper {
            let mid = (lower + upper) / 2
            if starts[mid] <= location { lower = mid + 1 } else { upper = mid }
        }
        currentLine = max(1, lower)
        scrollView.verticalRulerView?.needsDisplay = true
        onSelection?()
    }
    func updateRulerWidth() {
        scrollView.verticalRulerView?.ruleThickness = max(58, CGFloat(String(starts.count).count) * 8 + 24)
        scrollView.verticalRulerView?.needsDisplay = true
    }
    func highlight() {
        guard let storage = textView.textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.defaultTabInterval = fontSize * 2.4
        paragraph.tabStops = []
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font
        textView.backgroundColor = isDark ? NSColor(srgbRed: 0.10, green: 0.12, blue: 0.11, alpha: 1) : NSColor.textBackgroundColor
        textView.insertionPointColor = .systemGreen
        let foreground: NSColor = isDark ? NSColor(srgbRed: 0.86, green: 0.89, blue: 0.87, alpha: 1) : .textColor
        textView.textColor = foreground
        let base: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: foreground, .paragraphStyle: paragraph]
        storage.beginEditing()
        storage.setAttributes(base, range: full)
        // Keep large text documents responsive; syntax colors are intentionally bounded.
        if storage.length <= 1_000_000 {
            for token in Syntax.tokens(textView.string, language: language) {
                storage.addAttribute(.foregroundColor, value: Syntax.color(token.kind, dark: isDark), range: token.range)
            }
        }
        storage.endEditing()
        textView.typingAttributes = base
        scrollView.verticalRulerView?.needsDisplay = true
    }
    func setWrap(_ wrap: Bool) {
        wrapped = wrap
        textView.isHorizontallyResizable = !wrap
        scrollView.hasHorizontalScroller = !wrap
        textView.textContainer?.widthTracksTextView = wrap
        if wrap {
            textView.setFrameSize(NSSize(width: scrollView.contentSize.width, height: max(scrollView.contentSize.height, textView.frame.height)))
            textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: 10_000_000)
        } else { textView.textContainer?.containerSize = NSSize(width: 10_000_000, height: 10_000_000) }
        scrollView.verticalRulerView?.needsDisplay = true
    }
    @discardableResult func replace(range: NSRange, with text: String, action: String = "Replace") -> Bool {
        let text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        guard textView.shouldChangeText(in: range, replacementString: text) else { return false }
        textView.textStorage?.replaceCharacters(in: range, with: text)
        textView.didChangeText()
        textView.undoManager?.setActionName(action)
        textView.setSelectedRange(NSRange(location: range.location + (text as NSString).length, length: 0))
        return true
    }
}
