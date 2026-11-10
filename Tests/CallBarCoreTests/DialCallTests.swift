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
        do {
            try await DialCall(launcher: launcher).start(rawNumber: "tel:123")
            XCTFail("Invalid input must not be handed off")
        } catch {
            XCTAssertEqual(error as? PhoneNumberError, .unsupportedCharacters)
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
