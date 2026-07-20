import AppKit
import SwiftUI

final class ServerMenuItemView: NSView {
    private let server: LocalServer
    private let progressIndicator = NSProgressIndicator()

    init(server: LocalServer) {
        self.server = server
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 24))

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.frame = NSRect(x: 8, y: 3, width: 18, height: 18)
        addSubview(progressIndicator)
        progressIndicator.startAnimation(nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let title = NSMutableAttributedString(
            string: String(server.port),
            attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: NSColor.labelColor
            ]
        )

        title.append(NSAttributedString(string: "  "))
        title.append(NSAttributedString(
            string: server.serverType,
            attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        ))

        title.draw(at: NSPoint(x: 30, y: 4))
    }
}

#Preview("Busy Server Menu Item") {
    NSViewPreview {
        ServerMenuItemView(server: PorchlightPreviewData.activeServer)
    }
    .frame(width: 220, height: 24)
    .padding()
}
