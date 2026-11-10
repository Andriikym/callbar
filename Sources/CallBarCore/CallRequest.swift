import Foundation

/// Only validated phone numbers can produce a system call request.
public struct CallRequest: Equatable, Sendable {
    public let number: PhoneNumber
    public let url: URL

    public init(rawNumber: String) throws {
        let number = try PhoneNumber(rawNumber)
        var components = URLComponents()
        components.scheme = "tel"
        components.path = number.canonical
        guard let url = components.url else {
            throw CallLaunchError.invalidURL
        }
        self.number = number
        self.url = url
    }
}

public enum CallLaunchError: Error, Equatable, LocalizedError, Sendable {
    case invalidURL
    case noHandler
    case openFailed

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not prepare the number for a call."
        case .noHandler:
            return "macOS could not find a calling app. Check your iPhone calling settings."
        case .openFailed:
            return "Could not open the calling app. Try placing a call from a system app."
        }
    }
}
