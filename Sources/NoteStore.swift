import Cocoa

enum NoteStore {

    static let directory: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MenuNote", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Keyed archive of the attributed string — keeps fonts, styles, and checkbox state.
    static let fileURL = directory.appendingPathComponent("note.data")

    /// v1 of the app saved plain RTF; still read it once for migration.
    static let legacyRTFURL = directory.appendingPathComponent("note.rtf")

    static func load() -> NSAttributedString? {
        if let data = try? Data(contentsOf: fileURL),
           let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) {
            unarchiver.requiresSecureCoding = false
            if let note = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString {
                return note
            }
        }
        if let data = try? Data(contentsOf: legacyRTFURL),
           let note = NSAttributedString(rtf: data, documentAttributes: nil) {
            return note
        }
        return nil
    }

    static func save(_ text: NSAttributedString) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: text, requiringSecureCoding: false) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func lastModified() -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return attrs?[.modificationDate] as? Date
    }
}
