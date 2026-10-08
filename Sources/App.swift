import AppKit
import UniformTypeIdentifiers

final class ActionButton: NSButton {
    var handler: (() -> Void)?
    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        self.title = title; bezelStyle = .rounded; target = self; action = #selector(invoke)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc func invoke() { handler?() }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSToolbarDelegate, NSSearchFieldDelegate, NSMenuItemValidation {
    var window: NSWindow!
    var documents: [EditorDocument] = []
    var activeID: UUID?
    var untitledCount = 0
    let root = NSStackView()
    let tabStack = NSStackView()
    let tabScroll = NSScrollView()
    let editorHost = NSView()
    let searchPanel = NSStackView()
    let findField = NSSearchField()
    let replaceField = NSTextField()
    let matchCase = NSButton(checkboxWithTitle: "Match case", target: nil, action: nil)
    let regex = NSButton(checkboxWithTitle: "Regex", target: nil, action: nil)
    let searchStatus = NSTextField(labelWithString: "")
    let positionLabel = NSTextField(labelWithString: "")
    let formatLabel = NSTextField(labelWithString: "")
    let languageMenu = NSPopUpButton()
    let wrapButton = NSButton(checkboxWithTitle: "Word wrap", target: nil, action: nil)
    var lastZeroMatch: (UUID, NSRange)?
    var appearanceMode = "System"
    var active: EditorDocument? { documents.first { $0.id == activeID } }
    var query: SearchQuery { SearchQuery(text: findField.stringValue, matchCase: matchCase.state == .on, regex: regex.state == .on) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu(); buildWindow()
        if documents.isEmpty && !CommandLine.arguments.contains("--ui-test") { newDocument(nil) }
        let paths = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }
        for path in paths { openFile(URL(fileURLWithPath: path)) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if CommandLine.arguments.contains("--ui-test") {
            DispatchQueue.main.async { runUITests(self) }
        }
    }
    func application(_ sender: NSApplication, open urls: [URL]) {
        // Finder may deliver files before the initial launch callback.
        if window == nil { buildMenu(); buildWindow() }
        urls.forEach(openFile)
        window.makeKeyAndOrderFront(nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil)
        if documents.isEmpty { newDocument(nil) }
        return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        reviewUnsaved() ? .terminateNow : .terminateCancel
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { reviewUnsaved() }
    func reviewUnsaved() -> Bool {
        for document in documents where document.isDirty {
            select(document)
            if !confirmClose(document) { return false }
        }
        return true
    }

    func menuItem(_ menu: NSMenu, _ title: String, _ action: Selector?, _ key: String = "", modifiers: NSEvent.ModifierFlags = [.command], target: AnyObject? = nil) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = target ?? self
        menu.addItem(item)
    }
    func submenu(_ menu: NSMenu, title: String) -> NSMenu {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let child = NSMenu(title: title); item.submenu = child; menu.addItem(item); return child
    }
    func buildMenu() {
        let main = NSMenu()
        let app = submenu(main, title: "Greenpad")
        menuItem(app, "About Greenpad", #selector(about))
        app.addItem(.separator())
        menuItem(app, "Hide Greenpad", #selector(NSApplication.hide(_:)), "h", target: NSApp)
        app.addItem(.separator())
        menuItem(app, "Quit Greenpad", #selector(NSApplication.terminate(_:)), "q", target: NSApp)
        let file = submenu(main, title: "File")
        menuItem(file, "New Tab", #selector(newDocument(_:)), "n")
        menuItem(file, "Open…", #selector(openDocument(_:)), "o")
        file.addItem(.separator())
        menuItem(file, "Save", #selector(saveDocument(_:)), "s")
        menuItem(file, "Save As…", #selector(saveAs(_:)), "s", modifiers: [.command, .shift])
        file.addItem(.separator())
        menuItem(file, "Close Tab", #selector(closeDocument(_:)), "w")
        let edit = submenu(main, title: "Edit")
        for (title, action, key, modifiers) in [
            ("Undo", "undo:", "z", NSEvent.ModifierFlags.command),
            ("Redo", "redo:", "z", [.command, .shift]),
            ("Cut", "cut:", "x", .command), ("Copy", "copy:", "c", .command),
            ("Paste", "paste:", "v", .command), ("Select All", "selectAll:", "a", .command)
        ] {
            let item = NSMenuItem(title: title, action: NSSelectorFromString(action), keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers; edit.addItem(item)
        }
        let search = submenu(main, title: "Search")
        menuItem(search, "Find…", #selector(showFind(_:)), "f")
        menuItem(search, "Find Next", #selector(findNext(_:)), "g")
        menuItem(search, "Find Previous", #selector(findPrevious(_:)), "g", modifiers: [.command, .shift])
        menuItem(search, "Use Selection for Find", #selector(useSelection(_:)), "e")
        menuItem(search, "Go to Line…", #selector(goToLine(_:)), "l")
        let view = submenu(main, title: "View")
        menuItem(view, "Word Wrap", #selector(toggleWrap(_:)), "w", modifiers: [.command, .option])
        menuItem(view, "Increase Font Size", #selector(increaseFont(_:)), "+")
        menuItem(view, "Decrease Font Size", #selector(decreaseFont(_:)), "-")
        menuItem(view, "Reset Font Size", #selector(resetFont(_:)), "0")
        let appearance = submenu(view, title: "Appearance")
        for title in ["System", "Light", "Dark"] { menuItem(appearance, title, #selector(changeAppearance(_:))) }
        let tabs = submenu(main, title: "Window")
        menuItem(tabs, "Next Tab", #selector(nextTab(_:)), "]", modifiers: [.command, .shift])
        menuItem(tabs, "Previous Tab", #selector(previousTab(_:)), "[", modifiers: [.command, .shift])
        menuItem(tabs, "Minimize", #selector(NSWindow.miniaturize(_:)), "m", target: nil)
        tabs.items.last?.target = nil
        NSApp.windowsMenu = tabs
        NSApp.mainMenu = main
    }

    func buildWindow() {
        guard window == nil else { return }
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 730), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Greenpad"
        window.minSize = NSSize(width: 820, height: 450)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.tabbingMode = .disallowed
        window.center()
        window.toolbarStyle = .unifiedCompact
        let toolbar = NSToolbar(identifier: "GreenpadToolbar")
        toolbar.delegate = self; toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        let content = NSView()
        root.orientation = .vertical; root.alignment = .leading; root.spacing = 0; root.distribution = .fill
        root.detachesHiddenViews = true
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        window.contentView = content
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo: content.leadingAnchor), root.trailingAnchor.constraint(equalTo: content.trailingAnchor), root.topAnchor.constraint(equalTo: content.topAnchor), root.bottomAnchor.constraint(equalTo: content.bottomAnchor)])

        tabStack.orientation = .horizontal; tabStack.spacing = 4; tabStack.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        tabScroll.drawsBackground = true; tabScroll.backgroundColor = .controlBackgroundColor
        tabScroll.hasHorizontalScroller = true; tabScroll.autohidesScrollers = true
        tabScroll.documentView = tabStack
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([tabStack.leadingAnchor.constraint(equalTo: tabScroll.contentView.leadingAnchor), tabStack.topAnchor.constraint(equalTo: tabScroll.contentView.topAnchor), tabStack.heightAnchor.constraint(equalToConstant: 42)])
        addFullWidth(tabScroll, height: 46)
        buildSearchPanel()
        addFullWidth(searchPanel)
        searchPanel.isHidden = true
        addFullWidth(editorHost)
        editorHost.setContentHuggingPriority(.defaultLow, for: .vertical)

        let status = NSStackView()
        status.orientation = .horizontal; status.spacing = 18
        status.edgeInsets = NSEdgeInsets(top: 5, left: 16, bottom: 5, right: 12)
        for label in [positionLabel, formatLabel] { label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular); label.textColor = .secondaryLabelColor }
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        languageMenu.addItems(withTitles: Language.allCases.map(\.rawValue))
        languageMenu.target = self; languageMenu.action = #selector(changeLanguage(_:))
        languageMenu.controlSize = .small; languageMenu.font = .systemFont(ofSize: 11)
        wrapButton.controlSize = .small; wrapButton.font = .systemFont(ofSize: 11)
        wrapButton.target = self; wrapButton.action = #selector(toggleWrap(_:))
        [positionLabel, spacer, languageMenu, formatLabel, wrapButton].forEach(status.addArrangedSubview)
        addFullWidth(status, height: 34)
    }
    func addFullWidth(_ view: NSView, height: CGFloat? = nil) {
        view.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        if let height { view.heightAnchor.constraint(equalToConstant: height).isActive = true }
    }
    func buildSearchPanel() {
        searchPanel.orientation = .vertical; searchPanel.alignment = .leading; searchPanel.spacing = 6
        searchPanel.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        findField.placeholderString = "Find in this tab"; findField.delegate = self
        findField.sendsSearchStringImmediately = true
        findField.target = self; findField.action = #selector(findNext(_:))
        findField.widthAnchor.constraint(greaterThanOrEqualToConstant: 230).isActive = true
        replaceField.placeholderString = "Replace with"; replaceField.delegate = self
        for control in [matchCase, regex] { control.target = self; control.action = #selector(searchOptions(_:)); control.font = .systemFont(ofSize: 11) }
        let first = NSStackView(views: [findField, ActionButton(title: "Previous") { [weak self] in self?.findPrevious(nil) }, ActionButton(title: "Next") { [weak self] in self?.findNext(nil) }, matchCase, regex, ActionButton(title: "Done") { [weak self] in self?.hideFind() }])
        first.orientation = .horizontal; first.spacing = 8
        searchStatus.font = .systemFont(ofSize: 11); searchStatus.textColor = .secondaryLabelColor
        searchStatus.lineBreakMode = .byTruncatingTail
        searchStatus.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let second = NSStackView(views: [replaceField, ActionButton(title: "Replace") { [weak self] in self?.replaceOne() }, ActionButton(title: "Replace All") { [weak self] in self?.replaceAll() }, searchStatus])
        second.orientation = .horizontal; second.spacing = 8
        for row in [first, second] {
            searchPanel.addArrangedSubview(row); row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: searchPanel.widthAnchor, constant: -28).isActive = true
        }
        replaceField.widthAnchor.constraint(equalTo: findField.widthAnchor).isActive = true
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarDefaultItemIdentifiers(toolbar) }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [NSToolbarItem.Identifier("new"), NSToolbarItem.Identifier("open"), NSToolbarItem.Identifier("save"), .flexibleSpace, NSToolbarItem.Identifier("find"), NSToolbarItem.Identifier("wrap")]
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let options: [String: (String, String, Selector)] = [
            "new": ("New Tab (⌘N)", "plus", #selector(newDocument(_:))),
            "open": ("Open File (⌘O)", "folder", #selector(openDocument(_:))),
            "save": ("Save (⌘S)", "square.and.arrow.down", #selector(saveDocument(_:))),
            "find": ("Find & Replace (⌘F)", "magnifyingglass", #selector(showFind(_:))),
            "wrap": ("Toggle Word Wrap", "text.word.spacing", #selector(toggleWrap(_:)))
        ]
        guard let option = options[id.rawValue] else { return nil }
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = option.0; item.toolTip = option.0
        item.image = NSImage(systemSymbolName: option.1, accessibilityDescription: option.0)
        item.target = self; item.action = option.2
        return item
    }

    func add(_ document: EditorDocument) {
        documents.append(document)
        document.onChange = { [weak self, weak document] in
            guard let self, let document else { return }
            self.updateTab(document); self.updateStatus(); self.updateSearchStatus()
        }
        document.onSelection = { [weak self] in self?.updateStatus() }
        select(document)
    }
    func select(_ document: EditorDocument) {
        activeID = document.id
        editorHost.subviews.forEach { $0.removeFromSuperview() }
        let view = document.scrollView
        view.translatesAutoresizingMaskIntoConstraints = false; editorHost.addSubview(view)
        NSLayoutConstraint.activate([view.leadingAnchor.constraint(equalTo: editorHost.leadingAnchor), view.trailingAnchor.constraint(equalTo: editorHost.trailingAnchor), view.topAnchor.constraint(equalTo: editorHost.topAnchor), view.bottomAnchor.constraint(equalTo: editorHost.bottomAnchor)])
        window.contentView?.layoutSubtreeIfNeeded()
        document.setWrap(document.wrapped)
        renderTabs(); updateStatus(); updateSearchStatus()
        window.makeFirstResponder(document.textView)
    }
    func renderTabs() {
        tabStack.arrangedSubviews.forEach { tabStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        for document in documents {
            let tab = NSStackView()
            tab.identifier = NSUserInterfaceItemIdentifier(document.id.uuidString)
            tab.orientation = .horizontal; tab.spacing = 2
            tab.wantsLayer = true; tab.layer?.cornerRadius = 6
            tab.layer?.backgroundColor = (document.id == activeID ? NSColor.systemGreen.withAlphaComponent(0.12) : NSColor.clear).cgColor
            tab.edgeInsets = NSEdgeInsets(top: 1, left: 7, bottom: 1, right: 5)
            let selectButton = ActionButton(title: tabTitle(document)) { [weak self, weak document] in if let document { self?.select(document) } }
            selectButton.isBordered = false; selectButton.font = .systemFont(ofSize: 12, weight: document.id == activeID ? .medium : .regular)
            selectButton.contentTintColor = document.id == activeID ? .labelColor : .secondaryLabelColor
            selectButton.lineBreakMode = .byTruncatingMiddle
            selectButton.toolTip = document.url?.path ?? document.title
            selectButton.widthAnchor.constraint(lessThanOrEqualToConstant: 200).isActive = true
            let close = ActionButton(title: "") { [weak self, weak document] in if let document { self?.close(document) } }
            close.isBordered = false; close.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close \(document.title)")
            close.image?.size = NSSize(width: 9, height: 9)
            close.contentTintColor = .secondaryLabelColor
            close.widthAnchor.constraint(equalToConstant: 20).isActive = true
            tab.addArrangedSubview(selectButton); tab.addArrangedSubview(close)
            tab.heightAnchor.constraint(equalToConstant: 29).isActive = true
            tabStack.addArrangedSubview(tab)
        }
        let plus = ActionButton(title: "+") { [weak self] in self?.newDocument(nil) }
        plus.isBordered = false; plus.toolTip = "New Tab (⌘N)"; plus.widthAnchor.constraint(equalToConstant: 28).isActive = true
        tabStack.addArrangedSubview(plus)
        tabStack.layoutSubtreeIfNeeded()
        if let active = tabStack.arrangedSubviews.first(where: { $0.identifier?.rawValue == activeID?.uuidString }) { tabStack.scrollToVisible(active.frame) }
    }
    func tabTitle(_ document: EditorDocument) -> String { (document.isDirty ? "●  " : "") + document.title }
    func updateTab(_ document: EditorDocument) {
        if let tab = tabStack.arrangedSubviews.first(where: { $0.identifier?.rawValue == document.id.uuidString }) as? NSStackView, let button = tab.arrangedSubviews.first as? NSButton { button.title = tabTitle(document) }
    }
    func updateStatus() {
        guard let document = active else { return }
        let position = lineAndColumn(document.textView.string, offset: document.textView.selectedRange().location)
        let selection = document.textView.selectedRange().length
        positionLabel.stringValue = "Ln \(position.0), Col \(position.1)    ·    \(document.starts.count) lines" + (selection > 0 ? "    ·    \(selection) selected" : "")
        formatLabel.stringValue = "\(document.format.encoding.rawValue)    ·    \(document.format.newlineLabel)"
        languageMenu.selectItem(withTitle: document.language.rawValue)
        wrapButton.state = document.wrapped ? .on : .off
        window.title = "\(document.title) — Greenpad"
        window.isDocumentEdited = document.isDirty
        window.representedURL = document.url
    }

    @objc func newDocument(_ sender: Any?) {
        untitledCount += 1; add(EditorDocument(name: "Untitled \(untitledCount)"))
    }
    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.message = "Open text or source files"
        if panel.runModal() == .OK { panel.urls.forEach(openFile) }
    }
    func openFile(_ url: URL) {
        let url = url.standardizedFileURL.resolvingSymlinksInPath()
        if let existing = documents.first(where: { $0.url?.standardizedFileURL.resolvingSymlinksInPath() == url }) { select(existing); return }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? NSNumber, size.intValue > 20_000_000 {
                throw NSError(domain: "Greenpad", code: 3, userInfo: [NSLocalizedDescriptionKey: "This first version supports text files up to 20 MB."])
            }
            let data = try Data(contentsOf: url)
            let (text, format) = try TextFormat.decode(data)
            if documents.count == 1, let empty = active, empty.url == nil, empty.textView.string.isEmpty { documents.removeAll() }
            add(EditorDocument(name: url.lastPathComponent, text: text, url: url, format: format, data: data))
        } catch { present(error) }
    }
    @objc func saveDocument(_ sender: Any?) { if let document = active { _ = save(document) } }
    @objc func saveAs(_ sender: Any?) { if let document = active { _ = save(document, saveAs: true) } }
    @discardableResult func save(_ document: EditorDocument, saveAs: Bool = false) -> Bool {
        var destination = document.url
        if destination == nil || saveAs {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = document.url?.lastPathComponent ?? "Untitled.txt"
            panel.directoryURL = document.url?.deletingLastPathComponent()
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else { return false }
            destination = url.standardizedFileURL.resolvingSymlinksInPath()
        }
        guard let destination else { return false }
        if let existing = documents.first(where: { $0.id != document.id && $0.url?.standardizedFileURL.resolvingSymlinksInPath() == destination.standardizedFileURL.resolvingSymlinksInPath() }) {
            let alert = NSAlert(); alert.messageText = "This file is open in another tab."
            alert.informativeText = "Close the other tab before saving to \(existing.title)."; alert.runModal(); return false
        }
        do {
            if destination == document.url, let original = document.savedData {
                let current = try? Data(contentsOf: destination)
                if current != original {
                    let alert = NSAlert(); alert.messageText = "The file changed outside Greenpad."
                    alert.informativeText = "Overwrite the disk version with the text in this tab?"
                    alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Overwrite")
                    guard alert.runModal() == .alertSecondButtonReturn else { return false }
                }
            }
            let data = try document.format.encode(document.textView.string)
            try data.write(to: destination, options: .atomic)
            let wasUntitled = document.url == nil
            document.url = destination; document.savedText = document.textView.string; document.savedData = data
            if wasUntitled && document.language == .plain { document.language = Language.detect(destination); document.highlight() }
            renderTabs(); updateStatus(); return true
        } catch { present(error); return false }
    }
    func present(_ error: Error) { NSAlert(error: error).runModal() }
    func confirmClose(_ document: EditorDocument) -> Bool {
        guard document.isDirty else { return true }
        let alert = NSAlert(); alert.messageText = "Save changes to “\(document.title)”?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Don't Save")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return save(document)
        case .alertThirdButtonReturn: return true
        default: return false
        }
    }
    @objc func closeDocument(_ sender: Any?) { if let document = active { close(document) } }
    func close(_ document: EditorDocument) {
        guard confirmClose(document), let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents.remove(at: index)
        if documents.isEmpty { newDocument(nil) }
        else if activeID == document.id { select(documents[min(index, documents.count - 1)]) }
        else { renderTabs() }
    }

    @objc func showFind(_ sender: Any?) {
        searchPanel.isHidden = false
        if let document = active, document.textView.selectedRange().length > 0 {
            let selected = (document.textView.string as NSString).substring(with: document.textView.selectedRange())
            if !selected.contains("\n") { findField.stringValue = selected }
        }
        updateSearchStatus(); window.makeFirstResponder(findField)
    }
    func hideFind() { searchPanel.isHidden = true; if let active { window.makeFirstResponder(active.textView) } }
    @objc func searchOptions(_ sender: Any?) { lastZeroMatch = nil; updateSearchStatus() }
    func controlTextDidChange(_ obj: Notification) { lastZeroMatch = nil; updateSearchStatus() }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { hideFind(); return true }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if control === findField { findNext(nil) } else { replaceOne() }
            return true
        }
        return false
    }
    func updateSearchStatus() {
        guard let document = active else { return }
        guard !query.text.isEmpty else { searchStatus.stringValue = ""; return }
        do { let count = try query.matches(in: document.textView.string).count; searchStatus.stringValue = "\(count) \(count == 1 ? "match" : "matches")"; searchStatus.textColor = .secondaryLabelColor }
        catch { searchStatus.stringValue = "Invalid regular expression"; searchStatus.textColor = .systemRed }
    }
    @objc func findNext(_ sender: Any?) { find(backward: false) }
    @objc func findPrevious(_ sender: Any?) { find(backward: true) }
    func find(backward: Bool) {
        guard let document = active, !query.text.isEmpty else { return }
        do {
            let matches = try query.matches(in: document.textView.string)
            guard !matches.isEmpty else { searchStatus.stringValue = "No matches"; NSSound.beep(); return }
            let selection = document.textView.selectedRange()
            let zeroWasSelected = lastZeroMatch?.0 == document.id && lastZeroMatch?.1 == selection
            let start = NSMaxRange(selection) + (zeroWasSelected ? 1 : 0)
            let match = backward ? (matches.last { $0.range.location < selection.location } ?? matches.last!) : (matches.first { $0.range.location >= start } ?? matches.first!)
            document.textView.setSelectedRange(match.range)
            document.textView.scrollRangeToVisible(match.range)
            lastZeroMatch = match.range.length == 0 ? (document.id, match.range) : nil
            let index = matches.firstIndex { $0.range == match.range } ?? 0
            searchStatus.stringValue = "\(index + 1) of \(matches.count) matches"
            searchStatus.textColor = .secondaryLabelColor
        } catch { updateSearchStatus() }
    }
    @objc func useSelection(_ sender: Any?) {
        guard let document = active, document.textView.selectedRange().length > 0 else { return }
        findField.stringValue = (document.textView.string as NSString).substring(with: document.textView.selectedRange())
        updateSearchStatus()
    }
    func replaceOne() {
        guard let document = active, !query.text.isEmpty else { return }
        do {
            let expression = try query.expression()
            let text = document.textView.string
            let matches = try query.matches(in: text)
            guard let match = matches.first(where: { $0.range == document.textView.selectedRange() }) else { findNext(nil); return }
            let replacement = query.regex ? expression.replacementString(for: match, in: text, offset: 0, template: replaceField.stringValue) : replaceField.stringValue
            document.replace(range: match.range, with: replacement)
            lastZeroMatch = match.range.length == 0 ? (document.id, document.textView.selectedRange()) : nil
            findNext(nil)
        } catch { updateSearchStatus() }
    }
    func replaceAll() {
        guard let document = active else { return }
        do {
            let (text, count) = try query.replacingAll(in: document.textView.string, with: replaceField.stringValue)
            guard count > 0 else { updateSearchStatus(); return }
            document.replace(range: NSRange(location: 0, length: (document.textView.string as NSString).length), with: text, action: "Replace All")
            lastZeroMatch = nil; searchStatus.stringValue = "Replaced \(count) \(count == 1 ? "match" : "matches")"
        } catch { updateSearchStatus() }
    }
    @objc func changeLanguage(_ sender: Any?) {
        guard let document = active, let title = languageMenu.titleOfSelectedItem, let language = Language(rawValue: title) else { return }
        document.language = language; document.highlight(); updateStatus()
    }
    @objc func toggleWrap(_ sender: Any?) { guard let document = active else { return }; document.setWrap(!document.wrapped); updateStatus() }
    @objc func increaseFont(_ sender: Any?) { adjustFont(1) }
    @objc func decreaseFont(_ sender: Any?) { adjustFont(-1) }
    @objc func resetFont(_ sender: Any?) { active?.fontSize = 13; active?.highlight() }
    func adjustFont(_ delta: CGFloat) { guard let document = active else { return }; document.fontSize = min(32, max(9, document.fontSize + delta)); document.highlight() }
    @objc func changeAppearance(_ sender: NSMenuItem) {
        appearanceMode = sender.title
        window.appearance = sender.title == "System" ? nil : NSAppearance(named: sender.title == "Dark" ? .darkAqua : .aqua)
        for document in documents { document.highlight() }
        renderTabs()
    }
    @objc func nextTab(_ sender: Any?) { cycleTab(1) }
    @objc func previousTab(_ sender: Any?) { cycleTab(-1) }
    func cycleTab(_ delta: Int) {
        guard let index = documents.firstIndex(where: { $0.id == activeID }) else { return }
        select(documents[(index + delta + documents.count) % documents.count])
    }
    @objc func goToLine(_ sender: Any?) {
        guard let document = active else { return }
        let alert = NSAlert(); alert.messageText = "Go to line"; alert.informativeText = "Enter a line from 1 to \(document.starts.count)."
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24)); input.stringValue = String(document.currentLine)
        alert.accessoryView = input; alert.addButton(withTitle: "Go"); alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = input
        if alert.runModal() == .alertFirstButtonReturn, let line = Int(input.stringValue), line > 0, line <= document.starts.count {
            let range = NSRange(location: document.starts[line - 1], length: 0)
            document.textView.setSelectedRange(range); document.textView.scrollRangeToVisible(range); window.makeFirstResponder(document.textView)
        }
    }
    @objc func about() {
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Greenpad", .applicationVersion: "0.1", .version: "1", .credits: NSAttributedString(string: "A small native Mac text editor.\nInspired by the everyday workflow of Notepad++.\nIndependent software; not affiliated with Notepad++.")])
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleWrap(_:)) { menuItem.state = active?.wrapped == true ? .on : .off }
        if menuItem.action == #selector(changeAppearance(_:)) { menuItem.state = menuItem.title == appearanceMode ? .on : .off }
        return true
    }
}
