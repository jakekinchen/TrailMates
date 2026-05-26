import SwiftUI

// MARK: - AboutView
struct AboutView: View {
    // MARK: - Constants
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    // MARK: - Body
    var body: some View {
        List {
            appIconSection
            appInfoSection
            legalSection
            socialSection
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("About")
                    .foregroundColor(AppColors.pine)
                    .font(.headline)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .themedBackground()
    }
}

// MARK: - AboutView Sections
private extension AboutView {
    var appIconSection: some View {
        Section {
            VStack(spacing: 8) {
                appIconView

                Text("TrailMates")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.pine)

                Text("Version \(appVersion) (\(buildNumber))")
                    .foregroundColor(AppColors.pine.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    var appInfoSection: some View {
        Section(header: Text("App Info").foregroundColor(AppColors.pine)) {
            infoRow("Version", value: appVersion)
            infoRow("Build", value: buildNumber)
        }
        .listRowBackground(AppColors.beige.opacity(0.9))
        .foregroundColor(AppColors.pine)
    }

    var legalSection: some View {
        Section(header: Text("Legal").foregroundColor(AppColors.pine)) {
            NavigationLink("Terms of Service") {
                WebViewContainer(url: URL(string: AppConstants.termsOfServiceURL)!)
            }

            NavigationLink("Privacy Policy") {
                WebViewContainer(url: URL(string: AppConstants.privacyPolicyURL)!)
            }

            NavigationLink("Acknowledgments") {
                AcknowledgmentsView()
            }
        }
        .listRowBackground(AppColors.beige.opacity(0.9))
        .foregroundColor(AppColors.pine)
    }

    var socialSection: some View {
        Section(header: Text("Follow Us").foregroundColor(AppColors.pine)) {
            Link(destination: URL(string: AppConstants.twitterURL)!) {
                HStack {
                    Text("Twitter")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
            }

            Link(destination: URL(string: AppConstants.instagramURL)!) {
                HStack {
                    Text("Instagram")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
            }
        }
        .listRowBackground(AppColors.beige.opacity(0.9))
        .foregroundColor(AppColors.pine)
    }
}

// MARK: - AboutView View Builders
private extension AboutView {
    @ViewBuilder
    var appIconView: some View {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let icon = window.windowScene?.activationState == .foregroundActive ? UIImage(named: "AppIcon60x60") : nil {
            Image(uiImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .cornerRadius(22)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(AppColors.pine.opacity(0.1), lineWidth: 1)
                )
        } else {
            Image(systemName: "app.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(AppColors.pine)
        }
    }
}

// MARK: - AboutView Helpers
private extension AboutView {
    func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundColor(AppColors.pine)
            Spacer()
            Text(value).foregroundColor(.gray)
        }
    }
}

// MARK: - WebViewContainer
struct WebViewContainer: View {
    // MARK: - Dependencies
    let url: URL

    // MARK: - Body
    var body: some View {
        ZStack {
            AppColors.beige.ignoresSafeArea()
            WebView(url: url)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
