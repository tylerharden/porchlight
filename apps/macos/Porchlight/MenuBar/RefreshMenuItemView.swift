import AppKit
import SwiftUI

final class RefreshMenuItemView: NSView {
    private let title: String
    private let shortcut: String?
    private let isEnabled: Bool
    private weak var target: AnyObject?
    private let action: Selector
    private var isHovered = false {
        didSet { needsDisplay = true }
    }
    private var isPressed = false {
        didSet { needsDisplay = true }
    }

    init(title: String, shortcut: String? = nil, isEnabled: Bool = true, target: AnyObject, action: Selector) {
        self.title = title
        self.shortcut = shortcut
        self.isEnabled = isEnabled
        self.target = target
        self.action = action
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let isHighlighted = isEnabled && (isHovered || isPressed)

        if isHighlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 0), xRadius: 4, yRadius: 4).fill()
        }

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: textColor(isHighlighted: isHighlighted, secondary: false)
        ]
        let shortcutAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: textColor(isHighlighted: isHighlighted, secondary: true)
        ]

        let title = NSAttributedString(string: title, attributes: titleAttributes)
        title.draw(at: NSPoint(x: 14, y: 4))

        if let shortcut {
            let shortcut = NSAttributedString(string: shortcut, attributes: shortcutAttributes)
            shortcut.draw(at: NSPoint(x: bounds.width - shortcut.size().width - 14, y: 4))
        }
    }

    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else { return }
            self.isPressed = false
            _ = self.target?.perform(self.action, with: nil)
        }
    }

    private func textColor(isHighlighted: Bool, secondary: Bool) -> NSColor {
        if !isEnabled {
            return .disabledControlTextColor
        }

        if isHighlighted {
            return .selectedMenuItemTextColor
        }

        return secondary ? .secondaryLabelColor : .labelColor
    }
}

#if DEBUG
#Preview("Refresh Menu Item") {
    let target = PreviewActionTarget()
    VStack(spacing: 8) {
        NSViewPreview {
            RefreshMenuItemView(title: "Refresh", shortcut: "⌘R", target: target, action: #selector(PreviewActionTarget.performAction(_:)))
        }
        .frame(width: 220, height: 24)

        NSViewPreview {
            RefreshMenuItemView(title: "Kill All", isEnabled: false, target: target, action: #selector(PreviewActionTarget.performAction(_:)))
        }
        .frame(width: 220, height: 24)
    }
    .padding()
}
#endif
