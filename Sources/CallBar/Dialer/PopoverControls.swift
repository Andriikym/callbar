import AppKit

enum PopoverPalette {
    static let panel = color(light: 0xf5f5f7, dark: 0x252526)
    static let top = color(light: 0xe9edf9, dark: 0x222639)
    static let line = color(light: 0xd4d5dc, dark: 0x424246)
    static let marker = color(light: 0xe2ecfd, dark: 0x293951)
    static let blue = color(light: 0x155cc8, dark: 0x78b4ff)
    static let hover = color(light: 0xe6e9f2, dark: 0x383840)
    static let primary = color(light: 0x1768e1, dark: 0x1455c1)

    private static func color(light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
    }
}

@MainActor
final class PopoverBackground: NSView {
    override func draw(_ dirtyRect: NSRect) {
        PopoverPalette.panel.setFill()
        dirtyRect.fill()
        let header = NSRect(x: bounds.minX, y: bounds.maxY - 90, width: bounds.width, height: 90)
        NSGradient(starting: PopoverPalette.top, ending: PopoverPalette.panel)?.draw(in: header, angle: -90)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

@MainActor
class PopoverButton: NSButton {
    enum Style { case standard, plain, primary }

    private let activate: () -> Void
    private let style: Style
    private var hovered = false

    init(_ title: String, symbol: String? = nil, style: Style = .standard, action: @escaping () -> Void) {
        activate = action
        self.style = style
        super.init(frame: .zero)
        self.title = title
        target = self
        self.action = #selector(performAction)
        bezelStyle = .rounded
        isBordered = style == .standard
        if style == .primary {
            font = .systemFont(ofSize: 13, weight: .semibold)
            heightAnchor.constraint(equalToConstant: 30).isActive = true
        }
        if let symbol { setSymbol(symbol, label: title) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(_:symbol:action:)") }

    func setSymbol(_ name: String, label: String) {
        image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
        imagePosition = .imageOnly
        toolTip = label
        setAccessibilityLabel(label)
    }

    func setPrimaryTitle(_ title: String) {
        attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.white
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        guard style != .standard else { return }
        for area in trackingAreas where area.owner === self { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if style == .primary || (style == .plain && isEnabled && (hovered || isHighlighted)) {
            let color = style == .plain ? PopoverPalette.hover : PopoverPalette.primary
            color.withAlphaComponent(isEnabled ? 1 : 0.45).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        }
        super.draw(dirtyRect)
    }

    @objc private func performAction() { activate() }
}

@MainActor
final class ListActionsButton: NSButton {
    init() {
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .semibold))
        imagePosition = .imageOnly
        bezelStyle = .rounded
        focusRingType = .exterior
        setAccessibilityRole(.menuButton)
        target = self
        action = #selector(openMenu)
        widthAnchor.constraint(equalToConstant: 34).isActive = true
        heightAnchor.constraint(equalToConstant: 24).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init()") }

    override func keyDown(with event: NSEvent) {
        switch event.charactersIgnoringModifiers {
        case "\r", "\u{3}", " ":
            if !event.isARepeat { performClick(nil) }
        default:
            super.keyDown(with: event)
        }
    }

    @objc private func openMenu() {
        guard isEnabled, let menu, let window else { return }
        window.makeFirstResponder(self)
        let bottom = isFlipped ? bounds.maxY + 8 : bounds.minY - 8
        let x = userInterfaceLayoutDirection == .rightToLeft ? bounds.maxX : bounds.maxX - menu.size.width
        let anchor = NSPoint(x: x, y: bottom)
        menu.popUp(positioning: nil, at: anchor, in: self)
    }
}

@MainActor
final class NumberRowButton: PopoverButton {
    let titleLabel: NSTextField
    let detailLabel: NSTextField

    init(title: String, detail: String, result: String? = nil, loadNumber: @escaping () -> Void) {
        titleLabel = Self.label(title, size: 13, weight: .semibold, color: .labelColor)
        detailLabel = Self.label(detail, size: 11.5, color: .secondaryLabelColor)
        super.init("", style: .plain, action: loadNumber)
        focusRingType = .exterior
        let lines = [title, detail, result].compactMap { $0 }
        setAccessibilityLabel(lines.joined(separator: ", "))
        setAccessibilityHelp("Loads the number into Dialer.")
        toolTip = lines.joined(separator: "\n")

        let marker = NSBox()
        marker.boxType = .custom
        marker.borderWidth = 0
        marker.fillColor = PopoverPalette.marker
        marker.cornerRadius = 12.5
        marker.setAccessibilityElement(false)
        let arrow = NSImageView()
        arrow.image = NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: nil)
        arrow.symbolConfiguration = .init(pointSize: 11, weight: .semibold)
        arrow.contentTintColor = PopoverPalette.blue
        arrow.setAccessibilityElement(false)
        marker.contentView?.addSubview(arrow)

        var labels = [titleLabel, detailLabel]
        if let result { labels.append(Self.label(result, size: 10.5, color: .secondaryLabelColor)) }
        let text = verticalStack(labels, spacing: 1)
        for child in [marker, text] {
            child.translatesAutoresizingMaskIntoConstraints = false
            addSubview(child)
        }
        arrow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            marker.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            marker.centerYAnchor.constraint(equalTo: centerYAnchor),
            marker.widthAnchor.constraint(equalToConstant: 25),
            marker.heightAnchor.constraint(equalTo: marker.widthAnchor),
            arrow.centerXAnchor.constraint(equalTo: marker.centerXAnchor),
            arrow.centerYAnchor.constraint(equalTo: marker.centerYAnchor),
            text.leadingAnchor.constraint(equalTo: marker.trailingAnchor, constant: 8),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: result == nil ? 42 : 54)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(title:detail:result:loadNumber:)") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == "\r" || event.charactersIgnoringModifiers == "\u{3}" {
            if !event.isARepeat { performClick(nil) }
        } else {
            super.keyDown(with: event)
        }
    }

    private static func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setAccessibilityElement(false)
        return label
    }
}

