// swift-tools-version:5.9
import PackageDescription

// =============================================================================
// DEPENDENCY DOCUMENTATION
// =============================================================================
//
// TrailMates dependencies are managed via Xcode's Swift Package Manager (SPM)
// integration in the .xcodeproj file, not in this Package.swift file.
//
// CURRENT DEPENDENCIES (as of 2025-01-26):
//
// 1. Firebase iOS SDK (v11.5.0, minimum: v11.3.0)
//    URL: https://github.com/firebase/firebase-ios-sdk
//    Products used:
//    - FirebaseCore: Core Firebase functionality and initialization
//    - FirebaseAuth: User authentication (phone number auth)
//    - FirebaseFirestore: Cloud database for users, events, landmarks, friends
//    - FirebaseDatabase: Realtime database for location sharing, notifications
//    - FirebaseStorage: Image storage for profile photos and event images
//    - FirebaseFunctions: Cloud functions for server-side logic (contact matching)
//    - FirebaseAnalyticsWithoutAdIdSupport: Analytics without Ad ID tracking
//
//    NOTE: Latest available version is 12.8.0 (requires Xcode 16.2+/Swift 6.0)
//    Consider upgrading when ready to update Xcode requirements.
//
// 2. PhoneNumberKit (v3.8.0, minimum: v3.7.0)
//    URL: https://github.com/marmelroy/PhoneNumberKit
//    Purpose: Phone number parsing, formatting, and validation
//    Used by: PhoneNumberService, PhoneNumberUtility, ContactsListViewModel
//    Features: E.164 formatting, international number support, validation
//
//    NOTE: Latest available version is 4.0.0
//    v3.8.0 is stable; upgrade when 4.x is more mature.
//
// TRANSITIVE DEPENDENCIES (automatically resolved):
// - abseil-cpp-binary: C++ utilities (Firebase dependency)
// - app-check: Firebase App Check
// - GoogleAppMeasurement: Analytics measurement
// - GoogleDataTransport: Data transport layer
// - GoogleUtilities: Shared utilities
// - grpc-binary: gRPC for network communication
// - gtm-session-fetcher: HTTP session management
// - interop-ios-for-google-sdks: Google SDK interoperability
// - leveldb: Key-value storage (Firebase dependency)
// - nanopb: Protocol buffers
// - promises: Promise-based async utilities
// - swift-protobuf: Protocol buffers for Swift
//
// =============================================================================

let package = Package(
    name: "TrailMates",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TrailMates",
            targets: ["TrailMates"]),
    ],
    dependencies: [
        // Dependencies are managed in Xcode project file.
        // See documentation above for current dependency list.
    ],
    targets: [
        .target(
            name: "TrailMates",
            dependencies: [],
            swiftSettings: [
                .unsafeFlags(["-suppress-warnings"])
            ]
        )
    ]
) 