import XCTest
@testable import CallBarCore

final class PhoneNumberTests: XCTestCase {
    func testNormalizesFormattingWithoutChangingDialedDigits() throws {
        let cases = [
            ("+1 (202) 555-0147", "+12025550147"),
            ("020 7946 0958", "02079460958"),
            ("+380\u{00A0}(50)\u{202F}123\u{2011}45\u{2013}67", "+380501234567"),
            ("\n  +44 (20) 7946-0958 \r\n", "+442079460958"),
            ("001 202 555 0147", "0012025550147"),
            ("123", "123"),
            ("+123456789012345", "+123456789012345")
        ]

        for (input, expected) in cases {
            XCTAssertEqual(try PhoneNumber(input).canonical, expected, input)
        }
    }

    func testRejectsEmptyAndOutOfRangeInput() {
        assertInvalid("", .empty)
        assertInvalid(" \t\n ", .empty)
        assertInvalid("+", .tooShort)
        assertInvalid("12", .tooShort)
        assertInvalid("+1234567890123456", .tooLong)
    }

    func testRejectsPlusInsideNumberOrRepeatedPlus() {
        assertInvalid("123+456", .misplacedPlus)
        assertInvalid("++123456", .misplacedPlus)
        assertInvalid("+ +123456", .misplacedPlus)
    }

    func testRejectsURLsExtensionsAndAmbiguousInput() {
        for input in [
            "tel:+12025550147",
            "https://example.com",
            "12025550147 ext 12",
            "12025550147;12",
            "12025550147,12",
            "12025550147/12025550148",
            "202.555.0147",
            "*123#",
            "123\n456",
            "123\r456",
            "123\u{2028}456",
            "１２３４５６",
            "١٢٣٤٥٦",
            "123\u{200B}456",
            "\u{200B}123456",
            "123456\u{200B}"
        ] {
            assertInvalid(input, .unsupportedCharacters)
        }
    }

    func testDigitLimitsCountDigitsRatherThanFormattingOrPlus() throws {
        for prefix in ["", "+"] {
            for count in [3, 15] {
                let digits = String(repeating: "0", count: count)
                let formatted = prefix + digits.map { "(\($0))" }.joined(separator: " - ")
                XCTAssertEqual(try PhoneNumber(formatted).canonical, prefix + digits)
            }

            assertInvalid(prefix + "(0) - (0)", .tooShort)
            assertInvalid(prefix + String(repeating: "(0) - ", count: 16), .tooLong)
        }
    }

    func testAcceptsDocumentedHorizontalSpacesAndDashes() throws {
        let separators = [
            " ", "\t", "\u{00A0}", "\u{1680}", "\u{2000}", "\u{2001}",
            "\u{2002}", "\u{2003}", "\u{2004}", "\u{2005}", "\u{2006}",
            "\u{2007}", "\u{2008}", "\u{2009}", "\u{200A}", "\u{202F}",
            "\u{205F}", "\u{3000}", "-", "\u{2010}", "\u{2011}",
            "\u{2012}", "\u{2013}", "\u{2014}"
        ]

        for separator in separators {
            let input = "+000\(separator)123\(separator)456"
            XCTAssertEqual(try PhoneNumber(input).canonical, "+000123456", input.debugDescription)
        }
    }

    func testRejectsEveryInternalLineSeparator() {
        for separator in ["\n", "\r", "\r\n", "\u{000B}", "\u{000C}", "\u{0085}", "\u{2028}", "\u{2029}"] {
            assertInvalid("123\(separator)456", .unsupportedCharacters)
        }
    }

    func testRejectsControlsInvisibleCharactersAndURLSyntaxAtAnyPosition() {
        let forbidden = [
            "\u{0000}", "\u{001B}", "\u{007F}", "\u{200B}", "\u{200C}",
            "\u{200D}", "\u{202E}", "\u{2066}", "\u{FEFF}",
            "%", ":", "/", "?", "#", "@", "&", "=", ",", ";", "*", ".",
            "１", "١", "A"
        ]

        for character in forbidden {
            for input in ["\(character)123456", "123\(character)456", "123456\(character)"] {
                assertInvalid(input, .unsupportedCharacters)
            }
        }
    }

    private func assertInvalid(
        _ input: String,
        _ expected: PhoneNumberError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try PhoneNumber(input), input, file: file, line: line) { error in
            XCTAssertEqual(error as? PhoneNumberError, expected, input, file: file, line: line)
        }
    }
}
