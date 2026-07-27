import AppKit
import Foundation

struct WorkspaceOpener {
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
