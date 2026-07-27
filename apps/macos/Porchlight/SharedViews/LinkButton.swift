import SwiftUI

struct LinkButton: View {
    let title: String
    let url: URL

    init(_ title: String, url: URL) {
        self.title = title
        self.url = url
    }

    var body: some View {
        Button(title) {
            WorkspaceOpener.open(url)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
    }
}
