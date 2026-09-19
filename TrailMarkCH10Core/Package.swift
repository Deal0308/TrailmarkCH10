// swift-tools-version: 6.0

import PackageDescription

/// Swift Package Manager manifest for the reusable TrailMark core library.
let package = Package(
    name: "TrailMarkCH10Core",

    // The core package can be shared by the iOS app and the watchOS app.
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        // Allows the pure model/store test suite to run from the command line on the development Mac.
        .macOS(.v14)
    ],

    products: [
        .library(
            name: "TrailMarkCH10Core",
            targets: ["TrailMarkCH10Core"]
        )
    ],

    targets: [
        // Main library target that contains models, HealthKit loading, and support utilities.
        .target(
            name: "TrailMarkCH10Core"
        ),

        // Unit tests for the reusable core package.
        .testTarget(
            name: "TrailMarkCH10CoreTests",
            dependencies: ["TrailMarkCH10Core"]
        )
    ],

    swiftLanguageModes: [.v6]
)
