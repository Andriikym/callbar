/// The operating-system boundary. Success means handoff, not a connected call.
@MainActor
public protocol CallLaunching {
    func open(_ request: CallRequest) async throws
}

@MainActor
public struct DialCall {
    private let launcher: any CallLaunching

    public init(launcher: any CallLaunching) {
        self.launcher = launcher
    }

    @discardableResult
    public func start(rawNumber: String) async throws -> PhoneNumber {
        try await start(CallRequest(rawNumber: rawNumber))
    }

    @discardableResult
    public func start(_ request: CallRequest) async throws -> PhoneNumber {
        try await launcher.open(request)
        return request.number
    }
}
