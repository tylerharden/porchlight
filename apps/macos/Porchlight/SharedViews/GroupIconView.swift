import SwiftUI

struct GroupIconView: View {
    let icon: String?
    let color: String
    var size: CGFloat = 12

    var body: some View {
        if let image = iconImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
        } else {
            Circle()
                .fill(Color(hex: color))
                .frame(width: size, height: size)
        }
    }

    private var iconImage: NSImage? {
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

        return NSImage(contentsOfFile: path)
    }
}

#if DEBUG
#Preview("Group Icons") {
    HStack(spacing: 16) {
        GroupIconView(icon: nil, color: "#007AFF", size: 18)
        GroupIconView(icon: nil, color: "#34C759", size: 18)
        GroupIconView(icon: nil, color: "#FF9500", size: 18)
    }
    .padding()
}
#endif
