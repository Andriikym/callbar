import XCTest
@testable import CallBarCore

final class DialCallTests: XCTestCase {
    func testRequestContainsOnlyCanonicalTelephoneURL() throws {
        let request = try CallRequest(rawNumber: "+1 (202) 555-0147")
        XCTAssertEqual(request.url.absoluteString, "tel:+12025550147")
        XCTAssertEqual(request.url.scheme, "tel")
        XCTAssertNil(request.url.query)
        XCTAssertNil(request.url.fragment)
        XCTAssertNil(request.url.host)
    }

    func testLocalNumberDoesNotAcquireACountryCode() throws {
        let request = try CallRequest(rawNumber: "020 7946 0958")
        XCTAssertEqual(request.url.absoluteString, "tel:02079460958")
    }

    func testRequestRejectsInvalidInputBeforeConstructingAURL() {
        let cases: [(String, PhoneNumberError)] = [
            ("", .empty),
            ("12", .tooShort),
            ("1234567890123456", .tooLong),
            ("12+3456", .misplacedPlus),
            ("123?body=456", .unsupportedCharacters),
            ("%2B123456", .unsupportedCharacters),
            ("123\n456", .unsupportedCharacters)
        ]

        for (input, expected) in cases {
            XCTAssertThrowsError(try CallRequest(rawNumber: input)) { error in
                XCTAssertEqual(error as? PhoneNumberError, expected)
            }
        }
    }

    @MainActor
    func testValidInputIsHandedOffOnce() async throws {
        let launcher = RecordingLauncher()
        let result = try await DialCall(launcher: launcher).start(rawNumber: "+1 (202) 555-0147")
        XCTAssertEqual(result.canonical, "+12025550147")
        XCTAssertEqual(launcher.requests.count, 1)
        XCTAssertEqual(launcher.requests.first?.url.absoluteString, "tel:+12025550147")
    }

    @MainActor
    func testInvalidInputNeverReachesTheOperatingSystem() async {
        let launcher = RecordingLauncher()
        let cases: [(String, PhoneNumberError)] = [
            ("", .empty),
            ("12", .tooShort),
            ("1234567890123456", .tooLong),
            ("++123", .misplacedPlus),
            ("tel:123", .unsupportedCharacters),
            ("123\n456", .unsupportedCharacters)
        ]

        for (input, expected) in cases {
            do {
                try await DialCall(launcher: launcher).start(rawNumber: input)
                XCTFail("Invalid input must not be handed off")
            } catch {
                XCTAssertEqual(error as? PhoneNumberError, expected)
            }
        }
        XCTAssertTrue(launcher.requests.isEmpty)
    }

    @MainActor
    func testSystemErrorsAreNotReportedAsSuccess() async {
        for failure in [CallLaunchError.noHandler, .openFailed] {
            let launcher = RecordingLauncher()
            launcher.failure = failure
            do {
                try await DialCall(launcher: launcher).start(rawNumber: "+12025550147")
                XCTFail("Failed handoff must propagate an error")
            } catch {
                XCTAssertEqual(error as? CallLaunchError, failure)
            }
            XCTAssertEqual(launcher.requests.count, 1)
        }
    }
}

@MainActor
private final class RecordingLauncher: CallLaunching {
    var requests: [CallRequest] = []
    var failure: CallLaunchError?

    func open(_ request: CallRequest) async throws {
        requests.append(request)
        if let failure {
            throw failure
        }
    }
}
