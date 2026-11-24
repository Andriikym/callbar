import AppKit

@MainActor
final class FavoriteEditorView: NSView, NSTextFieldDelegate {
    let favorite: Favorite?
    let nameField = NSTextField()
    let numberField = NSTextField()
    private let errorLabel = bodyLabel("", color: .systemRed)
    private let onSave: (String, String) throws -> Void
    private let onCancel: () -> Void
    private let onShowExisting: (Favorite) -> Void
    private var collision: Favorite?
    private lazy var saveButton = PopoverButton("Save favorite", style: .primary) { [weak self] in self?.save() }
    private lazy var existingButton = PopoverButton("Edit existing favorite") { [weak self] in
        guard let self, let collision else { return }
        onShowExisting(collision)
    }
    private lazy var collisionActions = horizontalStack([existingButton, NSView()])

    init(favorite: Favorite?, number: String, onSave: @escaping (String, String) throws -> Void,
         onCancel: @escaping () -> Void, onShowExisting: @escaping (Favorite) -> Void,
         onRemove: @escaping (Favorite) -> Void) {
        self.favorite = favorite
        self.onSave = onSave
        self.onCancel = onCancel
        self.onShowExisting = onShowExisting
        super.init(frame: .zero)

        let title = NSTextField(labelWithString: favorite == nil ? "Add favorite" : "Edit favorite")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        nameField.placeholderString = "e.g. Front desk"
        nameField.stringValue = favorite?.name ?? ""
        numberField.stringValue = favorite?.number ?? number
        numberField.placeholderString = "Type or paste a number"
        numberField.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        for (field, label) in [(nameField, "Name"), (numberField, "Phone number")] {
            field.delegate = self
            field.setAccessibilityLabel(label)
            field.heightAnchor.constraint(equalToConstant: 30).isActive = true
        }

        let name = verticalStack([NSTextField(labelWithString: "Name"), nameField], spacing: 4)
        let phone = verticalStack([NSTextField(labelWithString: "Phone number"), numberField], spacing: 4)
        let cancel = PopoverButton("Cancel", action: onCancel)
        cancel.keyEquivalent = "\u{1b}"
        saveButton.keyEquivalent = "\r"
        saveButton.setPrimaryTitle("Save favorite")
        saveButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        var actions: [NSView] = [NSView(), cancel, saveButton]
        if let favorite {
            let remove = PopoverButton("Remove favorite", symbol: "trash", style: .plain) { onRemove(favorite) }
            remove.setSymbol("trash", label: "Remove \(favorite.name), \(favorite.number)")
            remove.contentTintColor = .systemRed
            actions.insert(remove, at: 0)
        }
        let form = verticalStack([title, name, phone, errorLabel, collisionActions, horizontalStack(actions)], spacing: 10)
        errorLabel.isHidden = true
        collisionActions.isHidden = true
        addSubview(form)
        form.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            form.topAnchor.constraint(equalTo: topAnchor),
            form.leadingAnchor.constraint(equalTo: leadingAnchor),
            form.trailingAnchor.constraint(equalTo: trailingAnchor),
            form.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use the programmatic initializer.") }

    func controlTextDidChange(_ notification: Notification) {
        errorLabel.isHidden = true
        collisionActions.isHidden = true
        saveButton.setPrimaryTitle("Save favorite")
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy command: Selector) -> Bool {
        switch command {
        case #selector(NSResponder.insertNewline(_:)):
            if NSApp.currentEvent?.isRepeatKeyDown != true { save() }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            onCancel()
            return true
        default:
            return false
        }
    }

    private func save() {
        do {
            try onSave(nameField.currentEditor()?.string ?? nameField.stringValue,
                       numberField.currentEditor()?.string ?? numberField.stringValue)
        } catch {
            errorLabel.stringValue = error.localizedDescription
            errorLabel.isHidden = false
            if case FavoriteError.writeFailed = error { saveButton.setPrimaryTitle("Retry save") }
            if case FavoriteError.duplicate(let existing) = error, favorite == nil {
                collision = existing
                existingButton.setAccessibilityLabel("Edit \(existing.name), \(existing.number)")
                collisionActions.isHidden = false
            } else {
                collisionActions.isHidden = true
            }
        }
    }
}

extension NSEvent {
    var isRepeatKeyDown: Bool { type == .keyDown && isARepeat }
}
