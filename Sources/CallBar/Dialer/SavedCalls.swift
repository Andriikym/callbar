import CallBarCore
import Foundation

struct Favorite: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let number: String
}

struct CallAttempt: Codable, Equatable, Identifiable {
    enum Result: String, Codable {
        case pending, sent, noHandler, openFailed, unknown

        var title: String {
            switch self {
            case .pending: return "Sending number…"
            case .sent: return "Sent to calling app"
            case .noHandler: return "No calling app available"
            case .openFailed: return "Couldn’t open calling app"
            case .unknown: return "Result unknown"
            }
        }
    }

    let id: UUID
    let number: String
    let time: Date
    var result: Result
}

enum FavoriteError: LocalizedError {
    case missingName, missingFavorite, duplicate(Favorite), writeFailed

    var errorDescription: String? {
        switch self {
        case .missingName: return "Enter a name."
        case .missingFavorite: return "This favorite is no longer available."
        case .duplicate(let favorite): return "This number is already saved as \(favorite.name)."
        case .writeFailed: return "Couldn’t save changes to Favorites. Try again."
        }
    }
}

@MainActor
final class SavedCalls {
    private var favoriteStore: LocalList<Favorite>
    private var historyStore: LocalList<CallAttempt>
    private var unsavedAttempts: [CallAttempt] = []
    private var pendingInThisSession: Set<UUID> = []
    private(set) var historyWriteFailed = false

    init(directory: URL) {
        favoriteStore = LocalList(url: directory.appendingPathComponent("Favorites.json"))
        historyStore = LocalList(url: directory.appendingPathComponent("Recents.json"))
    }

    var favoritesReadFailed: Bool { favoriteStore.readFailed }
    var historyReadFailed: Bool { historyStore.readFailed }

    var favorites: [Favorite] {
        favoriteStore.entries.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.number < $1.number : order == .orderedAscending
        }
    }

    var history: [CallAttempt] {
        historyStore.entries.map { entry in
            guard entry.result == .pending, !pendingInThisSession.contains(entry.id) else { return entry }
            var interrupted = entry
            interrupted.result = .unknown
            return interrupted
        }
    }

    func favorite(for number: String) -> Favorite? {
        favoriteStore.entries.first { $0.number == number }
    }

    func retryFavoritesRead() {
        favoriteStore.reload()
    }

    @discardableResult
    func saveFavorite(id: UUID?, name: String, rawNumber: String) throws -> Favorite {
        var entries = favoriteStore.entries
        let index = entries.firstIndex { $0.id == id }
        if id != nil && index == nil { throw FavoriteError.missingFavorite }

        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw FavoriteError.missingName }
        let number = try PhoneNumber(rawNumber).canonical
        if let existing = favorite(for: number), existing.id != id {
            throw FavoriteError.duplicate(existing)
        }

        let favorite = Favorite(id: id ?? UUID(), name: name, number: number)
        if let index {
            entries[index] = favorite
        } else {
            entries.append(favorite)
        }
        try commitFavorites(entries)
        return favorite
    }

    func removeFavorites(ids: Set<UUID>) throws {
        let remaining = favoriteStore.entries.filter { !ids.contains($0.id) }
        if remaining.count != favoriteStore.entries.count { try commitFavorites(remaining) }
    }

    private func commitFavorites(_ entries: [Favorite]) throws {
        do {
            try favoriteStore.commit(entries)
        } catch {
            throw FavoriteError.writeFailed
        }
    }

    func startAttempt(number: String, at time: Date) -> CallAttempt {
        let attempt = CallAttempt(id: UUID(), number: number, time: time, result: .pending)
        pendingInThisSession.insert(attempt.id)
        stage(attempt)
        return attempt
    }

    func finishAttempt(_ attempt: CallAttempt, with result: CallAttempt.Result) {
        var finished = attempt
        finished.result = result
        stage(finished)
    }

    private func stage(_ attempt: CallAttempt) {
        if let index = unsavedAttempts.firstIndex(where: { $0.id == attempt.id }) {
            unsavedAttempts[index] = attempt
        } else {
            unsavedAttempts.append(attempt)
        }
        if !historyReadFailed, !historyWriteFailed { commitHistory() }
    }

    func retryHistory() {
        if historyReadFailed { historyStore.reload() }
        commitHistory()
    }

    private func commitHistory() {
        guard !historyReadFailed, !unsavedAttempts.isEmpty else { return }

        var entries = history
        for attempt in unsavedAttempts {
            if let index = entries.firstIndex(where: { $0.id == attempt.id }) {
                entries[index] = attempt
            } else {
                entries.insert(attempt, at: 0)
            }
        }
        do {
            try historyStore.commit(Array(entries.prefix(100)))
            pendingInThisSession.subtract(unsavedAttempts.filter { $0.result != .pending }.map(\.id))
            unsavedAttempts.removeAll()
            historyWriteFailed = false
        } catch {
            historyWriteFailed = true
        }
    }
}
