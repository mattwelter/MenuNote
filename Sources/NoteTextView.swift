import Cocoa

final class NoteTextView: NSTextView {

    var onCheckboxToggled: (() -> Void)?
    var onToggleBold: (() -> Void)?
    var onToggleItalic: (() -> Void)?

    // MARK: Pasting
    // Outside styling never enters the note: every paste is inserted as plain
    // text, which adopts the style at the cursor (Body, Heading, list, etc.).

    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    // MARK: Checkbox clicking

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if toggleCheckbox(at: point) { return }
        super.mouseDown(with: event)
    }

    private func toggleCheckbox(at point: NSPoint) -> Bool {
        guard let lm = layoutManager, let tc = textContainer,
              let storage = textStorage, storage.length > 0 else { return false }

        let local = NSPoint(x: point.x - textContainerOrigin.x,
                            y: point.y - textContainerOrigin.y)
        var fraction: CGFloat = 0
        let glyphIndex = lm.glyphIndex(for: local, in: tc, fractionOfDistanceThroughGlyph: &fraction)
        let glyphRect = lm.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: tc)
            .offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
        guard glyphRect.insetBy(dx: -3, dy: -3).contains(point) else { return false }

        let charIndex = lm.characterIndexForGlyph(at: glyphIndex)
        guard charIndex < storage.length,
              let box = storage.attribute(.attachment, at: charIndex, effectiveRange: nil) as? CheckboxAttachment
        else { return false }

        box.isChecked.toggle()
        lm.invalidateDisplay(forCharacterRange: NSRange(location: charIndex, length: 1))
        onCheckboxToggled?()
        return true
    }

    // MARK: Keyboard shortcuts
    // Menu-bar-only (accessory) apps have no visible menu bar, so we handle the
    // standard editing shortcuts directly to guarantee they always work.

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if flags == [.command] {
            switch key {
            case "a": selectAll(nil); return true
            case "c": copy(nil); return true
            case "v": paste(nil); return true
            case "x": cut(nil); return true
            case "z": undoManager?.undo(); return true
            case "b": onToggleBold?(); return true
            case "i": onToggleItalic?(); return true
            case "u": underline(nil); return true
            default: break
            }
        } else if flags == [.command, .shift], key == "z" {
            undoManager?.redo()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
