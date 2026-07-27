import SwiftUI

struct GroupIconView: View {
    let icon: String?
    let color: String
    var size: CGFloat = 12

    var body: some View {
        let resolvedIcon = GroupIconImage.resolve(icon: icon, size: size)

        Image(nsImage: resolvedIcon.image)
            .resizable()
            .renderingMode(resolvedIcon.isFallback ? .template : .original)
            .scaledToFit()
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: resolvedIcon.isFallback ? 0 : size * 0.2, style: .continuous))
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