@MainActor
func listRow(_ selection: NumberRowButton, actions: [PopoverButton], hasDivider: Bool) -> NSView {
    let row = NSView()
    let controls = horizontalStack(actions)
    for action in actions {
        action.widthAnchor.constraint(equalToConstant: 30).isActive = true
        action.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }
    for child in [selection, controls] {
        child.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(child)
    }
    NSLayoutConstraint.activate([
        selection.leadingAnchor.constraint(equalTo: row.leadingAnchor),
        selection.topAnchor.constraint(equalTo: row.topAnchor),
        selection.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        selection.trailingAnchor.constraint(equalTo: controls.leadingAnchor, constant: -5),
        controls.trailingAnchor.constraint(equalTo: row.trailingAnchor),
        controls.centerYAnchor.constraint(equalTo: row.centerYAnchor)
    ])
    if hasDivider {
        let line = popoverDivider()
        line.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(line)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            line.bottomAnchor.constraint(equalTo: row.bottomAnchor)
        ])
    }
    return row
}

@MainActor
func popoverDivider() -> NSBox {
    let line = NSBox()
    line.boxType = .custom
    line.borderWidth = 0
    line.fillColor = PopoverPalette.line
    line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
    line.setAccessibilityElement(false)
    return line
}

@MainActor
func verticalStack(_ children: [NSView], spacing: CGFloat = 8) -> NSStackView {
    let stack = NSStackView(views: children)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = spacing
    for child in children { child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
    return stack
}

@MainActor
func horizontalStack(_ children: [NSView]) -> NSStackView {
    let stack = NSStackView(views: children)
    stack.distribution = .fill
    stack.alignment = .centerY
    stack.spacing = 6
    return stack
}

@MainActor
func bodyLabel(_ title: String, color: NSColor = .secondaryLabelColor) -> NSTextField {
    let label = NSTextField(wrappingLabelWithString: title)
    label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    label.textColor = color
    return label
}

@MainActor
func listScrollView(rows: [NSView]) -> NSScrollView {
    let scroll = NSScrollView()
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true
    let document = FlippedListView()
    let stack = verticalStack(rows, spacing: 0)
    scroll.documentView = document
    document.addSubview(stack)
    document.translatesAutoresizingMaskIntoConstraints = false
    stack.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
        document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 2),
        stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 2),
        stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -3),
        stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -2)
    ])
    return scroll
}

private final class FlippedListView: NSView {
    override var isFlipped: Bool { true }
}
