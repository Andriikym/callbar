import SwiftUI

@MainActor
struct DialerView: View {
    @ObservedObject var model: DialerViewModel
    let onClose: () -> Void
    let onQuit: () -> Void

    @State private var showingSetup = false
    @FocusState private var isNumberFocused: Bool

    var body: some View {
        Group {
            if showingSetup {
                SetupGuideView {
                    showingSetup = false
                    focusNumber()
                }
            } else {
                dialer
            }
        }
        .padding(20)
        .frame(width: 360, height: 400, alignment: .topLeading)
        .onAppear(perform: focusNumber)
        .onChange(of: model.presentationID) { _ in
            showingSetup = false
            focusNumber()
        }
        .onExitCommand(perform: onClose)
    }

    private var dialer: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "phone.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CallBar").font(.title2.weight(.semibold))
                    Text("Call through iPhone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Phone number").font(.headline)
                HStack(spacing: 6) {
                    TextField("Type or paste a number", text: $model.rawNumber)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3.monospacedDigit())
                        .focused($isNumberFocused)
                        .accessibilityLabel("Phone number")
                        .accessibilityHint("Paste or type a number. Press Enter to start a call.")
                        .onSubmit { submit() }

                    Button {
                        model.clearNumber()
                        focusNumber()
                    } label: {
                        Label("Clear phone number", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                    .help("Clear phone number")
                    .disabled(model.rawNumber.isEmpty)
                }
                .disabled(model.isOpening)

                if let message = model.validationMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let normalized = model.normalizedNumber {
                    Text("Ready to dial: \(normalized)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("The number does not need to be in Contacts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: submit) {
                HStack {
                    if model.isOpening {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "phone.fill")
                    }
                    Text(model.isOpening ? "Sending number…" : "Call through iPhone")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!model.canCall)

            if let notice = model.notice {
                Text(notice.message)
                    .font(.caption)
                    .foregroundStyle(notice.kind == .error ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(notice.kind == .error ? "Error: \(notice.message)" : notice.message)
            } else {
                Text("macOS will open the calling app. Confirm the call in the system dialog if prompted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
            Divider()

            HStack {
                Button {
                    showingSetup = true
                } label: {
                    Label("Setup", systemImage: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .disabled(model.isOpening)

                Spacer()

                Button("Quit CallBar", action: onQuit)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }

    private func submit() {
        guard model.canCall else { return }
        Task { await model.call() }
    }

    private func focusNumber() {
        DispatchQueue.main.async {
            isNumberFocused = true
        }
    }
}
