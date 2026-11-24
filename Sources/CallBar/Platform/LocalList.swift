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

extension Date {
    var roundedToMilliseconds: Date {
        Date(timeIntervalSince1970: (timeIntervalSince1970 * 1000).rounded() / 1000)
    }
}

private let timestampV1: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    formatter.isLenient = false
    return formatter
}()

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
            decoder.dateDecodingStrategy = .custom { decoder in
                let text = try decoder.singleValueContainer().decode(String.self)
                guard text.utf8.count == 24, let date = timestampV1.date(from: text),
                      timestampV1.string(from: date) == text else { throw ListReadIssue.unreadable }
                return date.roundedToMilliseconds
            }
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
        encoder.dateEncodingStrategy = .formatted(timestampV1)
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
