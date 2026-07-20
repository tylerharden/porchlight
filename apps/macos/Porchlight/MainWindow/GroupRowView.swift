import SwiftUI

struct GroupRowView: View {
    let group: GroupSummary
    let showIcon: Bool

    var body: some View {
        if showIcon {
            Label {
                HStack {
                    Text(group.name)
                    Spacer()
                    Text(group.manual ? "Manual" : "Auto")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            } icon: {
                GroupIconView(icon: group.icon, color: group.color ?? "#8E8E93", size: 10)
            }
            .tag(group.id)
        } else {
            HStack {
                Text(group.name)
                Spacer()
                Text(group.manual ? "Manual" : "Auto")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .tag(group.id)
        }
    }
}

#Preview {
    GroupRowView(
        group: GroupSummary(
            id: "test-group",
            name: "Test Group",
            source: "manual",
            manual: true,
            kind: nil,
            role: nil,
            reason: nil,
            color: "#FF5733",
            icon: "star",
            activeServerCount: 2,
            recentServerCount: 3,
            activeCount: 2,
            hidden: false,
            firstSeenAt: nil,
            lastSeenAt: nil,
            ports: [3000, 8000],
            paths: []
        ),
        showIcon: true
    )
}
