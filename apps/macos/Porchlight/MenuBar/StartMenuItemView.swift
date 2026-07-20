import AppKit
import SwiftUI

final class StartMenuItemView: NSView {
    private let serverID: String
    private let title: String
    private let busyTitle: String
    private let isEnabled: Bool
    private var isStarting: Bool
    private weak var target: AnyObject?
    private let action: Selector
    private let progressIndicator = NSProgressIndicator()
    private var isHovered = false {
        didSet { needsDisplay = true }
    }

    init(
        serverID: String,
        title: String = "Start",
        busyTitle: String = "Starting…",
        isEnabled: Bool,
        isStarting: Bool,
        target: AnyObject,
        action: Selector
    ) {
        self.serverID = serverID
        self.title = title
        self.busyTitle = busyTitle
        self.isEnabled = isEnabled
        self.isStarting = isStarting
        self.target = target
        self.action = action
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.frame = NSRect(x: bounds.width - 28, y: 3, width: 18, height: 18)
        addSubview(progressIndicator)
        updateSpinner()
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

        if isHovered && isEnabled && !isStarting {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 5, yRadius: 5).fill()
        }

        let textColor: NSColor = if !isEnabled || isStarting {
            .disabledControlTextColor
        } else if isHovered {
            .selectedMenuItemTextColor
        } else {
            .labelColor
        }

        let title = NSAttributedString(
            string: isStarting ? busyTitle : title,
            attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: textColor
            ]
        )
        title.draw(at: NSPoint(x: 14, y: 4))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled && !isStarting else { return }
        isStarting = true
        updateSpinner()
        needsDisplay = true
        _ = target?.perform(action, with: serverID)
    }

    private func updateSpinner() {
        if isStarting {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }
}

#Preview("Start Menu Items") {
    let target = PreviewActionTarget()
    VStack(spacing: 8) {
        NSViewPreview {
            StartMenuItemView(
                serverID: PorchlightPreviewData.recentServer.id,
                isEnabled: true,
                isStarting: false,
                target: target,
                action: #selector(PreviewActionTarget.performAction(_:))
            )
        }
        .frame(width: 220, height: 24)

        NSViewPreview {
            StartMenuItemView(
                serverID: PorchlightPreviewData.recentServer.id,
                isEnabled: true,
                isStarting: true,
                target: target,
                action: #selector(PreviewActionTarget.performAction(_:))
            )
        }
        .frame(width: 220, height: 24)

        NSViewPreview {
            StartMenuItemView(
                serverID: PorchlightPreviewData.activeServer.id,
                title: "Kill",
                busyTitle: "Killing...",
                isEnabled: true,
                isStarting: true,
                target: target,
                action: #selector(PreviewActionTarget.performAction(_:))
            )
        }
        .frame(width: 220, height: 24)
    }
    .padding()
}
