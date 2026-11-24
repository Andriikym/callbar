import AppKit

@MainActor
final class SetupGuideView: NSView {
    private let onBack: () -> Void
    private let backButton = NSButton()

    init(onBack: @escaping () -> Void) {
        self.onBack = onBack
        super.init(frame: .zero)

        backButton.title = "Back"
        backButton.bezelStyle = .rounded
        backButton.target = self
        backButton.action = #selector(goBack)

        let title = NSTextField(labelWithString: "Calls through iPhone")
        title.font = .systemFont(ofSize: 16, weight: .semibold)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let document = NSView()
        scroll.documentView = document

        let instructions = NSStackView()
        instructions.orientation = .vertical
        instructions.alignment = .leading
        instructions.spacing = 12

        let steps = [
            "Sign in to the same Apple Account on your Mac and iPhone, and turn on Wi-Fi. For a typical setup, connect both devices to the same network.",
            "On iPhone, open Settings → Apps → Phone → Calls on Other Devices and allow calls on this Mac.",
            "Make sure you are signed in to FaceTime, then try a regular call from a system app on your Mac.",
            "Return to CallBar, enter a number, and click Call through iPhone."
        ]
        for (index, step) in steps.enumerated() {
            let label = NSTextField(wrappingLabelWithString: "\(index + 1). \(step)")
            instructions.addArrangedSubview(label)
            label.widthAnchor.constraint(equalTo: instructions.widthAnchor).isActive = true
        }
        let note = NSTextField(wrappingLabelWithString:
            "If another handler is selected for phone links, macOS will send the number to that app."
        )
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        instructions.addArrangedSubview(note)
        let link = NSButton(title: "Apple instructions", target: self, action: #selector(openInstructions))
        instructions.addArrangedSubview(link)

        for child in [backButton, title, scroll] {
            child.translatesAutoresizingMaskIntoConstraints = false
            addSubview(child)
        }
        document.translatesAutoresizingMaskIntoConstraints = false
        instructions.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(instructions)
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: topAnchor),
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            title.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 14),
            title.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            instructions.topAnchor.constraint(equalTo: document.topAnchor),
            instructions.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            instructions.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -8),
            instructions.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            note.widthAnchor.constraint(equalTo: instructions.widthAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use init(onBack:)")
    }

    func focusBack() {
        window?.makeFirstResponder(backButton)
    }

    @objc private func goBack() {
        onBack()
    }

    @objc private func openInstructions() {
        NSWorkspace.shared.open(URL(string: "https://support.apple.com/102405")!)
    }
}
