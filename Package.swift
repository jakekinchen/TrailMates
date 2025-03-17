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
    dependencies: [
        .package(url: "https://github.com/facebook/facebook-ios-sdk", from: "16.3.1")
    ],
    targets: [
        .target(
            name: "TrailMates",
            dependencies: [
                .product(name: "FacebookCore", package: "facebook-ios-sdk")
            ],
            swiftSettings: [
                .unsafeFlags(["-suppress-warnings"])
            ]
        )
    ]
) 