import AppKit

enum PorchlightStatusIcon {
    static func image(isActive: Bool) -> NSImage {
        let name = isActive ? "porchlight-icon-on" : "porchlight-icon-off"
        let image = loadImage(named: name) ?? fallbackImage(isActive: isActive)
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = !isActive
        return image
    }

    private static func loadImage(named name: String) -> NSImage? {
        if let image = NSImage(named: name) {
            return image
        }

        if let url = Bundle.main.url(forResource: name, withExtension: "pdf"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        if let url = Bundle.main.url(forResource: name, withExtension: "pdf", subdirectory: "Assets"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        return nil
    }

    private static func fallbackImage(isActive: Bool) -> NSImage {
        NSImage(
            systemSymbolName: isActive ? "lightbulb.fill" : "lightbulb",
            accessibilityDescription: "Porchlight"
        ) ?? NSImage(size: NSSize(width: 18, height: 18))
    }
}
