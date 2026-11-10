import SwiftUI

@MainActor
struct SetupGuideView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)

            Text("Calls through iPhone")
                .font(.title3.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    step("1", "Sign in to the same Apple Account on your Mac and iPhone, and turn on Wi-Fi. For a typical setup, connect both devices to the same network.")
                    step("2", "On iPhone, open Settings → Apps → Phone → Calls on Other Devices and allow calls on this Mac.")
                    step("3", "Make sure you are signed in to FaceTime, then try a regular call from a system app on your Mac.")
                    step("4", "Return to CallBar, enter a number, and click Call through iPhone.")

                    Text("If another handler is selected for phone links, macOS will send the number to that app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Link("Apple instructions", destination: URL(string: "https://support.apple.com/102405")!)
                        .font(.caption)
                }
            }
        }
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
