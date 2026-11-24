import CallBarCore
import Foundation

struct DialerNotice: Equatable {
    enum Kind: Equatable {
        case information
        case error
    }

    let kind: Kind
    let message: String
}

@MainActor
final class DialerViewModel {
    var rawNumber = "" {
        didSet {
            if oldValue != rawNumber {
                notice = nil
            }
        }
    }
    private(set) var isOpening = false
    private(set) var notice: DialerNotice?
    var onCallStateChange: (() -> Void)?

    let lists: SavedCalls
    private let dialCall: DialCall
    private let now: () -> Date

    init(dialCall: DialCall, lists: SavedCalls, now: @escaping () -> Date = Date.init) {
        self.dialCall = dialCall
        self.lists = lists
        self.now = now
    }

    var normalizedNumber: String? {
        try? PhoneNumber(rawNumber).canonical
    }

    var canCall: Bool {
        normalizedNumber != nil && !isOpening
    }

    var validationMessage: String? {
        do {
            _ = try PhoneNumber(rawNumber)
            return nil
        } catch PhoneNumberError.empty {
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func clearNumber() {
        rawNumber = ""
    }

    func prepareForPresentation() {
        notice = nil
    }

    @discardableResult
    func call() -> Task<Void, Never>? {
        guard !isOpening else { return nil }
        let request: CallRequest
        do {
            request = try CallRequest(rawNumber: rawNumber)
        } catch {
            notice = DialerNotice(kind: .error, message: error.localizedDescription)
            onCallStateChange?()
            return nil
        }

        isOpening = true
        notice = nil
        let attempt = lists.startAttempt(number: request.number.canonical, at: now())
        onCallStateChange?()
        return Task { await handOff(request, attempt: attempt) }
    }

    private func handOff(_ request: CallRequest, attempt: CallAttempt) async {
        defer {
            isOpening = false
            onCallStateChange?()
        }

        do {
            let number = try await dialCall.start(request)
            lists.finishAttempt(attempt, with: .sent)
            notice = DialerNotice(
                kind: .information,
                message: "Number \(number.canonical) was sent to the calling app. Continue in the system dialog."
            )
        } catch {
            let result: CallAttempt.Result = (error as? CallLaunchError) == .noHandler ? .noHandler : .openFailed
            lists.finishAttempt(attempt, with: result)
            notice = DialerNotice(kind: .error, message: error.localizedDescription)
        }
    }
}
