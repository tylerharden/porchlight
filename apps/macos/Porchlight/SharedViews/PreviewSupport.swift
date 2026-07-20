#if DEBUG
import AppKit
import SwiftUI

enum PorchlightPreviewData {
    static let frontendGroup = ServerGroupMatch(
        id: "frontend",
        name: "Frontend",
        kind: "Next.js",
        role: "Frontend",
        color: "#007AFF",
        icon: nil,
        confidence: 1,
        source: "preview"
    )

    static let activeServer = LocalServer(
        id: "preview-active",
        port: 3000,
        pid: 1234,
        status: .active,
        processName: "node",
        serverType: "Next.js",
        icon: nil,
        group: frontendGroup,
        command: "npm run dev",
        workingDirectory: "/tmp/porchlight",
        displayDirectory: "~/Developer/porchlight",
        url: "http://localhost:3000",
        pinned: true,
        lastSeenAt: nil,
        startCommand: "npm run dev"
    )

    static let recentServer = LocalServer(
        id: "preview-recent",
        port: 8000,
        pid: 5678,
        status: .recent,
        processName: "python",
        serverType: "Django",
        icon: nil,
        group: nil,
        command: "python manage.py runserver",
        workingDirectory: "/tmp/backend",
        displayDirectory: "~/Developer/backend",
        url: "http://localhost:8000",
        pinned: false,
        lastSeenAt: "2026-07-16T10:00:00Z",
        startCommand: nil
    )

    static let hiddenServer = LocalServer(
        id: "preview-hidden",
        port: 5173,
        pid: 9012,
        status: .stopped,
        processName: "node",
        serverType: "Vite",
        icon: nil,
        group: frontendGroup,
        command: "npm run dev -- --host 0.0.0.0",
        workingDirectory: "/tmp/hidden-app",
        displayDirectory: "~/Developer/hidden-app",
        url: "http://localhost:5173",
        pinned: false,
        hidden: true,
        lastSeenAt: "2026-07-16T10:00:00Z",
        startCommand: "npm run dev"
    )
}

struct NSViewPreview<View: NSView>: NSViewRepresentable {
    let makeView: () -> View

    func makeNSView(context: Context) -> View {
        makeView()
    }

    func updateNSView(_ nsView: View, context: Context) {}
}

final class PreviewActionTarget: NSObject {
    @objc func performAction(_ sender: Any?) {}
}
#endif
