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
                    Text(Strings.About.appName)
                        .font(.title3.weight(.semibold))

                    Text("Version 0.1.0")
                        .foregroundStyle(.secondary)

                    Text(Strings.About.tagline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        LinkButton(Strings.About.acknowledgementsLink, url: repositoryURL)
                        LinkButton(Strings.About.privacyPolicyLink, url: privacyURL)
                        LinkButton(Strings.About.termsOfUseLink, url: termsURL)
                    }
                    .padding(.top, 10)

                    Button(Strings.About.reportIssue) { open(issuesURL) }
                        .padding(.top, 10)
                }
                .frame(width: 210, alignment: .leading)
            }

            VStack(spacing: 12) {
                Text(Strings.About.description)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Text(Strings.About.copyright)
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

#if DEBUG
#Preview {
    AboutTabView()
}
#endif
