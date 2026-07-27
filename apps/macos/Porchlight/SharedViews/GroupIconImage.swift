import AppKit

struct GroupIconImage {
    let image: NSImage
    let isFallback: Bool

    static func resolve(icon: String?, size: CGFloat, fallbackVerticalOffset: CGFloat = 0) -> GroupIconImage {
        if let image = fileIconImage(icon, size: size) {
            return GroupIconImage(image: image, isFallback: false)
        }

        return GroupIconImage(
            image: folderIconImage(size: size, verticalOffset: fallbackVerticalOffset),
            isFallback: true
        )
    }

    private static func fileIconImage(_ icon: String?, size: CGFloat) -> NSImage? {
        guard let icon = icon?.trimmingCharacters(in: .whitespacesAndNewlines), !icon.isEmpty else {
            return nil
        }

        let path: String
        if let url = URL(string: icon), url.isFileURL {
            path = url.path
        } else if icon.hasPrefix("~") {
            path = (icon as NSString).expandingTildeInPath
        } else {
            path = icon
        }

        guard let image = NSImage(contentsOfFile: path) else { return nil }
        image.size = NSSize(width: size, height: size)
        image.isTemplate = false
        return image
    }

    private static func folderIconImage(size: CGFloat, verticalOffset: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        guard let symbol = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: size, weight: .regular))
        else {
            return image
        }

        let symbolSize = symbol.size
        let scale = min(size / symbolSize.width, size / symbolSize.height)
        let drawSize = NSSize(width: symbolSize.width * scale, height: symbolSize.height * scale)
        let drawRect = NSRect(
            x: (size - drawSize.width) / 2,
            y: ((size - drawSize.height) / 2) + verticalOffset,
            width: drawSize.width,
            height: drawSize.height
        )

        image.lockFocus()
        symbol.draw(
            in: drawRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
