// PermissionsView.swift
import SwiftUI
import CoreLocation
import UserNotifications

struct PermissionsView: View {
    private enum PermissionStep: Int, CaseIterable, Hashable {
        case notifications
        case location

        var title: String {
            switch self {
            case .notifications:
                return "Stay in the loop"
            case .location:
                return "Share your trail location"
            }
        }

        var message: String {
            switch self {
            case .notifications:
                return "We'll let you know when friends invite you for a walk or are nearby on the trail."
            case .location:
                return "This helps friends find you on the trail, even if TrailMates is in the background."
            }
        }

        var iconName: String {
            switch self {
            case .notifications:
                return "bell.badge.fill"
            case .location:
                return "location.fill"
            }
        }

        var progressLabel: String {
            "Step \(rawValue + 1) of \(Self.allCases.count)"
        }
    }

    @StateObject private var locationManager: LocationManager
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingPermissions = false
    @State private var currentStep: PermissionStep = .notifications
    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        _locationManager = StateObject(wrappedValue: LocationManager(userManager: UserManager.shared))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                permissionProgress

                Spacer()

                permissionContent(for: currentStep)
                    .padding(.horizontal, AppSpacing.xxl)

                Spacer()

                continueButton
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xxl)
            }
            .themedBackground()
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    await checkNotificationStatus()
                }
            }
        }
    }

    private var permissionProgress: some View {
        VStack(spacing: AppSpacing.md) {
            Text(currentStep.progressLabel)
                .font(AppTypography.labelPrimary)
                .foregroundColor(AppColors.alwaysSage)

            HStack(spacing: AppSpacing.sm) {
                ForEach(PermissionStep.allCases, id: \.self) { step in
                    Capsule()
                        .fill(step.rawValue <= currentStep.rawValue ? AppColors.pumpkin : AppColors.alwaysSage.opacity(0.25))
                        .frame(width: step == currentStep ? 28 : 10, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: currentStep)
                }
            }
        }
        .padding(.top, AppSpacing.xxxl)
    }

    private func permissionContent(for step: PermissionStep) -> some View {
        VStack(spacing: AppSpacing.xxl) {
            Image(systemName: step.iconName)
                .font(.system(size: 52, weight: .semibold))
                .foregroundColor(AppColors.pumpkin)
                .frame(width: 96, height: 96)
                .background(Color.white.opacity(0.75))
                .clipShape(Circle())

            VStack(spacing: AppSpacing.md) {
                Text(step.title)
                    .font(AppTypography.titleLarge)
                    .foregroundColor(AppColors.pine)
                    .multilineTextAlignment(.center)

                Text(step.message)
                    .font(AppTypography.bodyPrimary)
                    .foregroundColor(AppColors.alwaysSage)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var continueButton: some View {
        PrimaryButton("Continue", isLoading: isRequestingPermissions, size: .large) {
            Task {
                await continueFromCurrentStep()
            }
        }
    }

    private var notificationPermissionStatus: PermissionStatus {
        switch notificationStatus {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .provisional:
            return .partial
        case .notDetermined:
            return .notRequested
        case .ephemeral:
            return .partial
        @unknown default:
            return .notRequested
        }
    }

    @MainActor
    private func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    @MainActor
    private func continueFromCurrentStep() async {
        guard !isRequestingPermissions else { return }
        isRequestingPermissions = true
        defer { isRequestingPermissions = false }

        switch currentStep {
        case .notifications:
            await requestNotificationPermission()
            currentStep = .location
        case .location:
            await requestLocationPermission()
            onComplete()
        }
    }

    @MainActor
    private func requestNotificationPermission() async {
        guard notificationPermissionStatus == .notRequested else { return }

        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        await checkNotificationStatus()
    }

    @MainActor
    private func requestLocationPermission() async {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            let status = await locationManager.requestLocationPermission()
            if status == .authorizedWhenInUse {
                _ = await locationManager.requestAlwaysAuthorization()
            }
        case .authorizedWhenInUse:
            _ = await locationManager.requestAlwaysAuthorization()
        default:
            break
        }
    }
}

#Preview {
    PermissionsView {
    }
}
