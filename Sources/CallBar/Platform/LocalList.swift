import Foundation

struct LocalList<Entry: Codable> {
    let url: URL
    private(set) var entries: [Entry] = []
    private(set) var readFailed = false

    init(url: URL) {
        self.url = url
        reload()
    }

    mutating func reload() {
        do {
            entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
            readFailed = false
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            entries = []
            readFailed = false
        } catch {
            readFailed = true
        }
    }

    mutating func commit(_ updated: [Entry]) throws {
        guard !readFailed else { throw CocoaError(.fileReadUnknown) }
        let data = try JSONEncoder().encode(updated)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try data.write(to: url, options: .atomic)
        entries = updated
    }
}
