import Foundation

/// A syntactically validated dial string, not a guarantee that a number exists.
public struct PhoneNumber: Equatable, Sendable {
    public let canonical: String

    // Foundation's .whitespaces also includes U+200B on some platforms.
    // Only horizontal Unicode space separators and tab are formatting here.
    private static let horizontalWhitespace = CharacterSet(
        charactersIn: " \t\u{00A0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200A}\u{202F}\u{205F}\u{3000}"
    )

    public init(_ rawValue: String) throws {
        let trimmed = rawValue.trimmingCharacters(in: Self.horizontalWhitespace.union(.newlines))
        guard !trimmed.isEmpty else {
            throw PhoneNumberError.empty
        }

        var result = ""
        var digitCount = 0
        let formattingCharacters = CharacterSet(charactersIn: "()-\u{2010}\u{2011}\u{2012}\u{2013}\u{2014}")

        for scalar in trimmed.unicodeScalars {
            switch scalar.value {
            case 48...57:
                result.unicodeScalars.append(scalar)
                digitCount += 1
            case 43:
                guard result.isEmpty else {
                    throw PhoneNumberError.misplacedPlus
                }
                result.append("+")
            default:
                guard Self.horizontalWhitespace.contains(scalar) || formattingCharacters.contains(scalar) else {
                    throw PhoneNumberError.unsupportedCharacters
                }
            }
        }

        guard digitCount >= 3 else {
            throw PhoneNumberError.tooShort
        }
        guard digitCount <= 15 else {
            throw PhoneNumberError.tooLong
        }
        canonical = result
    }
}

public enum PhoneNumberError: Error, Equatable, LocalizedError, Sendable {
    case empty
    case tooShort
    case tooLong
    case misplacedPlus
    case unsupportedCharacters

    public var errorDescription: String? {
        switch self {
        case .empty:
            return "Enter a phone number."
        case .tooShort:
            return "The number must contain at least 3 digits."
        case .tooLong:
            return "The number must contain no more than 15 digits."
        case .misplacedPlus:
            return "A plus sign can appear only once, at the beginning of the number."
        case .unsupportedCharacters:
            return "Enter one number using digits, an optional leading plus sign, spaces, parentheses, or hyphens."
        }
    }
}
