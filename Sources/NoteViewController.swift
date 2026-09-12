import Cocoa

/// Opaque background that tracks light/dark appearance.
final class BackgroundView: NSView {
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
    }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }
}

/// Header icon button that shows a rounded highlight while hovered,
/// like the toolbar buttons in Notes.
final class HoverIconButton: NSButton {
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard isEnabled else { return }
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.09).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        layer?.backgroundColor = nil
    }
}

final class NoteViewController: NSViewController, NSTextViewDelegate {

    private(set) var textView: NoteTextView!
    private var titleLabel: NSTextField!
    private var dateLabel: NSTextField!
    private var pinButton: NSButton!

    /// Notifies the app delegate to swap between popover and floating panel.
    var onPinToggled: ((Bool) -> Void)?

    var isPinned = false {
        didSet {
            guard isPinned != oldValue else { return }
            updatePinButton()
            onPinToggled?(isPinned)
        }
    }

    private var saveTimer: Timer?
    private var isTransforming = false
    private var lastEdited = Date()

    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        return f
    }()

    // MARK: - View setup

    override func loadView() {
        let container = BackgroundView(frame: NSRect(x: 0, y: 0, width: 300, height: 400))

        // ---- Header (title + toolbar icons, Notes style) ----
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false

        titleLabel = NSTextField(labelWithString: "New Note")
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let aaButton = iconButton("textformat.size", action: #selector(showFormatMenu(_:)), enabled: true)
        let checklistButton = iconButton("checklist", action: #selector(toggleChecklist(_:)), enabled: true)
        pinButton = iconButton("pin", action: #selector(togglePin(_:)), enabled: true)
        pinButton.toolTip = "Pin on top: keep the note floating above other windows"

        let stack = NSStackView(views: [aaButton, checklistButton, pinButton])
        stack.orientation = .horizontal
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false

        header.addSubview(titleLabel)
        header.addSubview(stack)

        // ---- Date line under the header ----
        dateLabel = NSTextField(labelWithString: "")
        dateLabel.font = .systemFont(ofSize: 11)
        dateLabel.textColor = .secondaryLabelColor
        dateLabel.alignment = .center
        dateLabel.lineBreakMode = .byTruncatingTail
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        // ---- Text view ----
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let tv = NoteTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 340))
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: 280, height: CGFloat.greatestFiniteMagnitude)

        tv.isRichText = true
        tv.allowsUndo = true
        tv.usesFindBar = true
        tv.importsGraphics = false
        tv.isAutomaticSpellingCorrectionEnabled = true
        tv.isAutomaticQuoteSubstitutionEnabled = true
        tv.isAutomaticDashSubstitutionEnabled = true
        tv.isAutomaticLinkDetectionEnabled = true
        tv.isContinuousSpellCheckingEnabled = true
        tv.textColor = .textColor
        tv.backgroundColor = .textBackgroundColor
        tv.textContainerInset = NSSize(width: 10, height: 8)
        tv.typingAttributes = NoteStyle.body.attributes()
        tv.delegate = self

        tv.onCheckboxToggled = { [weak self] in self?.noteChanged() }
        tv.onToggleBold = { [weak self] in self?.toggleBold(nil) }
        tv.onToggleItalic = { [weak self] in self?.toggleItalic(nil) }

        if let saved = NoteStore.load() {
            tv.textStorage?.setAttributedString(saved)
        }
        textView = tv
        scrollView.documentView = tv

        container.addSubview(header)
        container.addSubview(dateLabel)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            header.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: stack.leadingAnchor, constant: -8),

            stack.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            dateLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            dateLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            dateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 12),

            scrollView.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        self.view = container

        if let modified = NoteStore.lastModified() {
            lastEdited = modified
        }
        refreshHeader()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        refreshHeader()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // Keep the text view exactly as wide as the visible area so text wraps
        // instead of scrolling horizontally.
        guard let scroll = textView.enclosingScrollView else { return }
        let width = scroll.contentSize.width
        if abs(textView.frame.width - width) > 0.5 {
            textView.setFrameSize(NSSize(width: width, height: textView.frame.height))
        }
    }

    private func symbolImage(_ symbol: String) -> NSImage {
        var image = NSImage(systemSymbolName: symbol, accessibilityDescription: symbol)
            ?? NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: symbol)
            ?? NSImage()
        if let configured = image.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)) {
            image = configured
        }
        return image
    }

    @objc private func togglePin(_ sender: Any?) {
        isPinned.toggle()
    }

    private func updatePinButton() {
        pinButton.image = symbolImage(isPinned ? "pin.fill" : "pin")
        pinButton.contentTintColor = isPinned ? .controlAccentColor : .secondaryLabelColor
        pinButton.toolTip = isPinned
            ? "Unpin: go back to the menu bar popover"
            : "Pin on top: keep the note floating above other windows"
    }

    private func iconButton(_ symbol: String, action: Selector?, enabled: Bool) -> NSButton {
        let image = symbolImage(symbol)
        let button = HoverIconButton(image: image, target: self, action: action)
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.contentTintColor = .secondaryLabelColor
        button.isEnabled = enabled
        button.translatesAutoresizingMaskIntoConstraints = false
        // Padding around the symbol — this is also the hover highlight area.
        button.widthAnchor.constraint(equalToConstant: 32).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return button
    }

    // MARK: - Change handling & saving

    func textDidChange(_ notification: Notification) {
        if !isTransforming {
            detectTrigger()
        }
        noteChanged()
    }

    private func noteChanged() {
        lastEdited = Date()
        refreshHeader()
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.saveNow()
        }
    }

    func saveNow() {
        guard let storage = textView?.textStorage else { return }
        NoteStore.save(storage)
    }

    private func refreshHeader() {
        var title = "New Note"
        for line in textView.string.components(separatedBy: .newlines) {
            var cleaned = line
                .replacingOccurrences(of: "\u{fffc}", with: "")
                .replacingOccurrences(of: "\t", with: " ")
                .trimmingCharacters(in: .whitespaces)
            for prefix in ["• ", "– ", "•", "–"] where cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
            if !cleaned.isEmpty {
                title = cleaned
                break
            }
        }
        titleLabel.stringValue = title
        dateLabel.stringValue = dateFormatter.string(from: lastEdited)
    }

    // MARK: - Small helpers

    private func transform(_ block: () -> Void) {
        isTransforming = true
        block()
        isTransforming = false
        noteChanged()
    }

    @discardableResult
    private func performEdit(_ range: NSRange, _ replacement: NSAttributedString) -> Bool {
        guard textView.shouldChangeText(in: range, replacementString: replacement.string) else { return false }
        textView.textStorage?.replaceCharacters(in: range, with: replacement)
        textView.didChangeText()
        return true
    }

    private func styleAtLocation(_ location: Int) -> NoteStyle {
        guard let storage = textView.textStorage, storage.length > 0, location < storage.length else { return .body }
        if let raw = storage.attribute(noteStyleKey, at: location, effectiveRange: nil) as? String,
           let style = NoteStyle(rawValue: raw) {
            return style
        }
        return .body
    }

    private func currentStyle(atParagraphStart pRange: NSRange) -> NoteStyle {
        if pRange.length > 0 {
            return styleAtLocation(pRange.location)
        }
        if let raw = textView.typingAttributes[noteStyleKey] as? String,
           let style = NoteStyle(rawValue: raw) {
            return style
        }
        return .body
    }

    private func currentStyleAtSelection() -> NoteStyle {
        let ns = textView.string as NSString
        let sel = textView.selectedRange()
        let pRange = ns.paragraphRange(for: NSRange(location: min(sel.location, ns.length), length: 0))
        return currentStyle(atParagraphStart: pRange)
    }

    private func attributesAt(_ location: Int) -> [NSAttributedString.Key: Any] {
        guard let storage = textView.textStorage, storage.length > 0 else { return NoteStyle.body.attributes() }
        return storage.attributes(at: min(location, storage.length - 1), effectiveRange: nil)
    }

    /// Length of a list prefix ("•\t", "–\t", "3.\t", checkbox+"\t") at the start of a paragraph.
    private func existingPrefixLength(in pRange: NSRange) -> Int {
        guard let storage = textView.textStorage, pRange.length > 0 else { return 0 }
        let ns = storage.string as NSString
        if storage.attribute(.attachment, at: pRange.location, effectiveRange: nil) is CheckboxAttachment {
            if pRange.length > 1, ns.character(at: pRange.location + 1) == 9 { return 2 }
            return 1
        }
        let text = ns.substring(with: pRange)
        if text.hasPrefix("\u{2022}\t") || text.hasPrefix("\u{2013}\t") { return 2 }
        let digits = text.prefix(while: { $0.isNumber })
        if !digits.isEmpty, text.dropFirst(digits.count).hasPrefix(".\t") {
            return digits.count + 2
        }
        return 0
    }

    private func prefixLength(for style: NoteStyle, number: Int) -> Int {
        switch style {
        case .bullet, .dash, .checklist: return 2
        case .numbered: return String(number).count + 2
        default: return 0
        }
    }

    private func prefixString(for style: NoteStyle, checked: Bool, number: Int,
                              attrs: [NSAttributedString.Key: Any]) -> NSAttributedString {
        switch style {
        case .bullet:
            return NSAttributedString(string: "\u{2022}\t", attributes: attrs)
        case .dash:
            return NSAttributedString(string: "\u{2013}\t", attributes: attrs)
        case .numbered:
            return NSAttributedString(string: "\(number).\t", attributes: attrs)
        case .checklist:
            let attachment = CheckboxAttachment(checked: checked)
            let result = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
            result.addAttributes(attrs, range: NSRange(location: 0, length: result.length))
            result.append(NSAttributedString(string: "\t", attributes: attrs))
            return result
        default:
            return NSAttributedString()
        }
    }

    // MARK: - Applying styles

    private func setStyle(_ style: NoteStyle, paragraphAt location: Int,
                          checked: Bool = false, startNumber: Int = 1) {
        guard let storage = textView.textStorage else { return }
        var ns = storage.string as NSString
        var pRange = ns.paragraphRange(for: NSRange(location: min(location, ns.length), length: 0))

        // 1. Strip any existing list prefix.
        let oldPrefix = existingPrefixLength(in: pRange)
        if oldPrefix > 0 {
            performEdit(NSRange(location: pRange.location, length: oldPrefix), NSAttributedString(string: ""))
            ns = storage.string as NSString
            pRange = ns.paragraphRange(for: NSRange(location: min(pRange.location, ns.length), length: 0))
        }

        // 2. Restyle the paragraph.
        let attrs = style.attributes()
        if pRange.length > 0, textView.shouldChangeText(in: pRange, replacementString: nil) {
            storage.addAttributes(attrs, range: pRange)
            textView.didChangeText()
        }
        textView.typingAttributes = attrs

        // 3. Insert the new list prefix, if any.
        if style.isList {
            performEdit(NSRange(location: pRange.location, length: 0),
                        prefixString(for: style, checked: checked, number: startNumber, attrs: attrs))
        }
        if style == .numbered {
            renumberList(around: pRange.location)
        }
    }

    private func applyStyleToSelection(_ style: NoteStyle) {
        guard let storage = textView.textStorage else { return }
        transform {
            let ns = storage.string as NSString
            let sel = textView.selectedRange()
            let full = ns.paragraphRange(for: sel)

            var starts: [Int] = []
            var loc = full.location
            while loc < full.location + full.length {
                let p = ns.paragraphRange(for: NSRange(location: loc, length: 0))
                starts.append(p.location)
                if p.length == 0 { break }
                loc = p.location + p.length
            }
            if starts.isEmpty { starts = [full.location] }

            // Process back-to-front so earlier offsets stay valid.
            for (index, start) in starts.enumerated().reversed() {
                setStyle(style, paragraphAt: start, checked: false, startNumber: index + 1)
            }
            if style == .numbered, let first = starts.first {
                renumberList(around: first)
            }

            let ns2 = storage.string as NSString
            let caret = min(sel.location + sel.length + prefixLength(for: style, number: 1), ns2.length)
            textView.setSelectedRange(NSRange(location: caret, length: 0))
        }
    }

    private func renumberList(around location: Int) {
        guard let storage = textView.textStorage else { return }
        var ns = storage.string as NSString

        // Walk back to the first numbered paragraph of this run.
        var start = ns.paragraphRange(for: NSRange(location: min(location, ns.length), length: 0)).location
        while start > 0 {
            let prev = ns.paragraphRange(for: NSRange(location: start - 1, length: 0))
            if styleAtLocation(prev.location) == .numbered {
                start = prev.location
            } else {
                break
            }
        }

        var number = 1
        var loc = start
        while true {
            ns = storage.string as NSString
            guard loc < ns.length else { break }
            let p = ns.paragraphRange(for: NSRange(location: loc, length: 0))
            guard p.length > 0, styleAtLocation(p.location) == .numbered else { break }

            let text = ns.substring(with: p)
            let digits = text.prefix(while: { $0.isNumber })
            if !digits.isEmpty, text.dropFirst(digits.count).hasPrefix(".") {
                let wanted = "\(number)"
                let digitsRange = NSRange(location: p.location, length: digits.count)
                if String(digits) != wanted {
                    performEdit(digitsRange, NSAttributedString(string: wanted, attributes: attributesAt(p.location)))
                }
            }
            number += 1

            let nsAfter = storage.string as NSString
            let pAfter = nsAfter.paragraphRange(for: NSRange(location: min(p.location, nsAfter.length), length: 0))
            if pAfter.length == 0 { break }
            loc = pAfter.location + pAfter.length
        }
    }

    // MARK: - Markdown-style triggers

    private func detectTrigger() {
        let sel = textView.selectedRange()
        guard sel.length == 0 else { return }
        let ns = textView.string as NSString
        let caret = min(sel.location, ns.length)
        let pRange = ns.paragraphRange(for: NSRange(location: caret, length: 0))
        let typedLength = caret - pRange.location
        guard typedLength > 0, typedLength <= 8 else { return }
        guard currentStyle(atParagraphStart: pRange) == .body else { return }
        let typed = ns.substring(with: NSRange(location: pRange.location, length: typedLength))

        func fire(_ style: NoteStyle, deleting count: Int, checked: Bool = false, number: Int = 1) {
            transform {
                performEdit(NSRange(location: pRange.location, length: count), NSAttributedString(string: ""))
                setStyle(style, paragraphAt: pRange.location, checked: checked, startNumber: number)
                let caretTarget = pRange.location + prefixLength(for: style, number: number)
                let limit = (textView.string as NSString).length
                textView.setSelectedRange(NSRange(location: min(caretTarget, limit), length: 0))
            }
        }

        switch typed {
        case "### ": fire(.subheading, deleting: 4)
        case "## ":  fire(.heading, deleting: 3)
        case "# ":   fire(.title, deleting: 2)
        case "- ", "* ": fire(.bullet, deleting: 2)
        case "\u{2013} ", "\u{2014} ": fire(.dash, deleting: 2)
        case "| ", "> ": fire(.quote, deleting: 2)
        case "```":  fire(.mono, deleting: 3)
        case "[] ":  fire(.checklist, deleting: 3, checked: false)
        case "[ ] ": fire(.checklist, deleting: 4, checked: false)
        case "[x] ", "[X] ": fire(.checklist, deleting: 4, checked: true)
        default:
            if typed.hasSuffix(". "), typed.count >= 3 {
                let digits = String(typed.dropLast(2))
                if !digits.isEmpty, digits.allSatisfy({ $0.isNumber }), let n = Int(digits) {
                    fire(.numbered, deleting: typed.count, number: n)
                }
            }
        }
    }

    // MARK: - Enter key: continue lists, exit on empty item, body after headings

    func textView(_ view: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }

        let sel = textView.selectedRange()
        let ns = textView.string as NSString
        let pRange = ns.paragraphRange(for: NSRange(location: min(sel.location, ns.length), length: 0))
        let style = currentStyle(atParagraphStart: pRange)

        func paragraphContentLength(afterPrefix prefix: Int) -> Int {
            var length = pRange.length - prefix
            if pRange.length > 0, ns.character(at: pRange.location + pRange.length - 1) == 10 {
                length -= 1
            }
            return length
        }

        switch style {
        case .bullet, .dash, .numbered, .checklist:
            let prefix = existingPrefixLength(in: pRange)
            if paragraphContentLength(afterPrefix: prefix) <= 0 {
                // Empty item + Enter = leave the list.
                transform {
                    setStyle(.body, paragraphAt: pRange.location)
                    textView.setSelectedRange(NSRange(location: pRange.location, length: 0))
                }
                return true
            }
            transform {
                var number = 1
                if style == .numbered {
                    let text = ns.substring(with: pRange)
                    let digits = text.prefix(while: { $0.isNumber })
                    number = (Int(digits) ?? 0) + 1
                }
                let attrs = style.attributes()
                let insertion = NSMutableAttributedString(string: "\n", attributes: attrs)
                insertion.append(prefixString(for: style, checked: false, number: number, attrs: attrs))
                performEdit(sel, insertion)
                textView.setSelectedRange(NSRange(location: sel.location + insertion.length, length: 0))
                textView.typingAttributes = attrs
                if style == .numbered {
                    renumberList(around: pRange.location)
                }
            }
            return true

        case .title, .heading, .subheading:
            // Enter after a heading starts a Body paragraph, like Notes.
            transform {
                let attrs = NoteStyle.body.attributes()
                performEdit(sel, NSAttributedString(string: "\n", attributes: attrs))
                textView.setSelectedRange(NSRange(location: sel.location + 1, length: 0))
                textView.typingAttributes = attrs
            }
            return true

        case .quote, .mono:
            if paragraphContentLength(afterPrefix: 0) <= 0 {
                transform {
                    setStyle(.body, paragraphAt: pRange.location)
                    textView.setSelectedRange(NSRange(location: pRange.location, length: 0))
                }
                return true
            }
            return false // default newline continues the quote / code block

        case .body:
            return false
        }
    }

    // MARK: - Header buttons

    @objc private func toggleChecklist(_ sender: Any?) {
        let current = currentStyleAtSelection()
        applyStyleToSelection(current == .checklist ? .body : .checklist)
        view.window?.makeFirstResponder(textView)
    }

    @objc private func showFormatMenu(_ sender: NSButton) {
        let menu = NSMenu()

        func plainItem(_ title: String, _ action: Selector, key: String) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = .command
            item.target = self
            return item
        }
        menu.addItem(plainItem("Bold", #selector(toggleBold(_:)), key: "b"))
        menu.addItem(plainItem("Italic", #selector(toggleItalic(_:)), key: "i"))
        menu.addItem(plainItem("Underline", #selector(toggleUnderline(_:)), key: "u"))
        menu.addItem(plainItem("Strikethrough", #selector(toggleStrikethrough(_:)), key: ""))
        menu.addItem(.separator())

        let current = currentStyleAtSelection()
        func styleItem(_ title: String, _ style: NoteStyle, font: NSFont) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(applyStyleFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            item.attributedTitle = NSAttributedString(
                string: title,
                attributes: [.font: font, .foregroundColor: NSColor.labelColor]
            )
            item.state = (style == current) ? .on : .off
            return item
        }

        menu.addItem(styleItem("Title", .title, font: .systemFont(ofSize: 18, weight: .bold)))
        menu.addItem(styleItem("Heading", .heading, font: .systemFont(ofSize: 16, weight: .bold)))
        menu.addItem(styleItem("Subheading", .subheading, font: .systemFont(ofSize: 14, weight: .semibold)))
        menu.addItem(styleItem("Body", .body, font: .systemFont(ofSize: 14)))
        menu.addItem(styleItem("Monostyled", .mono, font: .monospacedSystemFont(ofSize: 13, weight: .regular)))
        menu.addItem(styleItem("\u{2022} Bulleted List", .bullet, font: .systemFont(ofSize: 14)))
        menu.addItem(styleItem("\u{2013} Dashed List", .dash, font: .systemFont(ofSize: 14)))
        menu.addItem(styleItem("1. Numbered List", .numbered, font: .systemFont(ofSize: 14)))
        menu.addItem(styleItem("Checklist", .checklist, font: .systemFont(ofSize: 14)))
        menu.addItem(.separator())
        menu.addItem(styleItem("\u{2758} Block Quote", .quote, font: .systemFont(ofSize: 14)))

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 6), in: sender)
    }

    @objc private func applyStyleFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let style = NoteStyle(rawValue: raw) else { return }
        applyStyleToSelection(style)
        view.window?.makeFirstResponder(textView)
    }

    // MARK: - Inline formatting

    @objc func toggleBold(_ sender: Any?) { toggleFontTrait(.boldFontMask) }
    @objc func toggleItalic(_ sender: Any?) { toggleFontTrait(.italicFontMask) }

    @objc func toggleUnderline(_ sender: Any?) {
        textView.underline(nil)
    }

    @objc func toggleStrikethrough(_ sender: Any?) {
        let range = textView.selectedRange()
        if range.length == 0 {
            var attrs = textView.typingAttributes
            let currentValue = (attrs[.strikethroughStyle] as? Int) ?? 0
            attrs[.strikethroughStyle] = currentValue == 0 ? NSUnderlineStyle.single.rawValue : 0
            textView.typingAttributes = attrs
            return
        }
        guard let storage = textView.textStorage,
              textView.shouldChangeText(in: range, replacementString: nil) else { return }
        var turnOn = true
        if let value = storage.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil) as? Int,
           value != 0 {
            turnOn = false
        }
        storage.addAttribute(.strikethroughStyle,
                             value: turnOn ? NSUnderlineStyle.single.rawValue : 0,
                             range: range)
        textView.didChangeText()
        noteChanged()
    }

    private func toggleFontTrait(_ trait: NSFontTraitMask) {
        let fontManager = NSFontManager.shared
        let fallback = NoteStyle.body.font
        let range = textView.selectedRange()

        if range.length == 0 {
            var attrs = textView.typingAttributes
            let font = (attrs[.font] as? NSFont) ?? fallback
            let has = fontManager.traits(of: font).contains(trait)
            attrs[.font] = has
                ? fontManager.convert(font, toNotHaveTrait: trait)
                : fontManager.convert(font, toHaveTrait: trait)
            textView.typingAttributes = attrs
            return
        }

        guard let storage = textView.textStorage,
              textView.shouldChangeText(in: range, replacementString: nil) else { return }
        storage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let font = (value as? NSFont) ?? fallback
            let has = fontManager.traits(of: font).contains(trait)
            let newFont = has
                ? fontManager.convert(font, toNotHaveTrait: trait)
                : fontManager.convert(font, toHaveTrait: trait)
            storage.addAttribute(.font, value: newFont, range: subRange)
        }
        textView.didChangeText()
        noteChanged()
    }
}
