import AppKit

@MainActor
final class DialerViewController: NSViewController, NSTextFieldDelegate {
    static let popoverSize = NSSize(width: 372, height: 407)

    private enum Tab: Int { case dialer, recents, favorites }

    private let model: DialerViewModel
    private let onClose: () -> Void
    private let body = NSView()
    private let segments = NSSegmentedControl()
    private let listActions = ListActionsButton()
    private lazy var clearRecentsAction = listAction("Clear Recents…", symbol: "trash", action: #selector(clearRecents))
    private lazy var addFavoriteAction = listAction("Add Favorite…", symbol: "plus", action: #selector(addFavorite))
    private lazy var clearFavoritesAction = listAction("Clear Favorites…", symbol: "trash", action: #selector(clearFavorites))
    private lazy var recentsMenu = listMenu([clearRecentsAction])
    private lazy var favoritesMenu = listMenu([addFavoriteAction, .separator(), clearFavoritesAction])
    private var tab: Tab = .dialer
    private var editor: FavoriteEditorView?
    private var cancelPanel: (() -> Void)?
    private var favoriteSelection: UUID?
    private var recentSelection: UUID?

    private let numberField = NSTextField()
    private let validationLabel = bodyLabel("")
    private let noticeLabel = bodyLabel("")
    private let historyError = bodyLabel("", color: .systemRed)
    private lazy var historyRetry = PopoverButton("Retry Recents") { [weak self] in self?.retryHistory() }
    private lazy var historyRecovery = verticalStack([historyError, horizontalStack([historyRetry, NSView()])])
    private lazy var clearNumber = PopoverButton("Clear phone number", symbol: "xmark.circle", style: .plain) { [weak self] in
        guard let self else { return }
        view.window?.makeFirstResponder(nil)
        model.clearNumber()
        showTab(focus: true)
    }
    private lazy var dialerStar = PopoverButton("Save to Favorites", symbol: "star", style: .plain) { [weak self] in
        guard let self else { return }
        updateNumber()
        guard let number = model.normalizedNumber else { return }
        openEditor(number: number)
    }
    private lazy var callButton = PopoverButton("Call through iPhone", style: .primary) { [weak self] in self?.submit() }
    private lazy var setupButton = PopoverButton("Setup", symbol: "questionmark.circle", style: .plain) { [weak self] in
        self?.showSetup()
    }
    private lazy var dialer = makeDialer()

    init(model: DialerViewModel, onClose: @escaping () -> Void) {
        self.model = model
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
        model.onCallStateChange = { [weak self] in self?.refreshCallState() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(model:onClose:)") }

    override func loadView() {
        view = PopoverBackground(frame: NSRect(origin: .zero, size: Self.popoverSize))

        let title = NSTextField(labelWithString: "CallBar")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Call through iPhone")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.setContentCompressionResistancePriority(.required, for: .horizontal)
        let heading = verticalStack([title, subtitle], spacing: 1)
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "phone.circle.fill", accessibilityDescription: nil)
        icon.symbolConfiguration = .init(pointSize: 36, weight: .regular)
        icon.contentTintColor = .systemBlue
        icon.setAccessibilityElement(false)
        icon.widthAnchor.constraint(equalToConstant: 36).isActive = true
        icon.heightAnchor.constraint(equalTo: icon.widthAnchor).isActive = true
        let header = horizontalStack([icon, heading, NSView(), listActions])
        header.alignment = .top
        header.spacing = 12

        let tabs = [("Dialer", "phone"), ("Recents", "clock"), ("Favorites", "star")]
        segments.segmentCount = tabs.count
        segments.segmentDistribution = .fillEqually
        segments.trackingMode = .selectOne
        segments.segmentStyle = .rounded
        segments.controlSize = .large
        segments.target = self
        segments.action = #selector(changeTab)
        segments.setAccessibilityLabel("CallBar view")
        for (index, tab) in tabs.enumerated() {
            segments.setLabel(tab.0, forSegment: index)
            segments.setImage(NSImage(systemSymbolName: tab.1, accessibilityDescription: nil), forSegment: index)
        }

        let divider = popoverDivider()
        setupButton.imagePosition = .imageLeading
        setupButton.imageHugsTitle = true
        setupButton.font = .systemFont(ofSize: 11.5)
        let quit = PopoverButton("Quit CallBar", style: .plain) { NSApp.terminate(nil) }
        quit.font = .systemFont(ofSize: 11.5)
        let version = NSTextField(labelWithString: Bundle.main.callBarVersionLabel)
        version.font = .systemFont(ofSize: 10)
        version.textColor = .tertiaryLabelColor
        version.alignment = .center
        version.setAccessibilityLabel("CallBar version \(Bundle.main.callBarVersionLabel)")
        version.setContentCompressionResistancePriority(.required, for: .horizontal)
        let footer = horizontalStack([setupButton, NSView(), version, NSView(), quit])
        footer.heightAnchor.constraint(equalToConstant: 23).isActive = true
        let chrome = verticalStack([header, segments, body, divider, footer], spacing: 10)
        chrome.setCustomSpacing(14, after: header)
        chrome.setCustomSpacing(12, after: segments)
        chrome.setCustomSpacing(6, after: divider)
        view.addSubview(chrome)
        chrome.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chrome.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            chrome.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            chrome.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            chrome.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])
        showTab()
    }

    func focusNumber() {
        if !model.isOpening { view.window?.makeFirstResponder(numberField) }
    }

    override func cancelOperation(_ sender: Any?) {
        if let cancelPanel { cancelPanel() } else { onClose() }
    }

    func controlTextDidChange(_ notification: Notification) {
        updateNumber()
        refreshDialer()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy command: Selector) -> Bool {
        switch command {
        case #selector(NSResponder.insertNewline(_:)):
            submit()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            cancelOperation(nil)
            return true
        default:
            return false
        }
    }

    private func makeDialer() -> NSView {
        let numberLabel = NSTextField(labelWithString: "Phone number")
        numberLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        numberField.placeholderString = "Type or paste a number"
        numberField.font = .monospacedDigitSystemFont(ofSize: 16, weight: .regular)
        numberField.controlSize = .large
        numberField.delegate = self
        numberField.setAccessibilityLabel("Phone number")
        numberField.setAccessibilityHelp("Paste or type a number. Press Enter to start a call.")
        numberField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        numberField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        callButton.image = NSImage(systemSymbolName: "phone", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
        callButton.imagePosition = .imageLeading
        callButton.imageHugsTitle = true
        callButton.contentTintColor = .white
        numberField.heightAnchor.constraint(equalToConstant: 30).isActive = true
        for button in [clearNumber, dialerStar] {
            button.widthAnchor.constraint(equalToConstant: 30).isActive = true
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        }

        let field = horizontalStack([numberField, clearNumber, dialerStar])
        let dialer = NSView()
        let form = verticalStack([numberLabel, field, validationLabel, callButton, noticeLabel, historyRecovery])
        dialer.addSubview(form)
        form.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            form.topAnchor.constraint(equalTo: dialer.topAnchor, constant: 4),
            form.leadingAnchor.constraint(equalTo: dialer.leadingAnchor),
            form.trailingAnchor.constraint(equalTo: dialer.trailingAnchor),
            form.bottomAnchor.constraint(lessThanOrEqualTo: dialer.bottomAnchor)
        ])
        return dialer
    }

    @objc private func changeTab() {
        guard let next = Tab(rawValue: segments.selectedSegment) else { return }
        if tab == .dialer { updateNumber() }
        tab = next
        showTab(focus: next == .dialer)
    }

    private func showTab(focus: Bool = false) {
        editor = nil
        cancelPanel = nil
        segments.isEnabled = true
        segments.selectedSegment = tab.rawValue
        setupButton.isEnabled = !model.isOpening
        listActions.isHidden = tab == .dialer
        listActions.isEnabled = true
        switch tab {
        case .dialer:
            listActions.menu = nil
            show(dialer)
            numberField.stringValue = model.rawNumber
            refreshDialer()
            if focus { focusNumber() }
        case .recents:
            configureListActions("Recents actions", menu: recentsMenu)
            showRecents(focus: focus)
        case .favorites:
            configureListActions("Favorites actions", menu: favoritesMenu)
            showFavorites(focus: focus)
        }
    }

    private func configureListActions(_ label: String, menu: NSMenu) {
        listActions.setAccessibilityLabel(label)
        listActions.toolTip = label
        listActions.menu = menu
    }

    private func listMenu(_ items: [NSMenuItem]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.items = items
        return menu
    }

    private func listAction(_ title: String, symbol: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        item.target = self
        return item
    }

    @objc private func clearRecents() {
        guard tab == .recents, cancelPanel == nil, !model.lists.historyReadFailed else { return }
        confirmRecentRemoval(model.lists.history, clear: true)
    }

    @objc private func addFavorite() {
        guard tab == .favorites, cancelPanel == nil else { return }
        openEditor()
    }

    @objc private func clearFavorites() {
        guard tab == .favorites, cancelPanel == nil, !model.lists.favoritesReadFailed else { return }
        confirmRemoval(model.lists.favorites, clear: true)
    }

    private func showFavorites(focus: Bool) {
        let lists = model.lists
        let favorites = lists.favorites
        addFavoriteAction.isEnabled = !lists.favoritesReadFailed
        clearFavoritesAction.isEnabled = !lists.favoritesReadFailed && !favorites.isEmpty
        if let issue = lists.favoritesReadIssue {
            showRecovery(issue.message(for: "Favorites"), focus: focus) { [weak self] in
                self?.model.lists.retryFavoritesRead()
                self?.showTab(focus: true)
            }
            return
        }

        var selection: NSButton?
        let rows = favorites.enumerated().map { index, favorite in
            let load = NumberRowButton(title: favorite.name, detail: favorite.number) { [weak self] in
                self?.selectFavorite(favorite.id)
            }
            if selection == nil || favoriteSelection == favorite.id { selection = load }
            let edit = PopoverButton("Edit \(favorite.name), \(favorite.number)", symbol: "pencil", style: .plain) { [weak self] in
                self?.openEditor(number: favorite.number)
            }
            let remove = PopoverButton("Remove \(favorite.name), \(favorite.number)", symbol: "trash", style: .plain) { [weak self] in
                self?.confirmRemoval([favorite])
            }
            return listRow(load, actions: [edit, remove], hasDivider: index < favorites.count - 1)
        }
        show(rows.isEmpty ? emptyFavorites() : listScrollView(rows: rows))
        if focus { focusRow(selection, fallback: listActions) }
    }

    private func emptyFavorites() -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "star", accessibilityDescription: nil)
        icon.symbolConfiguration = .init(pointSize: 32, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        icon.setAccessibilityElement(false)
        icon.heightAnchor.constraint(equalToConstant: 34).isActive = true
        let title = NSTextField(labelWithString: "No favorites yet")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.alignment = .center
        let hint = bodyLabel("Use the ⋯ menu to add a favorite.")
        hint.alignment = .center
        let message = verticalStack([icon, title, hint], spacing: 7)
        let content = NSView()
        content.addSubview(message)
        message.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            message.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            message.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            message.centerYAnchor.constraint(equalTo: content.centerYAnchor, constant: 10)
        ])
        return content
    }

    private func showRecents(focus: Bool) {
        let lists = model.lists
        let history = lists.history
        clearRecentsAction.isEnabled = !lists.historyReadFailed && !history.isEmpty
        if lists.historyReadFailed {
            showRecovery(historyIssue, focus: focus) { [weak self] in self?.retryHistory() }
            return
        }

        var rows: [NSView] = []
        var previousDay: Date?
        var selectedRow: NSButton?
        let calendar = Calendar.current
        for (index, attempt) in history.enumerated() {
            let day = calendar.startOfDay(for: attempt.time)
            if day != previousDay {
                rows.append(dayHeading(Self.dayTitle(day, calendar: calendar), startsList: index == 0))
                previousDay = day
            }
            let favorite = lists.favorite(for: attempt.number)
            let time = attempt.time.formatted(date: .omitted, time: .shortened)
            let detail = favorite == nil ? time : "\(attempt.number) · \(time)"
            let load = NumberRowButton(title: favorite?.name ?? attempt.number, detail: detail, result: attempt.result.title) { [weak self] in
                guard let self, let current = model.lists.history.first(where: { $0.id == attempt.id }) else {
                    self?.showRecents(focus: true)
                    return
                }
                loadNumber(current.number)
            }
            let star = PopoverButton("", symbol: "star", style: .plain) { [weak self] in
                self?.recentSelection = attempt.id
                self?.openEditor(number: attempt.number)
            }
            configureStar(star, number: attempt.number)
            if recentSelection == attempt.id { selectedRow = star }
            let remove = PopoverButton("Remove call to \(attempt.number), \(attempt.time.formatted())",
                                       symbol: "trash", style: .plain) { [weak self] in
                self?.confirmRecentRemoval([attempt])
            }
            let hasDivider = index + 1 < history.count && calendar.isDate(history[index + 1].time, inSameDayAs: day)
            rows.append(listRow(load, actions: [star, remove], hasDivider: hasDivider))
        }

        var content: [NSView] = []
        if lists.historyWriteFailed {
            content.append(recoveryControls(historyIssue) { [weak self] in self?.retryHistory() })
        }
        if rows.isEmpty {
            let back = PopoverButton("Go to Dialer") { [weak self] in
                self?.tab = .dialer
                self?.showTab(focus: true)
            }
            content += [bodyLabel("Calls started from CallBar appear here."), horizontalStack([back, NSView()]), NSView()]
        } else {
            content.append(listScrollView(rows: rows))
        }
        show(verticalStack(content))
        if focus { focusRow(selectedRow, fallback: listActions) }
    }

    private static func dayTitle(_ date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func dayHeading(_ title: String, startsList: Bool) -> NSView {
        let heading = NSView()
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11.5, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        heading.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: heading.topAnchor, constant: startsList ? 0 : 10),
            label.leadingAnchor.constraint(equalTo: heading.leadingAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: heading.bottomAnchor, constant: -3)
        ])
        return heading
    }

    private func showRecovery(_ message: String, focus: Bool, retry: @escaping () -> Void) {
        let controls = recoveryControls(message, retry: retry)
        show(verticalStack([controls, NSView()]))
        if focus { view.window?.makeFirstResponder(segments) }
    }

    private func recoveryControls(_ message: String, retry: @escaping () -> Void) -> NSView {
        let button = PopoverButton("Retry", action: retry)
        return verticalStack([bodyLabel(message, color: .systemRed), horizontalStack([button, NSView()])], spacing: 4)
    }

    private func configureStar(_ button: PopoverButton, number: String?) {
        let favorite = number.flatMap { model.lists.favorite(for: $0) }
        let label = favorite.map { "Edit \($0.name), \($0.number)" }
            ?? number.map { "Save \($0) to Favorites" } ?? "Save to Favorites"
        button.setSymbol(favorite == nil ? "star" : "star.fill", label: label)
        button.contentTintColor = PopoverPalette.blue
        button.isEnabled = number != nil && !model.lists.favoritesReadFailed
    }

    private func selectFavorite(_ id: UUID) {
        guard let favorite = model.lists.favorites.first(where: { $0.id == id }) else {
            showFavorites(focus: true)
            return
        }
        favoriteSelection = id
        loadNumber(favorite.number)
    }

    private func loadNumber(_ number: String) {
        view.window?.makeFirstResponder(nil)
        model.rawNumber = number
        tab = .dialer
        showTab(focus: true)
    }

    private func openEditor(number: String? = nil) {
        let favorite = number.flatMap { model.lists.favorite(for: $0) }
        openEditor(favorite: favorite, number: number ?? "")
    }

    private func openEditor(favorite: Favorite?, number: String) {
        guard !model.lists.favoritesReadFailed else { return }
        if let favorite { favoriteSelection = favorite.id }
        let editor = FavoriteEditorView(favorite: favorite, number: number) { [weak self] name, rawNumber in
            guard let self else { return }
            let saved = try model.lists.saveFavorite(id: favorite?.id, name: name, rawNumber: rawNumber)
            favoriteSelection = saved.id
            showTab(focus: true)
        } onCancel: { [weak self] in
            self?.showTab(focus: true)
        } onShowExisting: { [weak self] existing in
            self?.openEditor(favorite: existing, number: existing.number)
        } onRemove: { [weak self] target in
            self?.confirmRemoval([target])
        }
        self.editor = editor
        showEditor(editor)
    }

    private func showEditor(_ editor: FavoriteEditorView) {
        showPanel(editor, cancel: { [weak self] in self?.showTab(focus: true) })
        view.window?.makeFirstResponder(editor.nameField)
    }

    private func confirmRemoval(_ favorites: [Favorite], clear: Bool = false, error: String? = nil) {
        guard let first = favorites.first else { return }
        if !clear { favoriteSelection = first.id }

        let quantity = favorites.count == 1 ? "1 saved favorite" : "\(favorites.count) saved favorites"
        let detail = clear ? "Remove \(quantity) from Favorites." : "\(first.name)\n\(first.number)"
        let cancel = { [weak self] in
            guard let self else { return }
            if let editor { showEditor(editor) } else { showTab(focus: true) }
        }
        let ids = Set(favorites.map(\.id))
        let actionTitle = clear ? "Clear Favorites" : "Remove"
        showRemovalConfirmation(title: clear ? "Clear Favorites?" : "Remove favorite?", detail: detail,
                                actionTitle: actionTitle, target: clear ? quantity : "\(first.name), \(first.number)",
                                error: error, cancel: cancel) { [weak self] in
            guard let self else { return }
            do {
                try model.lists.removeFavorites(ids: ids)
                showTab(focus: true)
            } catch {
                confirmRemoval(favorites, clear: clear, error: error.localizedDescription)
            }
        }
    }

    private func confirmRecentRemoval(_ attempts: [CallAttempt], clear: Bool = false, error: String? = nil) {
        guard let first = attempts.first else { return }
        recentSelection = clear ? nil : first.id
        let quantity = attempts.count == 1 ? "1 call attempt" : "\(attempts.count) call attempts"
        let date = first.time.formatted(date: .abbreviated, time: .shortened)
        let detail = clear ? "Remove \(quantity) from Recents." : "\(first.number)\n\(date)"
        let cancel: () -> Void = { [weak self] in self?.showTab(focus: true) }
        let ids = Set(attempts.map(\.id))
        showRemovalConfirmation(title: clear ? "Clear Recents?" : "Remove call attempt?", detail: detail,
                                actionTitle: clear ? "Clear Recents" : "Remove",
                                target: clear ? quantity : "\(first.number), \(date)", error: error,
                                cancel: cancel) { [weak self] in
            guard let self else { return }
            do {
                try model.lists.removeAttempts(ids: ids)
                showTab(focus: true)
            } catch {
                confirmRecentRemoval(attempts, clear: clear, error: "Couldn’t remove call history. Try again.")
            }
        }
    }

    private func showRemovalConfirmation(title text: String, detail: String, actionTitle: String, target: String,
                                         error: String?, cancel: @escaping () -> Void,
                                         confirm: @escaping () -> Void) {
        let title = NSTextField(labelWithString: text)
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        let cancelButton = PopoverButton("Cancel", action: cancel)
        cancelButton.keyEquivalent = "\r"
        let remove = PopoverButton(error == nil ? actionTitle : "Retry", action: confirm)
        remove.setAccessibilityLabel("\(remove.title), \(target)")
        var children: [NSView] = [title, bodyLabel(detail)]
        if let error { children.append(bodyLabel(error, color: .systemRed)) }
        children += [horizontalStack([NSView(), cancelButton, remove]), NSView()]
        let confirmation = verticalStack(children)
        showPanel(confirmation, cancel: cancel)
        view.window?.makeFirstResponder(cancelButton)
    }

    private func showPanel(_ panel: NSView, cancel: @escaping () -> Void) {
        cancelPanel = cancel
        segments.isEnabled = false
        listActions.isEnabled = false
        setupButton.isEnabled = false
        show(panel)
    }

    private func show(_ content: NSView) {
        if body.subviews.first === content { return }
        body.subviews.forEach { $0.removeFromSuperview() }
        body.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: body.topAnchor),
            content.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: body.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: body.bottomAnchor)
        ])
        view.window?.recalculateKeyViewLoop()
    }

    private func focusRow(_ row: NSButton?, fallback: NSView) {
        view.layoutSubtreeIfNeeded()
        if let row { row.scrollToVisible(row.bounds) }
        view.window?.makeFirstResponder(row ?? fallback)
    }

    private func showSetup() {
        let back: () -> Void = { [weak self] in self?.showTab(focus: true) }
        let setup = SetupGuideView(onBack: back)
        showPanel(setup, cancel: back)
        setup.focusBack()
    }

    private func updateNumber() {
        model.rawNumber = numberField.currentEditor()?.string ?? numberField.stringValue
    }

    private func submit() {
        if let event = NSApp.currentEvent {
            if event.isRepeatKeyDown || (event.type == .leftMouseUp && event.clickCount > 1) { return }
        }
        updateNumber()
        if model.canCall { model.call() }
    }

    private var historyIssue: String {
        model.lists.historyReadIssue?.message(for: "Recents")
            ?? "Couldn’t save changes to Recents. Retry to save your call history."
    }

    private func retryHistory() {
        model.lists.retryHistory()
        if tab == .recents { showRecents(focus: true) } else { refreshDialer() }
    }

    private func refreshCallState() {
        guard isViewLoaded, cancelPanel == nil else { return }
        setupButton.isEnabled = !model.isOpening
        if tab == .dialer { refreshDialer() }
        if tab == .recents { showRecents(focus: false) }
    }

    private func refreshDialer() {
        if let message = model.validationMessage {
            validationLabel.stringValue = message
            validationLabel.textColor = .systemRed
        } else {
            validationLabel.stringValue = model.normalizedNumber.map { "Ready to dial: \($0)" }
                ?? "The number does not need to be in Contacts."
            validationLabel.textColor = .secondaryLabelColor
        }
        let notice = model.notice
        let failed = notice?.kind == .error
        noticeLabel.stringValue = notice?.message
            ?? "macOS will open the calling app. Confirm the call if prompted."
        noticeLabel.textColor = failed ? .systemRed : .secondaryLabelColor
        numberField.isEnabled = !model.isOpening
        clearNumber.isEnabled = !model.isOpening && !model.rawNumber.isEmpty
        configureStar(dialerStar, number: model.normalizedNumber)
        callButton.setPrimaryTitle(model.isOpening ? "Sending number…" : "Call through iPhone")
        callButton.setAccessibilityLabel(model.normalizedNumber.map { "Call \($0)" } ?? callButton.title)
        callButton.isEnabled = model.canCall
        historyError.stringValue = historyIssue
        historyRecovery.isHidden = !(model.lists.historyReadFailed || model.lists.historyWriteFailed)
    }
}
