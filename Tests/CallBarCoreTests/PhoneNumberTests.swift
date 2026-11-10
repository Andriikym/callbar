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
