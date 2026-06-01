import SwiftUI

enum TrailMatesDeepLink {
    private static let universalLinkHosts: Set<String> = []
    static let appStoreFallbackURL = URL(string: "https://apps.apple.com/app/id6737356482")!

    static func inviteURL(senderId: String) -> URL {
        var components = URLComponents()
        components.scheme = "trailmates"
        components.host = "invite"
        components.path = "/\(senderId)"

        return components.url ?? appStoreFallbackURL
    }

    static func profileUserId(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased()
        let pathParts = url.pathComponents.filter { $0 != "/" }

        if scheme == "trailmates" {
            if let userId = queryItems.value(for: "senderId") ?? queryItems.value(for: "userId") {
                return userId
            }

            if host == "profile" || host == "invite" {
                return pathParts.first
            }
            return host
        }

        guard scheme == "https",
              let host,
              universalLinkHosts.contains(host),
              let route = pathParts.first,
              route == "profile" || route == "invite" else {
            return nil
        }

        if let userId = queryItems.value(for: "senderId") ?? queryItems.value(for: "userId") {
            return userId
        }

        return pathParts.dropFirst().first
    }
}

@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    @Published var presentedProfileUser: User?
    @Published var isResolvingProfile = false
    @Published var errorMessage: String?

    private let pendingProfileUserIdKey = "pendingDeepLinkProfileUserId"
    private var pendingProfileUserId: String? {
        didSet {
            if let pendingProfileUserId {
                UserDefaults.standard.set(pendingProfileUserId, forKey: pendingProfileUserIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: pendingProfileUserIdKey)
            }
        }
    }

    private init() {
        pendingProfileUserId = UserDefaults.standard.string(forKey: pendingProfileUserIdKey)
    }

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let profileUserId = TrailMatesDeepLink.profileUserId(from: url) else {
            return false
        }

        pendingProfileUserId = profileUserId
        return true
    }

    func resolvePendingProfileIfPossible(userManager: UserManager) async {
        guard userManager.isLoggedIn,
              userManager.currentUser != nil,
              let profileUserId = pendingProfileUserId,
              !profileUserId.isEmpty else {
            return
        }

        isResolvingProfile = true
        defer { isResolvingProfile = false }

        let user: User
        if profileUserId == userManager.currentUser?.id,
           let currentUser = userManager.currentUser {
            user = currentUser
        } else {
            do {
                user = try await userManager.fetchPublicUserProfile(userId: profileUserId)
            } catch {
                let appError = AppError.classify(error)
                errorMessage = appError.errorDescription ?? "That TrailMates profile could not be found."
                pendingProfileUserId = nil
                return
            }
        }

        guard !user.id.isEmpty else {
            errorMessage = "That TrailMates profile could not be found."
            pendingProfileUserId = nil
            return
        }

        presentedProfileUser = user
        pendingProfileUserId = nil
    }
}

private extension Array where Element == URLQueryItem {
    func value(for name: String) -> String? {
        first { $0.name == name }?.value
    }
}
