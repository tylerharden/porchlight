import SwiftUI

struct CompactEmptyState: View {
    let title: String
    let systemImage: String
    var description: String?

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.callout.weight(.semibold))
            if let description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    VStack {
        CompactEmptyState(
            title: "No Servers",
            systemImage: "lightbulb",
            description: "Start a local development server and it will appear here."
        )
        Divider()
        CompactEmptyState(
            title: "Select a Group",
            systemImage: "folder"
        )
    }
    .frame(width: 300, height: 300)
}
