// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "focusmate",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "focusmate",
            targets: ["focusmate"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.0.0")
    ],
    targets: [
        .target(
            name: "focusmate",
            dependencies: [
                .product(name: "Sentry", package: "sentry-cocoa")
            ]
        ),
        .testTarget(
            name: "focusmateTests",
            dependencies: ["focusmate"]
        ),
    ]
)
