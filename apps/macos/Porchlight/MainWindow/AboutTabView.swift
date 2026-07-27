import Sparkle
import SwiftUI

struct AboutTabView: View {
    let updaterController: SPUStandardUpdaterController

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 34) {
            HStack(alignment: .top, spacing: 34) {
                Image(nsImage: PorchlightAppIcon.image)
                    .resizable()
                    .frame(width: 128, height: 128)

                VStack(alignment: .leading, spacing: 8) {
                    Text(Strings.About.appName)
                        .font(.title3.weight(.semibold))

                    Text("Version \(appVersion) (CLI \(BuildInfo.porchlightCLIVersion))")
                        .foregroundStyle(.secondary)

                    Text(Strings.About.tagline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        LinkButton(Strings.About.acknowledgementsLink, url: PorchlightLinks.repository)
                        LinkButton(Strings.About.privacyPolicyLink, url: PorchlightLinks.privacyPolicy)
                        LinkButton(Strings.About.termsOfUseLink, url: PorchlightLinks.termsOfUse)
                    }
                    .padding(.top, 10)

                    Button(Strings.About.reportIssue) { WorkspaceOpener.open(PorchlightLinks.issues) }
                        .padding(.top, 10)

                    Button(Strings.About.checkForUpdates) { updaterController.checkForUpdates(nil) }
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

}

#if DEBUG
#Preview {
    AboutTabView(updaterController: SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil))
}
#endif
