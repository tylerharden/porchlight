import AppKit

enum PorchlightAppIcon {
    static var image: NSImage {
        if let url = Bundle.main.url(forResource: "Porchlight", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        return NSApp.applicationIconImage
    }
}
