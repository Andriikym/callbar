import Foundation

extension Bundle {
    var callBarVersionLabel: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = infoDictionary?["CFBundleVersion"] as? String
        return build.map { "v\(version) (\($0))" } ?? "v\(version)"
    }
}
