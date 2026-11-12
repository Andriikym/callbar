import CallBarCore
import Foundation
import SwiftUI

struct DialerNotice: Equatable {
    enum Kind: Equatable {
        case information
        case error
    }

    let kind: Kind
    let message: String
}

@MainActor
final class DialerViewModel: ObservableObject {
    @Published var rawNumber = "" {
        didSet {
            if oldValue != rawNumber {
                notice = nil
            }
        }
    }
    @Published private(set) var isOpening = false
    @Published private(set) var notice: DialerNotice?
    @Published private(set) var presentationID = 0

    private let dialCall: DialCall

    init(dialCall: DialCall) {
        self.dialCall = dialCall
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
        presentationID += 1
    }

    func call() async {
        guard !isOpening else { return }
        let input = rawNumber
        isOpening = true
        notice = nil
        defer { isOpening = false }

        do {
            let number = try await dialCall.start(rawNumber: input)
            notice = DialerNotice(
                kind: .information,
                message: "Number \(number.canonical) was sent to the calling app. Continue in the system dialog."
            )
        } catch {
            notice = DialerNotice(kind: .error, message: error.localizedDescription)
        }
    }
}
