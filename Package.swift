// swift-tools-version:5.9
import PackageDescription

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
    dependencies: [],
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