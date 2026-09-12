import Cocoa

/// The round Notes-style checkbox that lives at the start of a checklist line.
/// It is a text attachment, so it flows with the text and is archived with the note.
final class CheckboxAttachment: NSTextAttachment {

    var isChecked: Bool = false {
        didSet { updateImage() }
    }

    init(checked: Bool) {
        super.init(data: nil, ofType: nil)
        isChecked = checked
        updateImage()
    }

    // NSTextAttachment's decoding machinery calls this designated initializer
    // on the subclass; without it, loading a saved checkbox crashes.
    override init(data contentData: Data?, ofType uti: String?) {
        super.init(data: contentData, ofType: uti)
        updateImage()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isChecked = coder.decodeBool(forKey: "MenuNote.isChecked")
        updateImage()
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(isChecked, forKey: "MenuNote.isChecked")
    }

    private func updateImage() {
        image = CheckboxAttachment.symbolImage(checked: isChecked)
        bounds = CGRect(x: 0, y: -4, width: 18, height: 18)
    }

    static func symbolImage(checked: Bool) -> NSImage {
        let name = checked ? "checkmark.circle.fill" : "circle"
        var base = NSImage(systemSymbolName: name, accessibilityDescription: name) ?? NSImage()
        if let configured = base.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15.5, weight: .regular)) {
            base = configured
        }
        let tint: NSColor = checked ? .systemOrange : .tertiaryLabelColor
        return NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            base.draw(in: rect)
            tint.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}
