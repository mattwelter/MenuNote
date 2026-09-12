import Cocoa

/// Custom attribute that tags every paragraph with its Notes-style role,
/// so styles survive editing and are persisted with the note.
let noteStyleKey = NSAttributedString.Key("MenuNote.paragraphStyle")

enum NoteStyle: String {
    case title, heading, subheading, body, mono, bullet, dash, numbered, checklist, quote

    var font: NSFont {
        switch self {
        case .title:      return .systemFont(ofSize: 24, weight: .bold)
        case .heading:    return .systemFont(ofSize: 18, weight: .bold)
        case .subheading: return .systemFont(ofSize: 16, weight: .semibold)
        case .mono:       return .monospacedSystemFont(ofSize: 13, weight: .regular)
        default:          return .systemFont(ofSize: 14)
        }
    }

    var isList: Bool {
        switch self {
        case .bullet, .dash, .numbered, .checklist: return true
        default: return false
        }
    }

    var paragraphStyle: NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        switch self {
        case .title:
            ps.paragraphSpacing = 6
            ps.paragraphSpacingBefore = 2
        case .heading, .subheading:
            ps.paragraphSpacing = 4
            ps.paragraphSpacingBefore = 2
        case .bullet, .dash, .numbered, .checklist:
            ps.firstLineHeadIndent = 2
            ps.headIndent = 27
            ps.tabStops = [NSTextTab(textAlignment: .left, location: 27, options: [:])]
            ps.defaultTabInterval = 27
            ps.paragraphSpacing = 2
        case .quote:
            ps.firstLineHeadIndent = 4
            ps.headIndent = 4
            // Left border bar, like the "|" in Notes' block quotes
            let block = NSTextBlock()
            block.setBorderColor(NSColor.separatorColor, for: .minX)
            block.setWidth(2, type: .absoluteValueType, for: .border, edge: .minX)
            block.setWidth(10, type: .absoluteValueType, for: .padding, edge: .minX)
            block.setWidth(1, type: .absoluteValueType, for: .padding, edge: .minY)
            block.setWidth(1, type: .absoluteValueType, for: .padding, edge: .maxY)
            ps.textBlocks = [block]
            ps.paragraphSpacing = 2
        default:
            ps.paragraphSpacing = 2
        }
        return ps
    }

    func attributes() -> [NSAttributedString.Key: Any] {
        [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.labelColor,
            noteStyleKey: rawValue
        ]
    }
}
