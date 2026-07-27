import SwiftUI

extension Color {
    init(hex: String) {
        self.init(nsColor: NSColor(hex: hex) ?? .systemGray)
    }

    var hexString: String {
        let color = NSColor(self).usingColorSpace(.sRGB) ?? .systemGreen
        return String(
            format: "#%02X%02X%02X",
            Int(round(color.redComponent * 255)),
            Int(round(color.greenComponent * 255)),
            Int(round(color.blueComponent * 255))
        )
    }
}
