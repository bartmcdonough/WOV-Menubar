// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WOVMenubar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WOVMenubar", targets: ["WOVMenubar"]),
        .library(name: "WOVMenubarCore", targets: ["WOVMenubarCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1")
    ],
    targets: [
        .target(
            name: "WOVMenubarCore",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "WOVMenubar",
            dependencies: [
                "WOVMenubarCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(
            name: "WOVMenubarTests",
            dependencies: ["WOVMenubarCore"]
        )
    ]
)
