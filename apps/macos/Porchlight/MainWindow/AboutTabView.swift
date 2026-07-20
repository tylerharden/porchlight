import AppKit
import SwiftUI

struct AboutTabView: View {
    private let repositoryURL = URL(string: "https://github.com/tylerharden/porchlight")!
    private let issuesURL = URL(string: "https://github.com/tylerharden/porchlight/issues/new")!
    private let termsURL = URL(string: "https://github.com/tylerharden/porchlight/blob/main/TERMS_OF_USE.md")!
    private let privacyURL = URL(string: "https://github.com/tylerharden/porchlight/blob/main/PRIVACY_POLICY.md")!

    var body: some View {
        VStack(spacing: 34) {
            HStack(alignment: .top, spacing: 34) {
                Image(nsImage: PorchlightAppIcon.image)
                    .resizable()
                    .frame(width: 128, height: 128)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Porchlight")
                        .font(.title3.weight(.semibold))

                    Text("Version 0.1.0")
                        .foregroundStyle(.secondary)

                    Text("Find the servers you left on.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        LinkButton("Acknowledgements", url: repositoryURL)
                        LinkButton("Privacy Policy", url: privacyURL)
                        LinkButton("Terms of Use", url: termsURL)
                    }
                    .padding(.top, 10)

                    Button("Report an Issue...") { open(issuesURL) }
                        .padding(.top, 10)
                }
                .frame(width: 210, alignment: .leading)
            }

            VStack(spacing: 12) {
                Text("Porchlight runs locally and uses the bundled Rust CLI to inspect development servers.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Text("© 2026 Porchlight. All rights reserved.")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity, minHeight: 340, alignment: .center)
    }

    private func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    AboutTabView()
}
