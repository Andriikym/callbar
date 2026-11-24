import Foundation

enum ListReadIssue: Error, Equatable {
    case unreadable
    case newerVersion(Int)

    func message(for list: StoredListKind) -> String {
        switch self {
        case .unreadable: return "Couldn’t read \(list.displayName). Retry to reload the file."
        case .newerVersion: return "A newer version of CallBar saved \(list.displayName). Update CallBar to open it."
        }
    }
}

enum StoredListKind {
    case favorites
    case recents

    var displayName: String {
        switch self {
        case .favorites: return "Favorites"
        case .recents: return "Recents"
        }
    }
}

private struct ListFileV1<Entry: Codable>: Codable {
    let schemaVersion: Int
    let entries: [Entry]

    init(entries: [Entry]) {
        self.schemaVersion = 1
        self.entries = entries
    }

    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try fields.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion <= 1 else { throw ListReadIssue.newerVersion(schemaVersion) }
        guard schemaVersion == 1 else { throw ListReadIssue.unreadable }
        entries = try fields.decode([Entry].self, forKey: .entries)
    }
}

struct LocalList<Entry: Codable & Identifiable> {
    let url: URL
    private let validateEntries: ([Entry]) throws -> Void
    private(set) var entries: [Entry] = []
    private(set) var readIssue: ListReadIssue?

    init(url: URL, validate: @escaping ([Entry]) throws -> Void) {
        self.url = url
        self.validateEntries = validate
        reload()
    }

    mutating func reload() {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let file = try decoder.decode(ListFileV1<Entry>.self, from: Data(contentsOf: url))
            try validate(file.entries)
            entries = file.entries
            readIssue = nil
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            entries = []
            readIssue = nil
        } catch {
            readIssue = error as? ListReadIssue ?? .unreadable
        }
    }

    mutating func commit(_ updated: [Entry]) throws {
        if let readIssue { throw readIssue }
        try validate(updated)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(ListFileV1(entries: updated))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try data.write(to: url, options: .atomic)
        entries = updated
    }

    private func validate(_ entries: [Entry]) throws {
        guard Set(entries.map(\.id)).count == entries.count else { throw ListReadIssue.unreadable }
        try validateEntries(entries)
    }
}
